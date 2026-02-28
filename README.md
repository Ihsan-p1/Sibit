# SIBIT - Sistem Informasi Bibit 

## Overview

SIBIT (Sistem Informasi Bibit) is an integrated monitoring platform for seedling management. Version 2 introduces a mobile-first architecture with offline capability, designed for field workers operating in areas with limited connectivity.

The system consists of three components:

- **Backend API** — FastAPI-based REST API serving both mobile and web clients.
- **Mobile Application** — Flutter-based app for field workers to record and update seedling data.
- **Admin Dashboard** — Web-based interface for administrators to verify, approve, and monitor batch data.

## Features

### Mobile Application
- Add and update seedling batch data directly from the field
- QR Code scanning for quick batch identification
- Offline mode with local SQLite queue and automatic synchronization
- Photo documentation with compression for low-bandwidth environments

### Admin Dashboard
- Real-time overview with summary cards and survival rate statistics
- Card and table view toggle for batch data visualization
- Circular gauge indicators for survival rate per batch
- Three-level health classification system (Healthy, Needs Attention, Critical)
- Batch verification and approval workflow
- Audit log with full change history

### Backend
- RESTful API with JWT authentication for mobile and session-based auth for web
- GZip response compression for reduced bandwidth usage
- Cloudinary integration for cloud-based photo storage (optional, falls back to local storage)
- SQLite database with SQLModel ORM

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend | FastAPI (Python 3.9+) |
| Mobile App | Flutter (Dart) |
| Database | SQLModel with SQLite |
| Web Dashboard | HTML, CSS, JavaScript, Jinja2 |
| Photo Storage | Cloudinary (optional) / Local |
| Authentication | JWT (mobile), Signed Cookies (web) |

## Prerequisites

- Python 3.9 or higher
- Flutter SDK 3.11 or higher
- Android Studio or VS Code with Flutter extension

## Installation

### Backend

1. **Clone the repository**

   ```bash
   git clone https://github.com/Ihsan-p1/Sibit.git
   cd Sibit
   ```

2. **Create and activate a virtual environment**

   ```bash
   cd backend
   python -m venv venv
   ```

   - Windows: `venv\Scripts\activate`
   - macOS/Linux: `source venv/bin/activate`

3. **Install dependencies**

   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables** (optional)

   Create a `.env` file in the `backend/` directory:

   ```env
   SECRET_KEY=your-secret-key
   CLOUDINARY_URL=cloudinary://API_KEY:API_SECRET@CLOUD_NAME
   ```

   If `CLOUDINARY_URL` is not set, photos will be saved to local storage.

5. **Start the server**

   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

### Mobile Application

1. **Navigate to the mobile directory**

   ```bash
   cd mobile
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure the API endpoint**

   Edit `lib/services/api_service.dart` and set `baseUrl` to your server address:

   ```dart
   static const String baseUrl = 'http://YOUR_SERVER_IP:8000';
   ```

4. **Run the application**

   ```bash
   flutter run
   ```

### Admin Dashboard

The admin dashboard is served automatically by the backend at `/admin/login`. No separate setup is required.

- URL: `http://localhost:8000/admin/login`
- Default credentials: `admin` / `admin123`

## Project Structure

```
SIBIT/
├── backend/
│   ├── static/
│   │   ├── css/              # Dashboard stylesheets
│   │   └── uploads/          # Local photo storage
│   ├── templates/            # Jinja2 HTML templates
│   │   ├── login.html
│   │   ├── dashboard.html
│   │   └── batch_detail.html
│   ├── db.py                 # Database initialization
│   ├── main.py               # API routes and web routes
│   ├── models.py             # SQLModel schema definitions
│   └── requirements.txt
├── mobile/
│   ├── lib/
│   │   ├── screens/          # UI screens
│   │   ├── services/         # API and offline services
│   │   └── main.dart         # Application entry point
│   └── pubspec.yaml
├── .gitignore
└── README.md
```

## API Documentation

The API is documented at `/docs` (Swagger UI) when the backend is running.

Key endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/login` | Authenticate user |
| GET | `/api/batches` | List all batches |
| GET | `/api/batches/{id}` | Get batch details |
| POST | `/api/batches/create` | Create new batch |
| POST | `/api/batches/update/{id}` | Update batch data |
| PUT | `/api/batches/verify/{id}` | Verify or reject batch |
| GET | `/api/analytics` | Get dashboard analytics |
| DELETE | `/api/batches/{id}` | Delete a batch |

## Version History

| Version | Description |
|---------|-------------|
| v1.0 | Web application using Flask with HTML/Bootstrap frontend |
| v2.0 | Mobile-first architecture with FastAPI, Flutter, offline mode, and admin dashboard |
