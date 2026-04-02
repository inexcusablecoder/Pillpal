# PillPal — Full Backend Plan

**Owner:** Shreyash (backend) · **Stack:** FastAPI + PostgreSQL + JWT  
**Companion docs:** `architecture.md` (schema & routes), `work-distribution.md` (whole team phases)

This document answers:

1. What **application features** we ship (product view).  
2. How the **backend** implements each feature.  
3. What **work** each feature requires on the API side.  
4. A **phase-wise backend roadmap** (order of implementation).

---

## Part A — Application features (what the user sees)

These map to the hackathon problem statement and MVP list.

| # | Feature | User-visible behaviour |
|---|---------|-------------------------|
| F1 | **Register / login** | Create account with email + password; sign in; stay logged in with token |
| F2 | **Profile** | See name/email; optional edit display name |
| F3 | **Add medicine** | Save name, dosage, scheduled time, frequency (MVP: daily) |
| F4 | **List medicines** | See all active medicines; sort by time |
| F5 | **Edit medicine** | Change fields; cancel old notifications on client |
| F6 | **Delete medicine** | Remove medicine; stop future dose rows for it |
| F7 | **Today’s schedule** | See today’s dose rows with status: pending / taken / missed |
| F8 | **Mark taken** | Tap taken → status updates; timestamp stored |
| F9 | **Auto-missed** | If time passed + grace window and still pending → missed (server truth) |
| F10 | **History** | Browse past days / date range; see taken vs missed pattern |
| F11 | **Sync on open** | Opening app ensures today’s dose rows exist + runs missed logic |

**Out of scope for backend v1 (can be frontend-only or later):** push notification payload from server, PDF export, adherence % (optional small endpoint later).

---

## Part B — Backend responsibility per feature

| Feature | Backend must… |
|---------|----------------|
| F1 | Store `users`, hash passwords (bcrypt), issue JWT (access token), validate on every protected route |
| F2 | Expose `GET/PATCH /users/me` |
| F3 | `POST /medicines` with validation; link `user_id` from JWT |
| F4 | `GET /medicines?active_only=true` |
| F5 | `PATCH /medicines/{id}`; ensure row belongs to user |
| F6 | `DELETE /medicines/{id}`; optionally cascade or soft-delete future `dose_logs` |
| F7 | `GET /dose-logs/today` after sync ensures rows exist |
| F8 | `POST /dose-logs/{id}/take` — transaction: set `status=taken`, `taken_at=now()` |
| F9 | Function `apply_missed_logic(user_id, as_of)` — pending rows whose scheduled_time + grace < now → `missed` |
| F10 | `GET /dose-logs/history?from=&to=` or `?days=30` |
| F11 | `POST /dose-logs/sync` (or `POST /scheduler/daily`) — idempotent “ensure today’s rows” + call F9 |

---

## Part C — How each feature is implemented (technical)

### F1 — Auth

- **Tables:** `users` (`id`, `email` unique, `password_hash`, `display_name`, `created_at`).
- **Register:** Validate email format, min password length; bcrypt hash; insert user; return JWT.
- **Login:** Lookup by email; verify bcrypt; return JWT.
- **JWT payload:** `sub` = user UUID, `exp` = expiry (e.g. 7 days).
- **Middleware/dependency:** FastAPI `Depends(get_current_user)` decodes JWT, loads `user_id`.

### F2 — Profile

- **GET /users/me:** Return user fields (no password).
- **PATCH /users/me:** Update `display_name` only (email change = stretch).

### F3–F6 — Medicines CRUD

- **Table:** `medicines` — see `architecture.md`.
- **Ownership:** Every query filters `user_id = current_user.id`.
- **Time:** Store `scheduled_time` as `TIME` or `TIME WITH TIME ZONE` consistently (document for Nikhil).
- **Delete:** Hard delete medicine + delete future `dose_logs` for that medicine, or soft-delete medicine and hide from list.

### F7–F11 — Dose logs & status

- **Table:** `dose_logs` — one row per medicine per calendar day (for daily frequency).
- **Generation (sync):** For each active medicine, if no row exists for `today` (user’s date or UTC date — **pick one rule and document**), `INSERT` with `status=pending`.
- **Mark taken:** Only if `status=pending` and `user_id` matches; set `taken_at`, `status=taken`.
- **Missed:** For rows with `status=pending` and `scheduled_date = today` and `now > scheduled_time + grace_minutes`, set `status=missed`.
- **History:** `SELECT` with `scheduled_date BETWEEN from AND to ORDER BY scheduled_date DESC, scheduled_time`.

**Idempotency:** `sync` can be called twice safely (no duplicate rows — unique constraint `(medicine_id, scheduled_date)` recommended).

---

## Part D — Work breakdown (backend effort)

| Area | Tasks | Rough size |
|------|--------|------------|
| **Project setup** | FastAPI app, `settings`, CORS, `/health`, `.env.example` | S |
| **DB** | SQLAlchemy models, Alembic, PostgreSQL URL | M |
| **Auth** | Register, login, JWT, `get_current_user` | M |
| **Medicines** | CRUD router + service + tests | M |
| **Dose logs** | Model, sync, take, missed logic, list today/history | L |
| **Polish** | Error format, validation messages, OpenAPI docs | S |
| **Deploy** | Snehal: env, HTTPS URL (backend code: Dockerfile optional) | M (ops) |

---

## Part E — Phase-wise backend plan (Shreyash)

Order is strict: later phases depend on earlier ones.

### Backend Phase 1 — Foundation

- **Goal:** Runnable API + DB connection + health check.
- **Deliverables:**
  - `backend/` FastAPI project structure (`app/main.py`, `core/config.py`, `core/database.py`).
  - `GET /health` (and optionally `GET /` → redirect to docs).
  - Async SQLAlchemy engine + session factory.
  - `.env.example`: `DATABASE_URL`, `JWT_SECRET`, `JWT_ALGORITHM`, `ACCESS_TOKEN_EXPIRE_MINUTES`.
  - Alembic initialized; first migration empty or stub.
- **Exit criteria:** `uvicorn` runs; DB connects; `/health` returns 200.

---

### Backend Phase 2 — Users & authentication

- **Goal:** Register, login, JWT, protected route.
- **Deliverables:**
  - `users` table migration.
  - `POST /api/v1/auth/register` — body: `email`, `password`, optional `display_name`.
  - `POST /api/v1/auth/login` — body: `email`, `password` → `{ "access_token", "token_type", "expires_in" }`.
  - `GET /api/v1/users/me` — Bearer JWT → user profile.
  - Password hashing (bcrypt or passlib).
  - `core/security.py`: create token, decode token, `get_current_user_id`.
- **Exit criteria:** Postman can register, login, and call `/users/me` with token.

---

### Backend Phase 3 — Medicines CRUD

- **Goal:** Full medicine lifecycle in PostgreSQL.
- **Deliverables:**
  - `medicines` table migration (FK `user_id`).
  - `GET /api/v1/medicines` — list for current user.
  - `POST /api/v1/medicines` — create.
  - `PATCH /api/v1/medicines/{medicine_id}` — update.
  - `DELETE /api/v1/medicines/{medicine_id}` — delete + policy for dose_logs.
  - Pydantic schemas for request/response.
  - 404 if medicine not found or wrong user.
- **Exit criteria:** All CRUD operations work via Swagger; data visible in DB.

---

### Backend Phase 4 — Dose logs: schema + sync + take

- **Goal:** Today’s rows exist; user can mark taken.
- **Deliverables:**
  - `dose_logs` table + unique `(medicine_id, scheduled_date)`.
  - `POST /api/v1/dose-logs/sync` — for current user: ensure one row per active medicine for **today** (idempotent inserts).
  - `GET /api/v1/dose-logs/today` — returns today’s rows with medicine name denormalized or joined.
  - `POST /api/v1/dose-logs/{log_id}/take` — validate pending → taken.
- **Exit criteria:** After sync, today shows pending; after take, status is taken with `taken_at`.

---

### Backend Phase 5 — Missed logic + history

- **Goal:** Automatic missed + history API.
- **Deliverables:**
  - Inside `sync` (or separate internal function called after sync): `apply_missed_doses(user_id)` using grace window (e.g. 60 minutes after scheduled time).
  - `GET /api/v1/dose-logs/history?days=30` or `?from=&to=` — paginated list.
  - Optional: `GET /api/v1/dose-logs/stats` (counts for adherence) — **stretch**.
- **Exit criteria:** Pending rows become missed after grace; history returns correct past days.

---

### Backend Phase 6 — Hardening & handoff

- **Goal:** Demo-ready for Nikhil and Snehal.
- **Deliverables:**
  - Consistent error JSON: `{ "detail": "..." }` or field errors.
  - CORS origins for Flutter dev / production.
  - README section: base URL, how to get token, example curl.
  - Optional: pytest for auth + one medicine + one dose flow.
  - Version prefix `/api/v1` everywhere.
- **Exit criteria:** Snehal can deploy; Nikhil can integrate without guessing.

---

## Phase dependency diagram

```
Phase 1 (Foundation)
    ↓
Phase 2 (Auth)
    ↓
Phase 3 (Medicines)
    ↓
Phase 4 (Dose logs + sync + take)
    ↓
Phase 5 (Missed + history)
    ↓
Phase 6 (Hardening)
```

---

## API prefix convention

Use **`/api/v1`** for all routes (update `architecture.md` if it only says `/v1`).

Example:

- `POST /api/v1/auth/register`
- `GET /api/v1/medicines`
- `POST /api/v1/dose-logs/sync`

---

## Quick reference — backend owner checklist

- [ ] Phase 1: FastAPI + DB + health  
- [ ] Phase 2: register, login, JWT, `/users/me`  
- [ ] Phase 3: medicines CRUD  
- [ ] Phase 4: dose_logs + sync + today + take  
- [ ] Phase 5: missed + history  
- [ ] Phase 6: CORS, docs, README, smoke tests  

---

*End of backend plan — implement in order; adjust dates with team, not scope of MVP.*
