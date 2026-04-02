# PillPal — Technology Decisions

**Context:** Hackathon MVP · Healthcare track · Medicine reminder + health monitoring · Team CodeConquerors.

---

## 1. Backend: FastAPI (Python)

**Chosen:** FastAPI  
**Alternatives considered:** Express, Django REST, Firebase Cloud Functions  

**Why FastAPI**

- Fast to build REST + OpenAPI docs (`/docs`) for judges and frontend integration.
- Native `async` fits PostgreSQL drivers (asyncpg / SQLAlchemy 2 async).
- Pydantic validation matches hackathon speed and fewer runtime bugs.
- Shreyash (backend) can own one clear `backend/` tree.

---

## 2. Database: PostgreSQL

**Chosen:** PostgreSQL  

**Why not Firebase / Firestore for this version**

- Relational model maps naturally: users → medicines → dose_logs.
- SQL queries for history, adherence, and date filters are straightforward.
- Free tier on Neon / Supabase / Railway is enough for demo.
- Aligns with “scalable, simple” — one source of truth in Postgres.

---

## 3. Auth: JWT + Email/Password (MVP)

**Chosen:** Register/login returning JWT; Flutter stores token in secure storage.

**Why not “optional login only” for MVP**

- Problem requires **user-specific** medicines and **history** — multi-user demo needs real accounts.
- Local-only mode can be a **stretch goal** (single-device SQLite).

---

## 4. Mobile: Flutter (Android)

**Chosen:** Flutter targeting Android  

**Why**

- Single codebase; Material UI; strong notification plugins.
- Matches problem statement: **mobile application**.
- Nikhil owns `frontend/pillpal_app/`; CR provides design system and flows.

---

## 5. Notifications: Local (Flutter) First

**Chosen:** `flutter_local_notifications` + scheduled alarms for daily repeat.  

**Why not server-push only**

- MVP does not require FCM infrastructure; local alarms fire at wall-clock time.
- Snehal can add FCM or cron later if time permits.

**Backend role:** Still owns **truth** for `pending` / `taken` / `missed` in PostgreSQL.

---

## 6. “Automatically mark missed”

**Chosen:** Logic in FastAPI service + triggered on **app open** (POST sync) and optionally **scheduled HTTP** from DevOps (cron).  

**Why:** No missed state if user never opens app is acceptable for MVP; demo can show missed after grace window.

---

## 7. Keep It Simple (Hackathon Rules)

- One API version prefix: `/api/v1` or `/v1`.
- Alembic for migrations; don’t hand-edit prod DB.
- No microservices, no event bus for MVP.

---

## Summary Table

| Topic | Decision |
|-------|----------|
| API | FastAPI |
| DB | PostgreSQL |
| Auth | JWT + bcrypt |
| Client | Flutter Android |
| Reminders | Local notifications (Flutter) |
| Missed doses | API + optional cron |
