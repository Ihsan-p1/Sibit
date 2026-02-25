from fastapi import FastAPI, Depends, HTTPException, Query, Request, File, UploadFile, Form
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, RedirectResponse, StreamingResponse
from fastapi.templating import Jinja2Templates
from sqlmodel import Session, select
from typing import List, Optional
import os
import shutil
import datetime
import pandas as pd
import io

from .db import engine, get_session, create_db_and_tables
from .models import Batch, AuditLog, BatchPhoto
from .utils.qr import generate_batch_qr

app = FastAPI(title="SIBIT - Sistem Tracking Batch Bibit")

# Konfigurasi Templates & Static
templates = Jinja2Templates(directory="templates")

if not os.path.exists("static/qrcodes"):
    os.makedirs("static/qrcodes")
if not os.path.exists("static/uploads"):
    os.makedirs("static/uploads")

app.mount("/static", StaticFiles(directory="static"), name="static")

@app.on_event("startup")
def on_startup():
    create_db_and_tables()

# --- WEB UI ROUTES ---

@app.get("/", response_class=HTMLResponse)
def index(request: Request, session: Session = Depends(get_session)):
    batches = session.exec(select(Batch).order_by(Batch.tanggal_semai.desc())).all()
    return templates.TemplateResponse("dashboard.html", {"request": request, "batches": batches})

@app.post("/batches/create")
async def web_create_batch(request: Request, session: Session = Depends(get_session)):
    form_data = await request.form()
    new_batch = Batch(
        batch_id=str(form_data.get("batch_id")),
        varietas=str(form_data.get("varietas")),
        jumlah_awal=int(form_data.get("jumlah_awal")),
        jumlah_hidup=int(form_data.get("jumlah_awal")),
        lokasi_bedeng=str(form_data.get("lokasi_bedeng")),
        tanggal_semai=datetime.datetime.utcnow()
    )
    
    session.add(new_batch)
    session.commit()
    session.refresh(new_batch)
    
    host = request.headers.get('host', 'localhost:8000')
    protocol = "https" if request.url.scheme == "https" else "http"
    base_url = f"{protocol}://{host}"
    
    batch_details = {
        "varietas": new_batch.varietas,
        "lokasi": new_batch.lokasi_bedeng,
        "tanggal_semai": new_batch.tanggal_semai,
        "jumlah_awal": new_batch.jumlah_awal
    }
    
    new_batch.qr_path = generate_batch_qr(new_batch.batch_id, base_url, batch_details)
    session.add(new_batch)
    session.commit()
    
    return RedirectResponse(url="/", status_code=303)

@app.get("/update-batch/{batch_id}", response_class=HTMLResponse)
def update_batch_view(batch_id: str, request: Request, session: Session = Depends(get_session)):
    statement = select(Batch).where(Batch.batch_id == batch_id)
    batch = session.exec(statement).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch tidak ditemukan")
    return templates.TemplateResponse("update_batch.html", {"request": request, "batch": batch})

@app.post("/batches/update/{batch_id}")
async def web_update_mortality(
    batch_id: str,
    session: Session = Depends(get_session),
    jumlah_hidup: int = Form(...),
    catatan: str = Form(None),
    photo: UploadFile = File(None)
):
    statement = select(Batch).where(Batch.batch_id == batch_id)
    db_batch = session.exec(statement).first()
    if not db_batch:
        raise HTTPException(status_code=404, detail="Batch tidak ditemukan")
    
    nilai_lama = db_batch.jumlah_hidup
    
    # Audit Log
    if nilai_lama != jumlah_hidup:
        log = AuditLog(
            batch_id=batch_id,
            aksi="Update Jumlah Hidup",
            nilai_lama=str(nilai_lama),
            nilai_baru=str(jumlah_hidup),
            keterangan=catatan
        )
        session.add(log)
        db_batch.jumlah_hidup = jumlah_hidup

    # Handle Photo Upload
    if photo and photo.filename:
        ext = os.path.splitext(photo.filename)[1]
        filename = f"{batch_id}_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}{ext}"
        photo_dir = "static/uploads"
        photo_path = os.path.join(photo_dir, filename)
        with open(photo_path, "wb") as buffer:
            shutil.copyfileobj(photo.file, buffer)
        
        new_photo = BatchPhoto(
            batch_id=batch_id,
            photo_path=f"/static/uploads/{filename}",
            catatan=catatan
        )
        session.add(new_photo)

    session.add(db_batch)
    session.commit()
    
    return RedirectResponse(url=f"/batch-details/{batch_id}", status_code=303)

@app.get("/batch-details/{batch_id}", response_class=HTMLResponse)
def batch_details_view(batch_id: str, request: Request, session: Session = Depends(get_session)):
    batch = session.exec(select(Batch).where(Batch.batch_id == batch_id)).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch tidak ditemukan")
    
    logs = session.exec(select(AuditLog).where(AuditLog.batch_id == batch_id).order_by(AuditLog.tanggal.desc())).all()
    photos = session.exec(select(BatchPhoto).where(BatchPhoto.batch_id == batch_id).order_by(BatchPhoto.tanggal.desc())).all()
    mortality_rate = (batch.jumlah_hidup / batch.jumlah_awal * 100) if batch.jumlah_awal > 0 else 0
    
    return templates.TemplateResponse("batch_details.html", {
        "request": request, "batch": batch, "logs": logs, "photos": photos, "mortality_rate": mortality_rate
    })

@app.get("/analytics", response_class=HTMLResponse)
def analytics_view(request: Request, session: Session = Depends(get_session)):
    batches = session.exec(select(Batch)).all()
    batches_data = []
    for b in batches:
        d = b.dict()
        d['tanggal_semai'] = b.tanggal_semai.strftime('%Y-%m-%d')
        batches_data.append(d)
        
    return templates.TemplateResponse("analytics.html", {
        "request": request, "batches": batches, "batches_json": batches_data
    })

@app.get("/map", response_class=HTMLResponse)
def map_view(request: Request, session: Session = Depends(get_session)):
    batches = session.exec(select(Batch)).all()
    return templates.TemplateResponse("map.html", {"request": request, "batches": batches})

@app.get("/api/reports/excel")
def export_excel(session: Session = Depends(get_session)):
    batches = session.exec(select(Batch)).all()
    data = []
    for b in batches:
        data.append({
            "Batch ID": b.batch_id, "Varietas": b.varietas, "Lokasi": b.lokasi_bedeng,
            "Tanggal Semai": b.tanggal_semai.strftime('%Y-%m-%d'), "Umur (Hari)": b.umur_hari,
            "Jumlah Awal": b.jumlah_awal, "Jumlah Hidup": b.jumlah_hidup,
            "Mortalitas (%)": 100 - b.persentase_hidup, "Status": b.status
        })
    
    df = pd.DataFrame(data)
    output = io.BytesIO()
    with pd.ExcelWriter(output, engine='openpyxl') as writer:
        df.to_excel(writer, index=False, sheet_name='Data Batch')
    
    output.seek(0)
    headers = {'Content-Disposition': 'attachment; filename="Laporan_SIBIT.xlsx"'}
    return StreamingResponse(output, headers=headers, media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

@app.post("/batches/delete/{batch_id}")
async def web_delete_batch(batch_id: str, session: Session = Depends(get_session)):
    batch = session.exec(select(Batch).where(Batch.batch_id == batch_id)).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch tidak ditemukan")
    
    if batch.qr_path:
        file_path = batch.qr_path.lstrip('/')
        if os.path.exists(file_path):
            try: os.remove(file_path)
            except: pass

    session.delete(batch)
    session.commit()
    return RedirectResponse(url="/", status_code=303)
