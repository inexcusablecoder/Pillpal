# pillpal_app

PillPal (Flutter) — **`frontend/pillpal_app/`** next to **`backend/`**. API prefix: `/api/v1`.

## Run the API

```bash
cd backend
py -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Run the app

```bash
cd frontend/pillpal_app
flutter pub get
flutter run
```

## API base URL

Defaults in `lib/config/constants.dart` (`AppConstants.apiBaseUrl`): web → `http://localhost:8000`, Android emulator → `http://10.0.2.2:8000`. Override: `--dart-define=API_BASE_URL=http://<host>:<port>`. On a phone, use your PC’s LAN IP and the uvicorn port.
