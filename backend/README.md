# PillPal — FastAPI backend

Firebase **Firestore** is the database. Firebase **Authentication** issues ID tokens; this API verifies them and uses the **Admin SDK** to read/write Firestore (bypasses client security rules).

## Security

- **Never** commit `serviceAccountKey.json` or paste it in chat. If a key is exposed, **delete that key** in Firebase Console → Service accounts → Manage keys → Delete, then create a new key.

## What you must provide (manual setup)

1. **Service account JSON**  
   Firebase Console → Project settings → Service accounts → Generate new private key.  
   Save as `backend/serviceAccountKey.json` (this path is gitignored).

2. **Environment**  
   Copy `.env.example` to `.env` and set:
   ```env
   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json
   FIREBASE_PROJECT_ID=pillpal-ed37e
   ```

3. **Python 3.10+**  
   Install Python, then:
   ```bash
   cd backend
   py -3 -m venv .venv
   .\.venv\Scripts\activate
   pip install -r requirements.txt
   ```

## Run locally

```bash
cd backend
set PYTHONPATH=%CD%
set GOOGLE_APPLICATION_CREDENTIALS=serviceAccountKey.json
.\.venv\Scripts\uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open **http://127.0.0.1:8000/docs** (Swagger UI).

## Auth header (for Flutter / Postman)

Every protected route expects:

```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```

Get the token in Flutter: `await FirebaseAuth.instance.currentUser?.getIdToken()`.

## API overview (`/v1`)

| Method | Path | Auth |
|--------|------|------|
| GET | `/` | No |
| GET | `/v1/health` | No |
| GET | `/v1/me` | Yes |
| GET | `/v1/medicines` | Yes |
| POST | `/v1/medicines` | Yes |
| PATCH | `/v1/medicines/{id}` | Yes |
| DELETE | `/v1/medicines/{id}` | Yes |
| GET | `/v1/logs/today` | Yes |
| GET | `/v1/logs/history` | Yes |
| POST | `/v1/logs/startup` | Yes — generate today’s logs + mark missed |
| POST | `/v1/logs/mark-taken` | Yes — body: `log_id`, `medicine_id` |
| POST | `/v1/logs/recalculate-adherence` | Yes |

See `PHASES.md` for the phased rollout plan.

## Flutter app (Android)

The Flutter client calls this API with `Authorization: Bearer <Firebase ID token>`.  
Configure base URL in `pillpal_app/lib/config/api_config.dart` (default `http://10.0.2.2:8000` for the Android emulator). Start uvicorn on your PC before running the app.
