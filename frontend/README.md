# PillPal App (Flutter)

Mobile app for PillPal (medicine reminders, dose history). Same top-level layout as the API: **`backend/`** = FastAPI, **`frontend/pillpal_app/`** = Flutter project root.

| Path | Role |
|------|------|
| `pillpal_app/` | Open this folder in your IDE — `pubspec.yaml`, `lib/`, `android/`, `test/`. |

## Requirements

- Flutter SDK (Dart 3.11+ per `pillpal_app/pubspec.yaml`)
- Android Studio / VS Code + Flutter extension (for emulator or device)

## Setup

From the repository root:

```bash
cd frontend/pillpal_app
flutter pub get
```

## Run

```bash
flutter run
```

Use **`frontend/pillpal_app/`** as the working directory — not a `pillpal_app` folder at the repo root.

Details (API base URL, emulator networking): see [pillpal_app/README.md](pillpal_app/README.md).
