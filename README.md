# SIBIT: Sistem Informasi Bibit

SIBIT tracks seedling batches from nursery to field. Version 2 is built mobile first with
an offline queue, because the people entering the data work in places where the network
drops.

Three parts:

- Backend API: FastAPI, serving both the mobile app and the admin dashboard.
- Mobile app: Flutter, for field workers recording and updating batch data.
- Admin dashboard: server-rendered pages for verifying and monitoring batches.

## Features

### Mobile app
- Add and update seedling batch data in the field
- QR code scanning to pull up a batch
- Offline mode with a local SQLite queue that syncs when the network returns
- Photo documentation, compressed before upload
- Root and jailbreak detection, SSL pinning, and 2FA login (added in v2.1)

### Admin dashboard
- Overview with summary cards and survival-rate statistics
- Card and table views of batch data
- Circular gauge per batch for survival rate
- Health classification in three levels: healthy, needs attention, critical
- Batch verification and approval workflow
- Audit log with the full change history

### Backend
- REST API with JWT for the mobile app and signed cookies for the dashboard
- Refresh tokens, so a mobile session survives without a long-lived access token
- TOTP two-factor authentication through `pyotp`
- Rate limiting with `slowapi`, 5 requests per minute on login
- Security headers on every response, including HSTS and `X-Frame-Options: DENY`
- Input sanitising with `bleach`
- GZip compression for responses over 500 bytes
- Cloudinary photo storage when `CLOUDINARY_URL` is set, local disk otherwise
- SQLModel over SQLite

## Tech stack

| Component | Technology |
|-----------|-----------|
| Backend | FastAPI (Python 3.9+) |
| Mobile app | Flutter (Dart) |
| Database | SQLModel with SQLite |
| Web dashboard | Jinja2 templates, HTML, CSS, JavaScript |
| Photo storage | Cloudinary, or local disk |
| Auth | JWT plus refresh tokens (mobile), signed cookies (web), TOTP 2FA |

## Prerequisites

- Python 3.9 or higher
- Flutter SDK 3.11 or higher
- Android Studio, or VS Code with the Flutter extension

## Installation

### Backend

```bash
git clone https://github.com/Ihsan-p1/Sibit.git
cd Sibit/backend

python -m venv venv
venv\Scripts\activate            # Windows
source venv/bin/activate         # macOS, Linux

pip install -r requirements.txt
```

Configuration is optional. To set a signing key and cloud photo storage, create
`backend/.env`:

```env
SECRET_KEY=your-secret-key
CLOUDINARY_URL=cloudinary://API_KEY:API_SECRET@CLOUD_NAME
```

Without `CLOUDINARY_URL`, photos go to `backend/static/uploads/`.

Start the server:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Mobile app

```bash
cd mobile
flutter pub get
```

Set the server address in `lib/services/api_service.dart`:

```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:8000';
```

Then:

```bash
flutter run
```

### Admin dashboard

The backend serves it. No separate setup.

- URL: `http://localhost:8000/admin/login`
- On an empty database, startup seeds one account: `admin` / `admin123`

Change that password before the server is reachable by anyone else. The seed value is in
this repository, so it is public knowledge.

## Project structure

```
SIBIT/
├── backend/
│   ├── static/
│   │   ├── css/              # Dashboard stylesheets
│   │   └── uploads/          # Local photo storage
│   ├── templates/            # Jinja2 templates
│   │   ├── login.html
│   │   ├── dashboard.html
│   │   └── batch_detail.html
│   ├── db.py                 # Database initialisation and admin seeding
│   ├── main.py               # API routes, dashboard routes, middleware
│   ├── models.py             # SQLModel schema
│   ├── migrate_lokasi.py     # One-off location migration
│   ├── API_DOCS.md           # Endpoint reference
│   └── requirements.txt
├── mobile/
│   ├── lib/
│   │   ├── screens/          # UI screens
│   │   ├── services/         # API client and offline queue
│   │   └── main.dart
│   └── pubspec.yaml
└── README.md
```

## API

Swagger UI is at `/docs` while the backend runs. `backend/API_DOCS.md` has the written
reference.

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/login` | Authenticate, rate limited to 5 per minute |
| POST | `/api/refresh-token` | Exchange a refresh token for a new access token |
| POST | `/api/logout` | Revoke the current refresh token |
| POST | `/api/2fa/setup` | Generate a TOTP secret and provisioning URI |
| GET | `/api/batches` | List all batches |
| GET | `/api/batches/{id}` | Batch details |
| POST | `/api/batches/create` | Create a batch |
| POST | `/api/batches/update/{id}` | Update batch data |
| PUT | `/api/batches/verify/{id}` | Verify or reject a batch |
| GET | `/api/analytics` | Dashboard analytics |
| DELETE | `/api/batches/{id}` | Delete a batch |

## Versions

| Version | Description |
|---------|-------------|
| v1.0 | Web application on Flask with an HTML and Bootstrap frontend. Kept on the `v1-web` branch. |
| v2.0 | Mobile-first rebuild: FastAPI, Flutter, offline mode, admin dashboard |
| v2.1 | Refresh tokens, 2FA, security headers, rate limiting; SSL pinning and root detection on mobile |
