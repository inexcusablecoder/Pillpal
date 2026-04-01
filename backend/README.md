# PillPal API (FastAPI)

Backend for the PillPal medicine reminder app: JWT auth, medicines CRUD, dose logs (sync, take, today, history, missed logic).

## Requirements

- Python 3.10+
- PostgreSQL 14+ (or compatible)

## Setup

```bash
cd backend
py -m venv .venv
.venv\Scripts\activate   # Windows
pip install -r requirements.txt
copy .env.example .env   # edit DATABASE_URL, JWT_SECRET
```

## Database

```bash
py -m alembic upgrade head
```

`DATABASE_URL` uses the `postgresql://` scheme; the app converts it to `asyncpg` for runtime.

## Run

```bash
py -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- **Liveness:** `GET /health`
- **Readiness (DB ping):** `GET /health/ready`
- **API docs (non-production):** `/docs`, `/redoc`
- **API prefix:** `/api/v1` (see `API_V1_PREFIX` in `.env`)

## Configuration

| Variable | Purpose |
|----------|---------|
| `ENVIRONMENT` | `development` \| `staging` \| `production` — production hides OpenAPI docs and rejects default `JWT_SECRET` |
| `DATABASE_URL` | PostgreSQL URL (encode special chars in password, e.g. `@` → `%40`) |
| `JWT_SECRET` | Strong random string for signing tokens |
| `JWT_ALGORITHM` | Default `HS256` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Token lifetime |
| `DOSE_GRACE_MINUTES` | After scheduled time, pending → missed |
| `CORS_ORIGINS` | `*` or comma-separated origins; `*` disables `credentials` |

## Tests

```bash
py -m pytest
```

## Project layout

```
app/
  main.py           # FastAPI app, CORS, exception handlers, health
  core/             # config, database, security, deps
  models/           # SQLAlchemy ORM
  schemas/          # Pydantic
  api/v1/           # Routers (auth, users, medicines, dose-logs)
  services/         # Dose log sync / missed logic
alembic/            # Migrations
tests/              # Pytest
```
