# Smart MedReminder

Smart MedReminder is an AI-driven cross-platform mobile application for medication scheduling, dose reminders, pill inventory tracking, refill management, caregiver notifications, and adherence analytics.

## Project Description

This project is an active development effort to support patients and caregivers with medication reminder workflows, inventory visibility, refill management, and scheduled adherence tracking.

## Main Objectives

- Provide safe medication reminder workflows
- Support medication inventory and refill visibility
- Support caregiver escalation for missed dose events
- Support future OCR and AI-assisted prescription intake
- Keep a clean modular architecture for mobile, API, database, and service integration layers

## Technology Stack

- Mobile: Flutter and Dart
- Backend: Python, FastAPI, Uvicorn
- Database: PostgreSQL, SQLAlchemy, Alembic
- Authentication: JWT, Argon2
- AI: Gemini API
- OCR: Google ML Kit on the mobile application
- Notifications: Firebase Cloud Messaging and Flutter local notifications
- SMS: Twilio

## High-Level Architecture

The project is organized into three major layers:

- Flutter mobile application for the user-facing experience
- FastAPI backend for business logic and API services
- PostgreSQL database with SQLAlchemy and Alembic migrations

External adapters for OCR, AI extraction, messaging, and SMS are intentionally isolated behind service boundaries.

## Current Development Status

The project is under active development. The current task is foundational only: folder structure, API health endpoint, configuration, database/session preparation, Alembic scaffolding, Flutter app skeleton, and documentation.

## Backend Setup Instructions

1. Create and activate a Python virtual environment.
2. Install dependencies from backend/requirements.txt.
3. Copy backend/.env.example to backend/.env if needed and adjust local environment values.
4. Run the API with uvicorn app.main:app --reload from the backend directory.

## Flutter Setup Instructions

1. Install Flutter SDK and ensure the flutter command is available in PATH.
2. Navigate to the mobile directory.
3. Use flutter pub get if dependencies are added in the future.
4. Run flutter run.

## Environment Variable Setup

Environment-dependent configuration is loaded from .env files. A root .env.example and a backend/.env.example are present with placeholder values only. Do not commit real credentials.

## How to Run the Backend

```bash
cd backend
python -m uvicorn app.main:app --reload
```

## How to Run the Flutter Application

```bash
cd mobile
flutter pub get
flutter run
```
