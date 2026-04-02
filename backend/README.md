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

- **Unit / smoke:** health, root, favicon (no DB required for most checks).
- **Integration** (`@pytest.mark.integration`): auth, medicines, dose logs — need a running PostgreSQL and valid `DATABASE_URL` in `.env`. If the DB is unreachable, those tests are skipped automatically.

Tests use Starlette’s synchronous `TestClient` (one event loop for async SQLAlchemy).

## Project layout

```
backend/
├── app/
│   ├── main.py              # FastAPI app factory, CORS, health, exception handlers
│   ├── core/                # config, database, security, deps
│   ├── models/              # SQLAlchemy ORM
│   ├── schemas/             # Pydantic request/response models
│   ├── api/v1/              # Routers: auth, users, medicines, dose_logs
│   └── services/            # Dose log sync, missed logic
├── alembic/                 # Alembic migrations + env.py
├── alembic.ini
├── sql/                     # Optional raw SQL (e.g. init_schema.sql for pgAdmin)
├── scripts/                 # Dev helpers (e.g. verify_tables.py)
├── tests/                   # pytest + pytest.ini
├── requirements.txt
├── .env.example
└── README.md
```
