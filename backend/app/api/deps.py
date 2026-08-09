from typing import Generator

from app.db.session import SessionLocal


def get_db() -> Generator:
    """FastAPI dependency for SQLAlchemy sessions."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
