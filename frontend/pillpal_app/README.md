# pillpal_app

PillPal Medicine Reminder App (Flutter). Lives in the repo at **`frontend/pillpal_app/`** (sibling to `backend/`). Talks to the FastAPI backend under `/api/v1`.

## Backend connection

Set the API base URL in `lib/config/constants.dart` (`AppConstants.apiBaseUrl`).

| Where you run the app | Typical `apiBaseUrl` |
|----------------------|----------------------|
| Android emulator | `http://10.0.2.2:8000` (default) |
| Chrome / web | `http://localhost:8000` |
| Physical phone | `http://<your-PC-LAN-IP>:8000` |

Run the API from the repository root (parent of `frontend/`):

```bash
cd backend
py -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
