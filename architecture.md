# PillPal — System Architecture

## Overview

PillPal is a **Medicine Reminder Android Application** built with Flutter for the mobile frontend and Firebase as the complete backend platform. The system ensures users never miss a dose by automating reminders, detecting missed medicines, tracking adherence, and maintaining a full history log.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     FLUTTER ANDROID APP                          │
│                                                                  │
│  ┌───────────┐  ┌──────────────┐  ┌───────────┐  ┌──────────┐  │
│  │   Auth    │  │  Dashboard   │  │  History  │  │ Profile  │  │
│  │  Screen   │  │   Screen     │  │  Screen   │  │ Screen   │  │
│  └─────┬─────┘  └──────┬───────┘  └─────┬─────┘  └────┬─────┘  │
│        │               │                │              │         │
│        └───────────────┴────────────────┴──────────────┘         │
│                                │                                  │
│                    Firebase Flutter SDK                           │
│           (firebase_core, cloud_firestore, firebase_auth,        │
│            firebase_messaging, cloud_functions)                  │
└────────────────────────────────┬────────────────────────────────┘
                                 │  HTTPS / Firestore SDK
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                        FIREBASE PLATFORM                         │
│                                                                  │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐ │
│  │   Firebase   │   │  Cloud       │   │  Firebase Cloud      │ │
│  │    Auth      │   │  Firestore   │   │  Messaging (FCM)     │ │
│  │              │   │  (Database)  │   │  (Push Notifications)│ │
│  └──────────────┘   └──────┬───────┘   └──────────────────────┘ │
│                             │                                    │
│                    ┌────────▼────────┐                           │
│                    │  Cloud          │                           │
│                    │  Functions      │                           │
│                    │  (Node.js)      │                           │
│                    └─────────────────┘                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Firestore Database Schema

### Collection: `users`
```
/users/{userId}
  ├── displayName       String
  ├── email             String
  ├── fcmToken          String       ← for push notifications
  ├── streakCount       Number       ← consecutive days all meds taken
  ├── adherenceScore    Number       ← percentage (0-100)
  ├── createdAt         Timestamp
  └── familyMembers     Array        ← [{name, relation}]
```

### Collection: `medicines`
```
/medicines/{medicineId}
  ├── userId            String       ← owner
  ├── memberName        String       ← "Self" or family member name
  ├── name              String       ← e.g. "Metformin"
  ├── dosage            String       ← e.g. "500mg"
  ├── scheduledTime     String       ← "08:00" (24hr format)
  ├── frequency         String       ← "daily" | "weekly" | "custom"
  ├── daysOfWeek        Array        ← [1,2,3,4,5] for weekly/custom
  ├── pillCount         Number       ← current stock
  ├── refillAt          Number       ← alert threshold (e.g. 5)
  ├── active            Boolean
  └── createdAt         Timestamp
```

### Collection: `logs`
```
/logs/{logId}
  ├── userId            String
  ├── medicineId        String
  ├── medicineName      String       ← denormalized for fast queries
  ├── dosage            String       ← denormalized
  ├── scheduledTime     String       ← "08:00"
  ├── date              String       ← "2026-04-01"
  ├── status            String       ← "pending" | "taken" | "missed"
  ├── takenAt           Timestamp    ← null if not taken
  └── createdAt         Timestamp
```

---

## Cloud Functions

| Function Name         | Trigger Type               | Schedule / Event             | Purpose                                                              |
|-----------------------|----------------------------|------------------------------|----------------------------------------------------------------------|
| `generateDailyLogs`   | Scheduled                  | Every day at 00:01 AM        | Creates a `pending` log for every active medicine for all users     |
| `autoMarkMissed`      | Scheduled                  | Every 30 minutes             | Marks `pending` logs as `missed` if scheduledTime + 1hr has passed  |
| `markAsTaken`         | HTTP (callable)            | Called from Flutter app      | Sets log status to `taken`, decrements pillCount, updates streak    |
| `sendReminder`        | Scheduled                  | Every minute                 | Sends FCM push notification when a medicine's scheduled time is now |
| `calculateAdherence`  | Firestore trigger on `logs`| On log write/update          | Recalculates adherenceScore for the user                            |
| `checkRefill`         | Firestore trigger          | On `medicines.pillCount` update | Sends FCM alert if pillCount drops to or below refillAt threshold |

---

## Application Data Flow

### Flow 1 — Adding a Medicine
```
User fills form in Flutter
      │
      ▼
Flutter SDK writes to /medicines collection
      │
      ▼
Firestore stores document
      │
      ▼
generateDailyLogs (next midnight run) creates a log entry for this medicine
```

### Flow 2 — Daily Reminder + Mark as Taken
```
generateDailyLogs runs at midnight
  → Creates pending log entries for all medicines today
        │
        ▼
sendReminder checks every minute
  → At 08:00, finds log with scheduledTime = "08:00" and status = "pending"
  → Sends FCM push notification to user's device
        │
        ▼
User sees notification → opens app
  → Taps "Mark as Taken" on Dashboard
  → Flutter calls markAsTaken Cloud Function
        │
        ▼
markAsTaken:
  → Sets log.status = "taken"
  → Sets log.takenAt = now()
  → Decrements medicine.pillCount by 1
  → Calls calculateAdherence
        │
        ▼
calculateAdherence:
  → Counts taken vs total logs for last 30 days
  → Updates user.adherenceScore
  → Checks streak and updates user.streakCount
```

### Flow 3 — Auto-Miss Detection
```
autoMarkMissed runs every 30 minutes
  → Queries all logs where:
      status == "pending"
      AND scheduledTime + 60 minutes < currentTime
      AND date == today
  → Updates each log.status = "missed"
  → Triggers calculateAdherence automatically (Firestore trigger)
```

### Flow 4 — Refill Alert
```
markAsTaken decrements pillCount
      │
      ▼
Firestore triggers checkRefill function
      │
      ▼
If pillCount <= refillAt:
  → Sends FCM notification: "Metformin running low — 5 pills left. Time to refill!"
```

---

## Flutter App Screen Structure

```
lib/
├── main.dart
├── firebase_options.dart
│
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── dashboard/
│   │   ├── dashboard_screen.dart
│   │   └── medicine_card.dart
│   ├── medicines/
│   │   ├── add_medicine_screen.dart
│   │   └── medicine_list_screen.dart
│   ├── history/
│   │   └── history_screen.dart
│   └── profile/
│       └── profile_screen.dart
│
├── models/
│   ├── medicine.dart
│   ├── log.dart
│   └── user_model.dart
│
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── notification_service.dart
│   └── functions_service.dart
│
└── widgets/
    ├── status_badge.dart
    ├── adherence_card.dart
    ├── streak_counter.dart
    └── medicine_tile.dart
```

---

## Firebase Cloud Functions Structure

```
functions/
├── package.json
├── index.js                    ← entry point, exports all functions
│
└── src/
    ├── generateDailyLogs.js
    ├── autoMarkMissed.js
    ├── markAsTaken.js
    ├── sendReminder.js
    ├── calculateAdherence.js
    └── checkRefill.js
```

---

## Security Rules (Firestore)

- Users can only read/write their own documents (`request.auth.uid == resource.data.userId`)
- Log entries are created by Cloud Functions (admin SDK — bypasses rules)
- Medicine documents are only accessible by their owner
- No unauthenticated access to any collection

---

## Key Non-Functional Decisions

| Concern            | Decision                                                             |
|--------------------|----------------------------------------------------------------------|
| Scalability        | Firestore auto-scales. Functions scale per invocation.               |
| Offline Support    | Firestore Flutter SDK has built-in offline persistence enabled       |
| Real-time Updates  | Firestore `snapshots()` stream used in Flutter for live UI updates  |
| Notifications      | FCM handles delivery even when app is in background/killed           |
| Auth               | Firebase Auth handles token refresh, session persistence             |
| PDF Export         | Generated client-side in Flutter using `pdf` and `printing` packages |
