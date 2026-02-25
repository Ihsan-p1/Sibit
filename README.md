# SIBIT - Sistem Tracking Batch Bibit

## Project Overview
SIBIT (Sistem Tracking Batch Bibit) is an integrated web-based tracking and monitoring system designed to manage seedling batches from planting to distribution. It enables real-time tracking, life-cycle monitoring, and status reporting of seedlings, ensuring optimal survival rates and efficient data management.

## Key Features
- **Batch Management**: Seamlessly create, update, and manage details of seed batches including variety, location, and initial quantity.
- **Real-time Tracking**: Monitor the live count and mortality rate automatically calculated throughout the seedling's lifecycle.
- **Interactive Dashboard**: View key metrics, survival percentages, and overall progress via a centralized interactive dashboard.
- **Audit Log System**: Track historical changes to batch statuses for accountability and auditing.
- **QR Code Integration**: Automatically generate scannable QR codes for each batch, linking directly to its respective detail page.
- **Map View & Reporting**: Geographic distribution tracking and Excel-based summary exports for offline analysis.

## Tech Stack
- **Backend Framework**: FastAPI (Python)
- **Database Architecture**: SQLModel utilizing SQLite (extensible to PostgreSQL via psycopg2)
- **Frontend Layer**: HTML, Bootstrap 5, Jinja2 Templates
- **Data Rendering**: Pandas, internal RESTful API structure

## Prerequisites
- Python 3.9+
- pip (Python package installer)

## Installation Guide

1. **Clone the repository**
   ```bash
   git clone https://github.com/Ihsan-p1/Sibit.git
   cd Sibit
   ```

2. **Set up the virtual environment**
   ```bash
   python -m venv venv
   ```
   Activate the environment:
   - On Windows: `venv\Scripts\activate`
   - On macOS/Linux: `source venv/bin/activate`

3. **Install dependencies**
   ```bash
   pip install -r backend/requirements.txt
   ```

4. **Environment Variables Configuration**
   Create a `.env` file in the root directory. This project uses SQLite by default if `.env` or `DATABASE_URL` is omitted.
   ```env
   DATABASE_URL=sqlite:///sibit.db
   ```

## Usage Instructions

1. **Start the application**
   Execute the `run.py` script to launch the FastAPI backend configured with Uvicorn.
   ```bash
   python run.py
   ```
2. **Access the application**
   Open a web browser and navigate to `http://localhost:8000`.

## Project Structure
```text
SIBIT/
|-- backend/
|   |-- utils/         # Helper functions (e.g., QR Code generation)
|   |-- db.py          # Database initialization and connection pool
|   |-- main.py        # Core application routes and logic
|   |-- models.py      # SQLModel schema definitions
|   `-- requirements.txt
|-- frontend/          # Jinja2 HTML templates
|-- static/            # Static assets (uploads, generated QR codes)
|-- .gitignore
|-- run.py             # Entry point for development server
`-- README.md
```
