from fastapi import FastAPI

from app.api.routes.auth import router as auth_router
from app.db.base import Base
from app.db.session import engine
from app.models.user import User

app = FastAPI(title="Smart MedReminder API")

Base.metadata.create_all(bind=engine)

app.include_router(auth_router)


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "smart-medreminder-api",
    }
