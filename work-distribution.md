# PillPal — Work Distribution & Step-by-Step Plan

**Team:** CodeConquerors  
**Track:** Healthcare — Medicine Reminder and Health Monitoring App  

| Role | Name | Focus |
|------|------|--------|
| **Frontend** | Nikhil | Flutter app — screens, API integration, local notifications |
| **Backend** | Shreyash | FastAPI, PostgreSQL, auth, dose log logic |
| **UI/UX** | CR | Wireframes, design system, UX flows, handoff to Nikhil |
| **DevOps / QA** | Snehal | CI, envs, DB hosting, test checklist, demo script, “Q&A style” app copy |

---

## Shared Rules

1. **Branch:** `main` protected; feature branches `feat/<name>-<short>`.
2. **Contract:** REST JSON; see `architecture.md` for routes and tables.
3. **Daily sync:** 15 min standup — blockers, API URL for Nikhil, design tokens for CR → Nikhil.

---

## Phase 0 — Repo & tools (everyone, Day 0)

| Step | Who | Action |
|------|-----|--------|
| 0.1 | Snehal | Ensure GitHub repo is up to date; add branch protection optional. |
| 0.2 | Shreyash | Create `backend/` skeleton: `requirements.txt`, `app/main.py`, `.env.example`. |
| 0.3 | Nikhil | `flutter create pillpal_app` (or restore when ready); add `http`/`dio`. |
| 0.4 | CR | Figma or paper wireframes: Login, Dashboard, Medicine list, Add/Edit, History. |

**Done when:** Empty API runs (`GET /health`), Flutter runs on emulator.

---

## Phase 1 — Database & auth (Shreyash leads)

| Step | Who | Action |
|------|-----|--------|
| 1.1 | Shreyash | PostgreSQL schema: `users`, `medicines`, `dose_logs`; Alembic migrations. |
| 1.2 | Shreyash | `POST /auth/register`, `POST /auth/login` → JWT; password hashing. |
| 1.3 | Shreyash | `GET /users/me` with Bearer token. |
| 1.4 | Snehal | Provision DB (Neon / Supabase / Docker); put `DATABASE_URL` in secrets; document in README. |
| 1.5 | Nikhil | Login/register screens calling Shreyash’s endpoints; store JWT securely. |
| 1.6 | CR | Review forms — labels, errors, loading states. |

**Done when:** User can register, login, and see profile from app.

---

## Phase 2 — Medicine CRUD (Shreyash + Nikhil)

| Step | Who | Action |
|------|-----|--------|
| 2.1 | Shreyash | `GET/POST/PATCH/DELETE /medicines` scoped by `user_id` from JWT. |
| 2.2 | Nikhil | List medicines, add medicine form (name, time, dosage), edit, delete with confirmation. |
| 2.3 | CR | Card layout, typography, empty states (“No medicines yet”). |
| 2.4 | Snehal | Postman collection or Thunder Client for medicines API; smoke test. |

**Done when:** Full CRUD works end-to-end from phone.

---

## Phase 3 — Dose logs, status, history (Shreyash + Nikhil)

| Step | Who | Action |
|------|-----|--------|
| 3.1 | Shreyash | Generate today’s `dose_logs` rows idempotently; `GET /dose-logs/today`, `GET /dose-logs/history`. |
| 3.2 | Shreyash | `POST .../take` marks `taken`, sets `taken_at`; batch job or endpoint marks `missed` after grace. |
| 3.3 | Nikhil | Dashboard: today’s doses; buttons Taken; reflect pending/taken/missed from API or refresh. |
| 3.4 | Nikhil | History screen — list by date (from API). |
| 3.5 | CR | Status colors (pending / taken / missed), history readability. |

**Done when:** PS core line satisfied: *track schedules + history of intake + status in database*.

---

## Phase 4 — Reminders (Nikhil + CR)

| Step | Who | Action |
|------|-----|--------|
| 4.1 | Nikhil | `flutter_local_notifications`: schedule daily at `scheduled_time` per medicine. |
| 4.2 | Nikhil | Cancel/reschedule on edit/delete medicine. |
| 4.3 | CR | Notification copy, icon, deep link to dashboard if time. |
| 4.4 | Snehal | Test on real device; battery / exact alarm notes for demo. |

**Done when:** Notification fires at set time; aligns with PS (*send notifications*).

---

## Phase 5 — DevOps, QA, demo (Snehal leads)

| Step | Who | Action |
|------|-----|--------|
| 5.1 | Snehal | Deploy API (Render / Railway / Fly.io); HTTPS URL in Flutter config. |
| 5.2 | Snehal | GitHub Actions: lint/test backend on PR optional. |
| 5.3 | Snehal | **Q&A checklist:** auth edge cases, offline message, wrong password, empty list. |
| 5.4 | Snehal | **Demo script** (2–3 min): register → add med → notification → mark taken → history. |
| 5.5 | Everyone | Dry run; fix P0 bugs only. |

---

## Per-Person Cheat Sheet

### Nikhil (Frontend)

- Owns `pillpal_app/`.
- Steps: 0.3 → 1.5 → 2.2 → 3.3–3.4 → 4.1–4.2.
- Uses `API_BASE_URL` from Snehal; never commit secrets.

### Shreyash (Backend)

- Owns `backend/`.
- Steps: 0.2 → 1.1–1.3 → 2.1 → 3.1–3.2.
- Ships OpenAPI; keeps `architecture.md` in sync if routes change.

### CR (UI/UX)

- Steps: 0.4 → 1.6 → 2.3 → 3.5 → 4.3.
- Deliverables: color palette, typography, spacing, key screens in Figma or PDF.

### Snehal (DevOps / QA)

- Steps: 0.1 → 1.4 → 2.4 → 4.4 → all of Phase 5.
- Owns deployment URLs, env docs, test matrix, judge demo flow.

---

## After MVP (stretch)

- Adherence %, streak, export PDF, push notifications (FCM), family profiles.

---

## Files in repo

| File | Purpose |
|------|---------|
| `architecture.md` | Diagrams, schema, API list |
| `decision.md` | Why FastAPI, Postgres, JWT, etc. |
| `work-distribution.md` | This file — who does what, in order |
