import os
from sqlmodel import SQLModel, create_engine, Session
from dotenv import load_dotenv

load_dotenv()

# We are using PostgreSQL as requested
POSTGRES_USER = os.getenv("POSTGRES_USER")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD")
POSTGRES_SERVER = os.getenv("POSTGRES_SERVER", "localhost")
POSTGRES_PORT = os.getenv("POSTGRES_PORT", "5432")
POSTGRES_DB = os.getenv("POSTGRES_DB", "sibit_app")

# DATABASE_URL = f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_SERVER}:{POSTGRES_PORT}/{POSTGRES_DB}"
# Fallback to sqlite if postgres is not available during dev
DATABASE_URL = "sqlite:///sibit_app.db"

# Check if DB_ECHO is explicitly True (useful for development)
DB_ECHO = os.getenv("DB_ECHO", "False").lower() in ("true", "1", "t")

engine = create_engine(DATABASE_URL, echo=DB_ECHO)

def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

def get_session():
    with Session(engine) as session:
        yield session
