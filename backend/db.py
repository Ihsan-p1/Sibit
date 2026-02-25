from sqlmodel import create_engine, SQLModel, Session
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

database_url = os.getenv("DATABASE_URL")

if not database_url:
    # Alternative for development if .env is missing
    sqlite_file_name = "sibit.db"
    database_url = f"sqlite:///{sqlite_file_name}"
    connect_args = {"check_same_thread": False}
else:
    connect_args = {}

engine = create_engine(database_url, echo=True, connect_args=connect_args)

def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

def get_session():
    with Session(engine) as session:
        yield session
