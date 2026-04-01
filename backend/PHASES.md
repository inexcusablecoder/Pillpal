# Backend phases — FastAPI + Firestore

## Phase 1 — Foundation (DONE)

- FastAPI app, CORS, `/` and `/v1/health`
- Firebase Admin init via `GOOGLE_APPLICATION_CREDENTIALS`
- Verify Firebase ID token → `uid` dependency
- `GET /v1/me` reads `users/{uid}`

**Deliverable:** API starts, Swagger works, authenticated calls work with a real ID token.

---

## Phase 2 — Medicines CRUD (DONE)

- `GET/POST/PATCH/DELETE /v1/medicines`
- Firestore fields match Flutter: `userId`, `name`, `dosage`, `scheduledTime`, `frequency`, `daysOfWeek`, `pillCount`, `refillAt`, `memberName`, `active`, `createdAt`

**Deliverable:** Create/edit/delete medicines through API only (optional: keep Flutter on direct Firestore until Phase 6).

---

## Phase 3 — Logs + business logic (DONE)

- `GET /v1/logs/today`, `GET /v1/logs/history`
- `POST /v1/logs/startup` — same as Flutter `runStartupChecks`: generate today’s logs + auto-mark missed
- `POST /v1/logs/mark-taken` — same as Flutter `markAsTaken` (batch update log + decrement pills)
- `POST /v1/logs/recalculate-adherence` — recompute `adherenceScore` + `streakCount` on `users/{uid}`

**Deliverable:** All pill logic runnable from the server; same behavior as `pillpal_logic.py` / Dart `BackendService`.

---

## Phase 4 — Deploy API (your turn)

- Host FastAPI (Render, Railway, Fly.io, Google Cloud Run, etc.)
- Set env vars: `GOOGLE_APPLICATION_CREDENTIALS` or embed service account as secret JSON
- HTTPS URL for Flutter `baseUrl`

---

## Phase 5 — Firestore indexes (when queries fail)

If Firestore returns “index required”, open the error link in Firebase Console and create the composite index, **or** simplify queries (already using `FieldFilter` on `userId` + `date` / `status`).

---

## Phase 6 — Flutter integration (your turn)

- Add `http` / `dio` client with `Authorization: Bearer ${idToken}`
- On app open: `POST /v1/logs/startup`
- On “Mark taken”: `POST /v1/logs/mark-taken`
- Optionally: stop direct Firestore writes for medicines/logs; use API only + keep Firestore **reads** for real-time UI, or switch to polling/API-only reads.

---

## Security note

Service account JSON is **full admin access** to your Firebase project. Never commit it. Rotate if leaked.
