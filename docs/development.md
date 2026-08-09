# Development Workflow

## Development Notes

The project is under active development and this repository currently contains foundational scaffolding only.

## Local Commands

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -m uvicorn app.main:app --reload
```

```bash
cd mobile
flutter pub get
flutter run
```

## Database

This project is configured for PostgreSQL and SQLAlchemy. Alembic is initialized in the backend for future migrations.

## Validation

The backend health endpoint can be checked through GET /health.
