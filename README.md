# PillPal — Medicine Reminder & Health Monitoring

**Team:** CodeConquerors · **Hackathon track:** Healthcare  

**Problem statement:** Build a mobile app that reminds patients to take medications, sends notifications, tracks schedules, and maintains a history of medicine intake to improve adherence.

## Tech stack

| Layer | Stack |
|-------|--------|
| Mobile | Flutter (Android) |
| API | FastAPI |
| Database | PostgreSQL |

## Run locally

Terminal 1 — API (from `backend/`):

```bash
py -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Terminal 2 — app (from `frontend/pillpal_app/`):

```bash
flutter pub get && flutter run
```

Configure DB via `backend/.env` (see `backend/.env.example`). Details: [frontend/pillpal_app/README.md](frontend/pillpal_app/README.md).

## Documentation

| File | Contents |
|------|----------|
| [docs/architecture.md](docs/architecture.md) | System design, PostgreSQL schema, API outline, folder layout |
| [docs/decision.md](docs/decision.md) | Technology choices and rationale |
| [docs/work-distribution.md](docs/work-distribution.md) | Team roles (Nikhil, Shreyash, CR, Snehal), phased step-by-step plan |
| [docs/backend-plan.md](docs/backend-plan.md) | Full feature list, backend implementation, work breakdown, **backend phases 1–6** |
| [frontend/README.md](frontend/README.md) | Where the Flutter app lives (`frontend/pillpal_app/`) |

## Team

| Role | Name |
|------|------|
| Frontend | Nikhil |
| Backend | Shreyash |
| UI/UX | CR |
| DevOps / QA | Snehal |

---

**Repository layout:** `backend/` (FastAPI), `frontend/pillpal_app/` (Flutter), `docs/` (architecture and planning). Work in the Flutter project under `frontend/`, not at repo root.
