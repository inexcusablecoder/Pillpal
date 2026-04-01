# PillPal — System Architecture

**Team:** CodeConquerors · **Track:** Healthcare  
**Problem statement:** [Medicine Reminder and Health Monitoring App](https://github.com/inexcusablecoder/Pillpal) — remind patients to take medications, send notifications, track schedules, and maintain intake history.

---

## Stack Overview

| Layer | Technology |
|-------|------------|
| Mobile app | Flutter (Android primary) |
| API | FastAPI (Python) |
| Database | PostgreSQL |
| Auth | JWT (email/password) or session tokens stored securely on device |

---

## High-Level Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER APP (Android)                         │
│  Screens: Auth · Dashboard · Medicines · History · Profile       │
│  Local: flutter_local_notifications · timezone · secure storage  │
└────────────────────────────┬────────────────────────────────────┘
                             │  HTTPS / JSON
                             │  Authorization: Bearer <JWT>
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FASTAPI (pillpal-api)                        │
│  Routers: /auth · /users · /medicines · /dose-logs · /health     │
│  Services: reminders logic · missed-dose job · adherence         │
└────────────────────────────┬────────────────────────────────────┘
                             │  SQL (async)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    PostgreSQL                                   │
│  users · medicines · dose_logs (see schema below)               │
└─────────────────────────────────────────────────────────────────┘
```

---

## PostgreSQL Schema (MVP)

### `users`
| Column | Type | Notes |
|--------|------|--------|
| id | UUID PK | |
| email | VARCHAR UNIQUE | login |
| password_hash | VARCHAR | bcrypt |
| display_name | VARCHAR | optional |
| created_at | TIMESTAMPTZ | |

### `medicines`
| Column | Type | Notes |
|--------|------|--------|
| id | UUID PK | |
| user_id | UUID FK → users | |
| name | VARCHAR | e.g. Metformin |
| dosage | VARCHAR | e.g. 500mg |
| scheduled_time | TIME | local wall-clock |
| frequency | VARCHAR | `daily` \| `weekly` (MVP: daily) |
| active | BOOLEAN | soft toggle |
| pill_count | INT | optional refill story |
| created_at | TIMESTAMPTZ | |

### `dose_logs`
| Column | Type | Notes |
|--------|------|--------|
| id | UUID PK | |
| user_id | UUID FK | |
| medicine_id | UUID FK | |
| scheduled_date | DATE | calendar day |
| scheduled_time | TIME | copy from medicine at generation |
| status | VARCHAR | `pending` \| `taken` \| `missed` |
| taken_at | TIMESTAMPTZ NULL | set when taken |
| created_at | TIMESTAMPTZ | |

Indexes: `(user_id, scheduled_date)`, `(medicine_id, scheduled_date)`.

---

## API Surface (MVP)

All routes use prefix **`/api/v1`**.

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/v1/auth/register` | Create user |
| POST | `/api/v1/auth/login` | Returns JWT |
| GET | `/api/v1/users/me` | Current user profile |
| GET | `/api/v1/medicines` | List medicines for user |
| POST | `/api/v1/medicines` | Add medicine |
| PATCH | `/api/v1/medicines/{id}` | Edit |
| DELETE | `/api/v1/medicines/{id}` | Delete |
| GET | `/api/v1/dose-logs/today` | Today’s doses |
| GET | `/api/v1/dose-logs/history` | Date range / last N days |
| POST | `/api/v1/dose-logs/{id}/take` | Mark taken |
| POST | `/api/v1/dose-logs/sync` | Generate today’s rows + apply missed logic (app on open + optional cron) |

---

## Backend Folder Layout (FastAPI)

```
backend/
├── app/
│   ├── main.py
│   ├── core/
│   │   ├── config.py          # settings from env
│   │   ├── security.py        # JWT, password hashing
│   │   └── database.py      # async SQLAlchemy session
│   ├── models/               # SQLAlchemy ORM
│   ├── schemas/              # Pydantic
│   ├── api/
│   │   └── v1/
│   │       ├── auth.py
│   │       ├── medicines.py
│   │       └── dose_logs.py
│   └── services/
│       ├── medicine_service.py
│       └── dose_log_service.py  # generate daily, mark missed
├── alembic/                  # migrations
├── requirements.txt
└── .env.example
```

---

## Flutter App Layout (reference for frontend)

```
pillpal_app/lib/
├── main.dart
├── config/
├── models/
├── services/
│   ├── api_client.dart       # Dio/http + JWT
│   └── notification_service.dart
├── screens/
│   ├── auth/
│   ├── dashboard/
│   ├── medicines/
│   └── history/
└── widgets/
```

---

## Reminder & Missed Logic

1. **On app open (or daily job):** API ensures `dose_logs` rows exist for each active medicine for **today** (idempotent).
2. **Flutter** schedules **local notifications** at `scheduled_time` (repeat daily) using `flutter_local_notifications` + `timezone`.
3. **Missed:** If a row is still `pending` after grace window (e.g. +60 min), API marks `missed` — triggered when app opens or via Snehal’s scheduled worker (cron / GitHub Actions hitting an endpoint).

---

## Non-Goals (post-MVP)

- iOS build polish, wearable, family profiles, advanced analytics — add after MVP is demo-ready.
