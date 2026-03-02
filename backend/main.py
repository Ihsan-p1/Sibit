from fastapi import FastAPI, Depends, HTTPException, Query, File, Form, UploadFile, Request
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from sqlmodel import Session, select
from typing import List, Optional
import os
import shutil
import datetime
import bleach
import pyotp
import secrets
from fastapi import status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
from itsdangerous import URLSafeSerializer
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Cloudinary (optional — works without it, falls back to local storage)
try:
    import cloudinary
    import cloudinary.uploader
    _cloudinary_url = os.getenv("CLOUDINARY_URL")
    if _cloudinary_url:
        cloudinary.config(cloudinary_url=_cloudinary_url)
        CLOUDINARY_ENABLED = True
        print("☁️  Cloudinary connected")
    else:
        CLOUDINARY_ENABLED = False
        print("📁 Cloudinary not configured — using local storage")
except ImportError:
    CLOUDINARY_ENABLED = False
    print("📁 Cloudinary package not installed — using local storage")

from db import engine, get_session, create_db_and_tables
from models import Batch, AuditLog, BatchPhoto, User, RefreshToken

# STRICT SECRET_KEY - Crashes if not provided in production
SECRET_KEY = os.environ.get("SECRET_KEY")
if not SECRET_KEY:
    # Only allow fallback if explicitly in DEV mode
    if os.getenv("ENV", "prod").lower() == "dev":
        SECRET_KEY = "sibit-secret-api-key-change-it"  # nosec B105
    else:
        raise ValueError("CRITICAL: SECRET_KEY environment variable is not set!")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 15 # Shortened to 15 mins
REFRESH_TOKEN_EXPIRE_DAYS = 7 # 1 week refresh token

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/login")

limiter = Limiter(key_func=get_remote_address)
app = FastAPI(title="SIBIT APP Backend API")
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Allowed Origins Config
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000,http://10.0.2.2,http://127.0.0.1:3000,*").split(",")
if "*" in ALLOWED_ORIGINS and os.getenv("ENV", "prod").lower() != "dev":
    ALLOWED_ORIGINS.remove("*") # Disallow wildcards in production

# Allow CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security Headers Middleware
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    # Hide server details
    response.headers.pop("Server", None)
    return response

# Global Exception Handler to hide stack traces
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    if isinstance(exc, HTTPException):
        return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})
    
    # Check if we are in dev mode
    is_dev = os.getenv("ENV", "prod").lower() == "dev"
    if is_dev:
        return JSONResponse(status_code=500, content={"detail": str(exc)})
    
    print(f"Unhandled Server Error: {exc}")
    return JSONResponse(status_code=500, content={"detail": "Internal Server Error"})

# GZip compression — ~60% smaller JSON responses
app.add_middleware(GZipMiddleware, minimum_size=500)

if not os.path.exists("static/uploads"):
    os.makedirs("static/uploads")
app.mount("/static", StaticFiles(directory="static"), name="static")

# --- Jinja2 Templates ---
templates = Jinja2Templates(directory="templates")
cookie_signer = URLSafeSerializer(SECRET_KEY, salt="admin-session")

def get_admin_from_cookie(request: Request):
    """Validate admin session cookie. Returns (username, token) or None."""
    session_cookie = request.cookies.get("admin_session")
    if not session_cookie:
        return None
    try:
        data = cookie_signer.loads(session_cookie)
        return data
    except Exception:
        return None

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[datetime.timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.datetime.utcnow() + expires_delta
    else:
        expire = datetime.datetime.utcnow() + datetime.timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme), session: Session = Depends(get_session)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    user = session.exec(select(User).where(User.username == username)).first()
    if user is None:
        raise credentials_exception
    return user

@app.on_event("startup")
def on_startup():
    try:
        create_db_and_tables()
        with Session(engine) as session:
            admin_user = session.exec(select(User).where(User.username == "admin")).first()
            if not admin_user:
                default_pass = get_password_hash("admin123")
                new_admin = User(username="admin", password_hash=default_pass, role="admin")
                session.add(new_admin)
                session.commit()
    except Exception as e:
        print(f"Warning: Database connection failed. Please ensure PostgreSQL is running. Details: {e}")

# --- AUTH API ---

@app.post("/api/login")
@limiter.limit("5/minute")
async def login_api(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(), 
    totp_code: Optional[str] = Form(None),
    session: Session = Depends(get_session)
):
    user = session.exec(select(User).where(User.username == form_data.username)).first()
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    # 2FA Enforcement
    if user.totp_secret:
        if not totp_code:
            raise HTTPException(status_code=403, detail="TOTP_REQUIRED")
        totp = pyotp.TOTP(user.totp_secret)
        if not totp.verify(totp_code):
            raise HTTPException(status_code=403, detail="Invalid 2FA Code")

    access_token_expires = datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    
    refresh_token_str = secrets.token_urlsafe(32)
    refresh_token = RefreshToken(
        token=refresh_token_str,
        user_username=user.username,
        expires_at=datetime.datetime.utcnow() + datetime.timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    )
    session.add(refresh_token)
    session.commit()
    
    return {
        "access_token": access_token, 
        "refresh_token": refresh_token_str,
        "token_type": "bearer",  # nosec B105
        "role": user.role
    }

@app.post("/api/refresh-token")
async def refresh_token_api(refresh_token: str = Form(...), session: Session = Depends(get_session)):
    db_token = session.exec(select(RefreshToken).where(RefreshToken.token == refresh_token)).first()
    if not db_token or db_token.is_revoked or db_token.expires_at < datetime.datetime.utcnow():
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
        
    user = session.exec(select(User).where(User.username == db_token.user_username)).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
        
    access_token_expires = datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer", "role": user.role}  # nosec B105

@app.post("/api/logout")
async def logout_api(current_user: User = Depends(get_current_user), refresh_token: Optional[str] = Form(None), session: Session = Depends(get_session)):
    if refresh_token:
        db_token = session.exec(select(RefreshToken).where(RefreshToken.token == refresh_token, RefreshToken.user_username == current_user.username)).first()
        if db_token:
            db_token.is_revoked = True
            session.add(db_token)
            session.commit()
    return {"status": "success", "message": "Logged out successfully"}

@app.post("/api/2fa/setup")
async def setup_2fa(current_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    if current_user.totp_secret:
        return {"status": "error", "message": "2FA already configured"}
    
    secret = pyotp.random_base32()
    uri = pyotp.totp.TOTP(secret).provisioning_uri(name=current_user.username, issuer_name="SIBIT App")
    
    current_user.totp_secret = secret
    session.add(current_user)
    session.commit()
    return {"status": "success", "secret": secret, "uri": uri}

# --- MOBILE API ROUTES ---

@app.get("/api/batches")
def get_batches(session: Session = Depends(get_session)):
    batches = session.exec(select(Batch).order_by(Batch.tanggal_semai.desc())).all()
    result = []
    for b in batches:
        batch_dict = b.model_dump() if hasattr(b, 'model_dump') else b.dict()
        # Count pending (unverified) audit logs for this batch
        pending_logs = session.exec(
            select(AuditLog).where(AuditLog.batch_id == b.batch_id, AuditLog.is_verified == False)
        ).all()
        batch_dict["pending_updates"] = len(pending_logs)
        result.append(batch_dict)
    return {"status": "success", "data": result}

@app.get("/api/batches/{batch_id}")
def get_batch_details(batch_id: str, session: Session = Depends(get_session)):
    batch = session.exec(select(Batch).where(Batch.batch_id == batch_id)).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch tidak ditemukan")
    logs = session.exec(select(AuditLog).where(AuditLog.batch_id == batch_id).order_by(AuditLog.tanggal.desc())).all()
    photos = session.exec(select(BatchPhoto).where(BatchPhoto.batch_id == batch_id).order_by(BatchPhoto.tanggal.desc())).all()
    return {"status": "success", "data": {"batch": batch, "logs": logs, "photos": photos}}

@app.post("/api/batches/create")
async def create_batch_api(
    batch_id: str = Form(...),
    varietas: str = Form(...),
    jumlah_awal: int = Form(...),
    lokasi: str = Form(...),
    nama_pekerja: str = Form(...),
    session: Session = Depends(get_session)
):
    try:
        new_batch = Batch(
            batch_id=bleach.clean(batch_id),
            varietas=bleach.clean(varietas),
            jumlah_awal=jumlah_awal,
            jumlah_hidup=jumlah_awal,
            lokasi=bleach.clean(lokasi),
            tanggal_semai=datetime.datetime.utcnow(),
            nama_pekerja=bleach.clean(nama_pekerja),
            is_verified=False
        )
        session.add(new_batch)
        session.commit()
        session.refresh(new_batch)
        return {"status": "success", "message": "Batch menunggu verifikasi", "batch_id": new_batch.batch_id}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/batches/update/{batch_id}")
async def update_batch_api(
    batch_id: str,
    jumlah_hidup: int = Form(...),
    catatan: str = Form(None),
    nama_pekerja: str = Form(...),
    photo: UploadFile = File(None),
    session: Session = Depends(get_session)
):
    db_batch = session.exec(select(Batch).where(Batch.batch_id == batch_id)).first()
    if not db_batch:
        raise HTTPException(status_code=404, detail="Batch tidak ditemukan")
    
    nilai_lama = db_batch.jumlah_hidup
    
    # Always create audit log for traceability
    catatan_clean = bleach.clean(catatan) if catatan else None
    pekerja_clean = bleach.clean(nama_pekerja)
    
    aksi = "Update Jumlah Hidup" if nilai_lama != jumlah_hidup else "Update Catatan"
    log = AuditLog(
        batch_id=batch_id,
        aksi=aksi,
        nilai_lama=str(nilai_lama),
        nilai_baru=str(jumlah_hidup),
        keterangan=catatan_clean,
        nama_pekerja=pekerja_clean,
        is_verified=False
    )
    session.add(log)
    
    # Mark batch as needing re-verification
    db_batch.is_verified = False
    session.add(db_batch)

    if photo and photo.filename:
        if CLOUDINARY_ENABLED:
            # Upload to Cloudinary with auto-optimization
            result = cloudinary.uploader.upload(
                photo.file,
                folder=f"sibit/{batch_id}",
                transformation=[{"width": 800, "quality": "auto:low", "fetch_format": "auto"}],
                resource_type="image"
            )
            photo_url = result["secure_url"]
        else:
            # Fallback: save locally
            ext = ".png" if photo.content_type == "image/png" else ".jpg"
            filename = f"{batch_id}_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}{ext}"
            photo_path = os.path.join("static/uploads", filename)
            with open(photo_path, "wb") as buffer:
                shutil.copyfileobj(photo.file, buffer)
            photo_url = f"/static/uploads/{filename}"
        
        new_photo = BatchPhoto(
            batch_id=batch_id,
            photo_path=photo_url,
            catatan=f"Diunggah oleh: {pekerja_clean} - {catatan_clean}"
        )
        session.add(new_photo)

    session.commit()
    return {"status": "success", "message": "Update berhasil direkam, menunggu verifikasi Admin."}

@app.put("/api/batches/verify/{batch_id}")
async def verify_batch_api(
    batch_id: str,
    action: str = Query(..., description="'approve' or 'reject'"),
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    # Only authenticated admin can hit this endpoint
    db_batch = session.exec(select(Batch).where(Batch.batch_id == batch_id)).first()
    if not db_batch:
        raise HTTPException(status_code=404, detail="Batch tidak ditemukan")
        
    if action == "approve":
        db_batch.is_verified = True
        
        # Approve pending logs for this batch
        pending_logs = session.exec(select(AuditLog).where(AuditLog.batch_id == batch_id, AuditLog.is_verified == False)).all()
        for log in pending_logs:
            log.is_verified = True
            if log.aksi == "Update Jumlah Hidup" and log.nilai_baru:
                db_batch.jumlah_hidup = int(log.nilai_baru)
                
        session.add(db_batch)
        session.commit()
        return {"status": "success", "message": f"Batch {batch_id} telah diverifikasi."}
    elif action == "reject":
        session.delete(db_batch)
        session.commit()
        return {"status": "success", "message": f"Batch {batch_id} telah dihapus/ditolak."}
    
    raise HTTPException(status_code=400, detail="Invalid action")

# --- ANALYTICS ---

@app.get("/api/analytics")
def get_analytics(session: Session = Depends(get_session)):
    batches = session.exec(select(Batch)).all()
    total_awal = sum(b.jumlah_awal for b in batches)
    total_hidup = sum(b.jumlah_hidup for b in batches)
    total_mati = total_awal - total_hidup
    tingkat_keberhasilan = round((total_hidup / total_awal * 100), 1) if total_awal > 0 else 0
    total_batch = len(batches)
    batch_verified = len([b for b in batches if b.is_verified])
    batch_pending = total_batch - batch_verified

    batch_list = []
    for b in batches:
        survival = round((b.jumlah_hidup / b.jumlah_awal * 100), 1) if b.jumlah_awal > 0 else 0
        batch_list.append({
            "batch_id": b.batch_id,
            "varietas": b.varietas,
            "jumlah_awal": b.jumlah_awal,
            "jumlah_hidup": b.jumlah_hidup,
            "survival_rate": survival,
        })

    return {
        "status": "success",
        "data": {
            "total_bibit": total_awal,
            "total_hidup": total_hidup,
            "total_mati": total_mati,
            "tingkat_keberhasilan": tingkat_keberhasilan,
            "total_batch": total_batch,
            "batch_verified": batch_verified,
            "batch_pending": batch_pending,
            "batches": batch_list,
        }
    }

# --- DELETE BATCH ---

@app.delete("/api/batches/{batch_id}")
async def delete_batch_api(
    batch_id: str,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    db_batch = session.exec(select(Batch).where(Batch.batch_id == batch_id)).first()
    if not db_batch:
        raise HTTPException(status_code=404, detail="Batch tidak ditemukan")
    
    # Delete related logs and photos
    logs = session.exec(select(AuditLog).where(AuditLog.batch_id == batch_id)).all()
    for log in logs:
        session.delete(log)
    photos = session.exec(select(BatchPhoto).where(BatchPhoto.batch_id == batch_id)).all()
    for photo in photos:
        session.delete(photo)
    
    session.delete(db_batch)
    session.commit()
    return {"status": "success", "message": f"Batch {batch_id} berhasil dihapus."}

# ===================================================================
# --- WEB ADMIN ROUTES (served with Jinja2 templates) ---
# ===================================================================

@app.get("/admin/login", response_class=HTMLResponse)
async def admin_login_page(request: Request):
    session = get_admin_from_cookie(request)
    if session:
        return RedirectResponse("/admin/dashboard", status_code=302)
    return templates.TemplateResponse("login.html", {"request": request, "error": None})

@app.post("/admin/login", response_class=HTMLResponse)
async def admin_login_submit(request: Request):
    form = await request.form()
    username = form.get("username", "")
    password = form.get("password", "")

    with Session(engine) as db:
        user = db.exec(select(User).where(User.username == username)).first()
        if not user or not verify_password(password, user.password_hash):
            return templates.TemplateResponse("login.html", {
                "request": request,
                "error": "Username atau password salah"
            })

    # Create JWT token for API calls from the dashboard
    access_token = create_access_token(
        data={"sub": username},
        expires_delta=datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    # Set signed cookie
    session_data = cookie_signer.dumps({"username": username, "token": access_token})
    response = RedirectResponse("/admin/dashboard", status_code=302)
    response.set_cookie(
        key="admin_session",
        value=session_data,
        httponly=True,
        max_age=ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        samesite="lax"
    )
    return response

@app.get("/admin/logout")
async def admin_logout():
    response = RedirectResponse("/admin/login", status_code=302)
    response.delete_cookie("admin_session")
    return response

@app.get("/admin/dashboard", response_class=HTMLResponse)
async def admin_dashboard_page(request: Request):
    session = get_admin_from_cookie(request)
    if not session:
        return RedirectResponse("/admin/login", status_code=302)
    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "username": session["username"],
        "token": session["token"]
    })

@app.get("/admin/batch/{batch_id}", response_class=HTMLResponse)
async def admin_batch_detail_page(request: Request, batch_id: str):
    session = get_admin_from_cookie(request)
    if not session:
        return RedirectResponse("/admin/login", status_code=302)
    return templates.TemplateResponse("batch_detail.html", {
        "request": request,
        "batch_id": batch_id,
        "username": session["username"],
        "token": session["token"]
    })
