# SIBIT - Sistem Informasi Bibit Kelapa Sawit

## Overview

SIBIT (Sistem Informasi Bibit) is a web-based tracking and monitoring system designed for managing palm oil seedling batches from planting to distribution. The system enables real-time tracking, lifecycle monitoring, and status reporting to ensure optimal survival rates and efficient data management.

## Features

- **Batch Management** — Create, update, and manage seedling batch data including variety, location, and initial quantity.
- **Real-time Tracking** — Monitor live seedling count with automatic mortality rate calculation.
- **Interactive Dashboard** — View key metrics, survival percentages, and overall progress through a centralized interface.
- **Audit Log** — Track all historical changes to batch statuses for accountability and traceability.
- **QR Code Integration** — Automatically generate scannable QR codes for each batch, linking to its detail page.
- **Map View and Reporting** — Geographic distribution tracking and Excel-based summary exports.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend | FastAPI (Python) |
| Database | SQLModel with SQLite |
| Frontend | HTML, Bootstrap 5, Jinja2 Templates |
| Data Processing | Pandas |

## Prerequisites

- Python 3.9 or higher
- pip (Python package installer)

## Installation

1. **Clone the repository**

   ```bash
   git clone -b v1-web https://github.com/Ihsan-p1/Sibit.git
   cd Sibit
   ```

2. **Create and activate a virtual environment**

   ```bash
   python -m venv venv
   ```

   - Windows: `venv\Scripts\activate`
   - macOS/Linux: `source venv/bin/activate`

3. **Install dependencies**

   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables**

   Create a `.env` file in the root directory:

   ```env
   DATABASE_URL=sqlite:///sibit.db
   ```

## Usage

1. Start the application:

   ```bash
   python run.py
   ```

2. Open a browser and navigate to `http://localhost:8000`.

## Project Structure

```
SIBIT/
├── backend/
│   ├── utils/            # Helper functions (QR Code generation)
│   ├── db.py             # Database initialization
│   ├── main.py           # Application routes and logic
│   ├── models.py         # SQLModel schema definitions
│   └── requirements.txt
├── frontend/             # Jinja2 HTML templates
├── static/               # Static assets (uploads, QR codes)
├── .gitignore
├── run.py                # Development server entry point
└── README.md
```
