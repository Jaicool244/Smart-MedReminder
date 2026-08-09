# Smart MedReminder Architecture

This project is organized around a layered architecture following the approved design.

## Approved High-Level Architecture

- Flutter mobile client handles user-facing workflows.
- FastAPI API layer exposes request/response contracts.
- Service layer implements business workflows such as medication, schedule, inventory, and refill logic.
- Repository layer provides relational database access.
- PostgreSQL remains the source of truth.
- External adapters isolate OCR, AI, FCM push, SMS, and notification components.

This foundation is intentionally limited to the initial scaffolding and health endpoint.
