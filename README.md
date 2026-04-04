# PillPal — Intelligent Multilingual Medicine Reminder & Health Monitoring

**Team:** CodeConquerors · **Hackathon Track:** Healthcare  
**Branch:** `calling_agent` (DeepSeek & Twilio Integration)

PillPal is a state-of-the-art health companion designed to improve medication adherence through high-tech reminders and a user-friendly, localized experience. It bridges the gap for non-English speakers and elderly users by providing reminders in their native tongues and via direct phone calls.

---

## 🚀 Key Features

### 🌍 1. Full Multilingual Localization (8 Languages)
PillPal is fully localized into **8 major Indian languages**, ensuring inclusivity for users across the country:
- **English** | **Hindi (हिंदी)** | **Bengali (বাংলা)** | **Telugu (తెలుగు)**
- **Marathi (मराठी)** | **Tamil (தமிழ்)** | **Gujarati (ગુજરાતી)** | **Kannada (ಕನ್ನಡ)**

The entire UI—from login to medical history—dynamically updates its text, placeholders, and validation messages based on the user's preference.

### 📞 2. Premium Twilio Calling Agent
For users who need more than just a push notification, PillPal integrates a **Twilio-powered calling agent**:
- **Automated Reminders:** Receives a real phone call at the scheduled dosage time.
- **Localized Voice:** The bot speaks to the user (via Twilio Programmable Voice) providing clear instructions.
- **Background Scheduling:** A robust FastAPI backend with `APScheduler` manages millions of dose events with sub-second precision.

### 📊 3. Health Monitoring & Family Tracking
- **Inventory Management:** Automatically tracks pill counts and notifies users when a refill is needed based on custom thresholds.
- **Vitals Dashboard:** Track blood pressure, heart rate, and historical trends.
- **Family Profiles:** Switch between family members to manage medications for children or elderly parents from a single account.

---

## 🛠️ Technical Architecture

| Layer | Technology | Key Features |
|-------|------------|--------------|
| **Mobile** | **Flutter** | Glassmorphism UI, `Provider` state management, `flutter_animate` |
| **API** | **FastAPI** | Async operations, JWT Auth, Pydantic validation |
| **Worker** | **APScheduler** | Background job execution for Twilio triggers |
| **Calls** | **Twilio API** | Programmable Voice for automated pill reminders |
| **Database** | **PostgreSQL** | Neon Serverless integration with SQLAlchemy Async |

---

## 💻 Local Setup & Deployment

### 1. Backend (FastAPI)
Navigate to `backend/` and configure your `.env` file with `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and `DATABASE_URL`.
```bash
# Start the server
python -m uvicorn app.main:app --reload
```

### 2. Frontend (Flutter)
Navigate to `frontend/pillpal_app/`.
```bash
flutter pub get
flutter run -d chrome  # Or your preferred mobile emulator
```

---

## 📖 Documentation & Planning

| Document | Purpose |
|----------|---------|
| [docs/architecture.md](docs/architecture.md) | System design & PostgreSQL schema |
| [docs/decision.md](docs/decision.md) | Why we chose FastAPI, Twilio, and Flutter |
| [backend/app/services/twilio_calls.py](backend/app/services/twilio_calls.py) | Core logic for the automated calling agent |
| [lib/utils/translations.dart](frontend/pillpal_app/lib/utils/translations.dart) | Centralized dictionary for 8-language support |

---

Developed with ❤️ by **CodeConquerors** (Nikhil, Shreyash, CR, Snehal)
