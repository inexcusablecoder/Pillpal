# PillPal — Team Work Distribution

## Team Structure Overview

| Member     | Role                            | Primary Tech                                 |
|------------|---------------------------------|----------------------------------------------|
| Member 1   | Flutter Mobile Developer        | Flutter, Dart, Firebase Flutter SDKs         |
| Member 2   | Firebase Backend Developer      | Node.js, Cloud Functions, Firestore, FCM     |
| Member 3   | UI/UX + Flutter Integration     | Flutter, Dart, Figma, Firebase Auth, FCM     |
| Member 4   | QA + Features + Deployment      | Flutter, Dart, jsPDF (pdf package), Firebase |

---

## Nikhil — Flutter Mobile Developer

### Role Summary
Build the core Flutter Android application, implement all screens, connect Firestore real-time listeners, and ensure data flows correctly between the app and Firebase.

### Tech Stack to Use
- **Flutter** (Dart) — primary framework
- **cloud_firestore** — database reads/writes and real-time streams
- **firebase_auth** — get current user UID, listen to auth state
- **cloud_functions** — call `markAsTaken` callable function
- **Provider** or **Riverpod** — state management

### Screens to Build
| Screen              | File Path                                    | Details                                                                       |
|---------------------|----------------------------------------------|-------------------------------------------------------------------------------|
| Dashboard           | `lib/screens/dashboard/dashboard_screen.dart`| Today's medicine cards, taken/pending/missed counts, real-time updates        |
| Medicine Card       | `lib/screens/dashboard/medicine_card.dart`   | Individual card with medicine name, dosage, time, status badge, "Mark Taken" |
| Add Medicine        | `lib/screens/medicines/add_medicine_screen.dart` | Form with name, dosage, time picker, frequency, pill count              |
| Medicine List       | `lib/screens/medicines/medicine_list_screen.dart`| All added medicines, toggle active/inactive, delete                     |

### Data Models to Build
```dart
// lib/models/medicine.dart
class Medicine {
  final String id;
  final String userId;
  final String name;
  final String dosage;
  final String scheduledTime;
  final String frequency;
  final int pillCount;
  final int refillAt;
  final bool active;
}

// lib/models/log.dart
class MedicineLog {
  final String id;
  final String medicineId;
  final String medicineName;
  final String dosage;
  final String scheduledTime;
  final String date;
  final String status; // "pending" | "taken" | "missed"
  final DateTime? takenAt;
}
```

### Services to Implement
```dart
// lib/services/firestore_service.dart
- getTodayLogs(userId)           → Stream<List<MedicineLog>>
- getMedicines(userId)           → Stream<List<Medicine>>
- addMedicine(medicine)          → Future<void>
- deleteMedicine(medicineId)     → Future<void>
- toggleMedicineActive(id, bool) → Future<void>

// lib/services/functions_service.dart
- markAsTaken(logId, medicineId) → Future<void>  ← calls Cloud Function
```

### How to Build Step by Step
```
1. Run: flutter create pillpal
2. Add dependencies to pubspec.yaml:
   - firebase_core, cloud_firestore, firebase_auth, cloud_functions
   - provider (state management)
3. Set up Firebase using FlutterFire CLI: flutterfire configure
4. Build models (Medicine, MedicineLog)
5. Build FirestoreService with stream methods
6. Build Dashboard screen with StreamBuilder listening to today's logs
7. Build Add Medicine screen with form validation
8. Build Medicine List screen
9. Wire up FunctionsService.markAsTaken() to "Mark as Taken" button
10. Test real-time updates — change Firestore directly, watch UI update
```

### Packages to Add in pubspec.yaml
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: latest
  cloud_firestore: latest
  firebase_auth: latest
  cloud_functions: latest
  provider: latest
  intl: latest             # date/time formatting
```

---

## Shreyash — Firebase Backend Developer

### Role Summary
Set up the entire Firebase project, write all Cloud Functions, define Firestore security rules, and ensure the backend logic (daily log generation, auto-miss detection, adherence scoring, FCM dispatch) works correctly.

### Tech Stack to Use
- **Node.js** (JavaScript) — Cloud Functions runtime
- **firebase-admin** — Firestore and FCM access from functions
- **firebase-functions** — function triggers and scheduling
- **Firebase CLI** — deploy functions

### Cloud Functions to Build

#### 1. `generateDailyLogs` — Scheduled, midnight daily
```javascript
// src/generateDailyLogs.js
// Logic:
// - Query all medicines where active == true
// - For each medicine, check if today matches its frequency/daysOfWeek
// - Create a log document: { userId, medicineId, medicineName, dosage,
//   scheduledTime, date: today, status: "pending", takenAt: null }
// - Use batch writes for efficiency
```

#### 2. `autoMarkMissed` — Scheduled, every 30 minutes
```javascript
// src/autoMarkMissed.js
// Logic:
// - Get current time
// - Query logs where status == "pending" AND date == today
// - For each log: parse scheduledTime, add 60 minutes
// - If (scheduledTime + 60min) < now → update status to "missed"
// - Use batch updates
```

#### 3. `markAsTaken` — HTTP Callable (called from Flutter)
```javascript
// src/markAsTaken.js
// Logic:
// - Receive: { logId, medicineId }
// - Verify auth context (request.auth.uid)
// - Update log: { status: "taken", takenAt: admin.firestore.FieldValue.serverTimestamp() }
// - Decrement medicine.pillCount by 1
// - Return success
```

#### 4. `sendReminder` — Scheduled, every minute
```javascript
// src/sendReminder.js
// Logic:
// - Get current time (HH:MM format)
// - Query logs where scheduledTime == currentTime AND status == "pending" AND date == today
// - For each log, get user's FCM token from /users/{userId}.fcmToken
// - Send FCM message: { title: "Time for your medicine!", body: "Take your {medicineName} {dosage}" }
```

#### 5. `calculateAdherence` — Firestore trigger on logs
```javascript
// src/calculateAdherence.js
// Logic:
// - Triggered on any log write
// - Get userId from the log document
// - Query last 30 days of logs for this userId
// - Count total and taken
// - adherenceScore = (taken / total) * 100
// - Update users/{userId}.adherenceScore
// - Calculate streak: consecutive days all meds taken, update streakCount
```

#### 6. `checkRefill` — Firestore trigger on medicines
```javascript
// src/checkRefill.js
// Logic:
// - Triggered when medicine document is updated
// - Check if pillCount changed
// - If new pillCount <= refillAt:
//   → Get user FCM token
//   → Send FCM: "⚠️ {medicineName} running low — only {pillCount} pills left!"
```

### Firestore Security Rules to Write
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }

    match /medicines/{medicineId} {
      allow read, write: if request.auth.uid == resource.data.userId;
      allow create: if request.auth.uid == request.resource.data.userId;
    }

    match /logs/{logId} {
      allow read: if request.auth.uid == resource.data.userId;
      // Logs are written by Cloud Functions (admin SDK) — no client write needed
      allow write: if false;
    }
  }
}
```

### Project Setup Commands
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize project
firebase init functions
# Choose: JavaScript, no ESLint, yes install dependencies

# Project structure
functions/
  ├── index.js
  ├── package.json
  └── src/
      ├── generateDailyLogs.js
      ├── autoMarkMissed.js
      ├── markAsTaken.js
      ├── sendReminder.js
      ├── calculateAdherence.js
      └── checkRefill.js

# Test locally
firebase emulators:start --only functions,firestore

# Deploy
firebase deploy --only functions
```

### How to Build Step by Step
```
1. Create Firebase project at console.firebase.google.com
2. Enable Firestore, Authentication (Email + Google), Cloud Functions, FCM
3. Install Firebase CLI, run firebase init functions in /functions folder
4. Write index.js to export all functions
5. Build generateDailyLogs first — test with emulator
6. Build autoMarkMissed — manually trigger to test
7. Build markAsTaken callable function — test with Postman or Flutter
8. Build sendReminder — test by setting a medicine time 1 min from now
9. Build calculateAdherence trigger — write a log in Firestore, watch score update
10. Build checkRefill trigger — decrement pillCount below threshold, watch FCM
11. Write and deploy security rules
12. Deploy all functions: firebase deploy --only functions
```

---

## Shubhangi — UI/UX + Flutter Integration

### Role Summary
Design the visual language of PillPal, build reusable UI components, implement Firebase Authentication in Flutter, set up FCM for push notifications, and build the History and Profile screens.

### Tech Stack to Use
- **Flutter** (Dart) — building components and screens
- **firebase_auth** — sign in, sign up, sign out, Google auth
- **firebase_messaging** — FCM token retrieval, foreground/background notification handling
- **flutter_local_notifications** — show notification banner when app is foreground
- **google_sign_in** — Google OAuth
- **Figma** (or pen + paper) — initial wireframes/mockup

### Design System to Define
```dart
// lib/theme/app_theme.dart
// Define:
// - Primary color: Medical blue (#2196F3) or soft green (#4CAF50)
// - Background: Off-white (#F5F5F5)
// - Card color: White with soft shadow
// - Status colors:
//     pending  → Amber (#FFC107)
//     taken    → Green (#4CAF50)
//     missed   → Red (#F44336)
// - Font: Poppins or Inter (add to pubspec.yaml)
// - Border radius: 12px on cards
// - Spacing: 8px base unit
```

### Reusable Widgets to Build
```
lib/widgets/
├── status_badge.dart      → colored chip: "Taken" | "Pending" | "Missed"
├── adherence_card.dart    → circular progress showing adherence %
├── streak_counter.dart    → fire icon + streak number
├── medicine_tile.dart     → list tile for history view
└── empty_state.dart       → illustration + text when list is empty
```

### Screens to Build
| Screen         | File Path                             | Details                                                                 |
|----------------|---------------------------------------|-------------------------------------------------------------------------|
| Login          | `lib/screens/auth/login_screen.dart`  | Email/password form + Google Sign-In button, link to signup             |
| Signup         | `lib/screens/auth/signup_screen.dart` | Name, email, password, confirm password                                |
| History        | `lib/screens/history/history_screen.dart` | List of logs grouped by date, filter by medicine or status         |
| Profile        | `lib/screens/profile/profile_screen.dart` | Display name, adherenceScore, streakCount, family members, sign out |

### Auth Service to Build
```dart
// lib/services/auth_service.dart
class AuthService {
  Future<void> signUpWithEmail(email, password, name)
  Future<void> signInWithEmail(email, password)
  Future<void> signInWithGoogle()
  Future<void> signOut()
  Stream<User?> get authStateChanges
}
```

### Notification Service to Build
```dart
// lib/services/notification_service.dart
class NotificationService {
  Future<void> initialize()            // request permission, set up handlers
  Future<String?> getToken()          // returns FCM token → save to Firestore
  void saveFcmToken(userId, token)    // update /users/{userId}.fcmToken
  void handleForegroundMessage()      // show local notification banner
  void handleNotificationTap()        // navigate to correct screen on tap
}
```

### How to Build Step by Step
```
1. Sketch wireframes for all 6 screens (even rough sketches are fine)
2. Define app_theme.dart with colors, text styles, card decoration
3. Add google_fonts, firebase_messaging, flutter_local_notifications to pubspec.yaml
4. Build AuthService — test sign up, sign in, Google auth, sign out
5. Build login_screen.dart and signup_screen.dart using AuthService
6. Wrap MaterialApp with a StreamBuilder on authStateChanges
   → If user logged in → Dashboard
   → If not → Login screen
7. Build status_badge, adherence_card, streak_counter widgets
8. Build history_screen.dart with Firestore query (last 30 days of logs)
9. Build profile_screen.dart showing user data and sign out
10. Implement NotificationService:
    → Request permission on first launch
    → Get FCM token and save to /users/{userId}.fcmToken
    → Handle foreground messages with local notification
    → Handle tap on notification → navigate to Dashboard
```

### Packages to Add
```yaml
  firebase_auth: latest
  firebase_messaging: latest
  flutter_local_notifications: latest
  google_sign_in: latest
  google_fonts: latest
```

---

## Snehal — QA + Features + Deployment

### Role Summary
Test every user flow end-to-end, build the bonus features (PDF export, refill tracker UI, family mode UI), and handle Firebase Hosting / APK deployment. Also owns the hackathon demo script and presentation.

### Tech Stack to Use
- **Flutter** (Dart) — building feature screens and testing
- **pdf** + **printing** Flutter packages — PDF generation and share
- **Firebase Hosting** — deploy web version (optional)
- **flutter build apk** — generate Android APK for demo
- Manual testing on Android emulator or physical device

### Features to Build

#### 1. PDF History Export
```dart
// In history_screen.dart — add "Export PDF" button
// Using 'pdf' package:
// - Create a Document()
// - Add a table with columns: Date | Medicine | Dosage | Status | Time Taken
// - Loop through all fetched logs and add rows
// - Add header: "PillPal - Medicine History Report" + user name + date range
// - Use Printing.sharePdf(bytes) to show share dialog (download or share)
```

#### 2. Refill Tracker UI
```dart
// In medicine_list_screen.dart (or a separate refill_screen.dart)
// - Show each medicine with a progress bar: pillCount / original count
// - Color code: green (>50%), amber (20-50%), red (<20% or <= refillAt)
// - "Update Stock" button → dialog to set new pillCount (after buying refill)
```

#### 3. Family Mode UI
```dart
// In add_medicine_screen.dart
// - Add "For" dropdown: "Myself" + any family members added in profile
// - In profile_screen.dart: "Add Family Member" section
//   → Enter name + relation (e.g. "Mom - Parent")
//   → Saved to users/{userId}.familyMembers array
// - Dashboard groups medicines by family member
```

### Testing Checklist
```
AUTH
  [ ] Sign up with email — user appears in Firebase Auth console
  [ ] Sign in with email — goes to dashboard
  [ ] Google Sign-In works
  [ ] Sign out — goes back to login
  [ ] Unauthenticated user cannot access dashboard (router guard)

MEDICINE MANAGEMENT
  [ ] Add medicine — appears in Firestore /medicines collection
  [ ] Medicine shows on dashboard after generateDailyLogs runs
  [ ] Delete medicine — removed from Firestore, no longer on dashboard
  [ ] Toggle active/inactive — inactive medicines not included in daily logs

MARK AS TAKEN
  [ ] "Mark as Taken" updates log status in Firestore
  [ ] Dashboard card updates in real-time (no page refresh)
  [ ] pillCount decrements by 1 in Firestore
  [ ] adherenceScore recalculates

AUTO-MISS DETECTION
  [ ] Add medicine with time 1 minute in past → wait 30 min → status = "missed"
  [ ] Alternatively: call autoMarkMissed HTTP function directly with test data

NOTIFICATIONS
  [ ] App receives FCM notification when medicine time matches
  [ ] Tapping notification opens app and navigates correctly
  [ ] Refill alert fires when pillCount drops to/below refillAt

HISTORY
  [ ] History screen shows all past logs
  [ ] Filter by medicine name works
  [ ] Filter by status works

PDF EXPORT
  [ ] PDF generates with correct data
  [ ] PDF share dialog appears
  [ ] PDF is readable and well-formatted

OFFLINE
  [ ] Turn off WiFi — app still shows cached dashboard
  [ ] Mark as taken while offline — syncs when reconnected
```

### Deployment Steps
```bash
# Build release APK for Android
flutter build apk --release
# APK location: build/app/outputs/flutter-apk/app-release.apk
# Install on test device: flutter install

# Deploy to Firebase Hosting (web — optional)
flutter build web
firebase deploy --only hosting

# Share APK for hackathon judges via Google Drive or direct install
```

### Demo Script (Hackathon Presentation)
```
1. [30 sec] Open app → Sign up with email
2. [30 sec] Add 2 medicines:
     - "Vitamin D" — 1000IU — 8:00 AM — daily — 30 pills
     - "Metformin" — 500mg — 9:00 AM — daily — 10 pills (refillAt: 5)
3. [30 sec] Show Dashboard — both medicines appear as "Pending"
4. [15 sec] Tap "Mark as Taken" on Vitamin D — card turns green instantly
5. [30 sec] Show History screen — log entry appears
6. [30 sec] Show Adherence Score card (80%) and Streak counter
7. [15 sec] Call autoMarkMissed manually via Firebase console or emulator
             — Metformin card turns red "Missed"
8. [30 sec] Tap Export PDF — show generated PDF report
9. [15 sec] Show refill alert (Metformin: 10 pills, refillAt: 5)
             — Trigger by decrementing pillCount to 4 in Firestore console
10. [30 sec] Closing statement: scalable, real-time, works offline
```

---

## How All 4 Members Work Together

### Integration Points (Where Code Meets)

| What                        | Member 1 (Mobile Dev) waits for...         | Member 2 (Backend) provides...              |
|-----------------------------|---------------------------------------------|---------------------------------------------|
| Dashboard logs              | `getTodayLogs()` Firestore stream           | Firestore /logs collection with daily entries|
| Mark as Taken               | `markAsTaken` callable function endpoint    | Deployed Cloud Function `markAsTaken`       |
| Adherence Score on Profile  | `users/{uid}.adherenceScore` in Firestore   | `calculateAdherence` trigger keeping it updated |
| Push notifications          | Member 3 sets up FCM receiver               | `sendReminder` function sends FCM messages  |
| Refill UI                   | Member 4 reads `medicine.pillCount`         | `checkRefill` trigger sends FCM on low stock|

### Shared Firestore Field Contract
Everyone must use the same field names. **Do not rename fields without telling the team.**

```
Log status values: "pending" | "taken" | "missed"  ← exact lowercase strings
Date format:       "YYYY-MM-DD"                     ← e.g. "2026-04-01"
Time format:       "HH:MM"                          ← 24-hour, e.g. "08:00"
```

### Communication Rules
- All Firestore collection/field names are defined in `architecture.md` — treat it as the contract
- If Member 2 adds a new field to a collection, update `architecture.md` and notify the team
- Test with Firebase Emulator locally before deploying functions
- Member 4 runs the full test checklist before the demo — raise issues early

---

## Tools Each Member Needs Installed

| Tool                        | Member 1 | Member 2 | Member 3 | Member 4 |
|-----------------------------|----------|----------|----------|----------|
| Flutter SDK                 | ✅        | ❌        | ✅        | ✅        |
| Android Studio / Emulator   | ✅        | ❌        | ✅        | ✅        |
| VS Code                     | ✅        | ✅        | ✅        | ✅        |
| Node.js (v18+)              | ❌        | ✅        | ❌        | ❌        |
| Firebase CLI                | ❌        | ✅        | ❌        | ✅        |
| FlutterFire CLI             | ✅        | ❌        | ✅        | ❌        |
| Git                         | ✅        | ✅        | ✅        | ✅        |

---

## Git Branch Strategy

```
main            → stable, demo-ready code only
│
├── feat/dashboard          → Member 1
├── feat/add-medicine       → Member 1
├── feat/backend-functions  → Member 2
├── feat/auth-ui            → Member 3
├── feat/history-profile    → Member 3
└── feat/pdf-refill         → Member 4
```

- Each member works on their branch
- Merge to `main` only when the feature is complete and tested
- Member 4 reviews and merges all PRs before the demo build

---

## Integration Guide — How All 4 Members Connect Their Work

This section explains exactly how each piece of work connects to the others, in what order, and what the actual code handoff looks like.

---

### Why UI/UX is a Separate Role from the Flutter Mobile Developer

Member 1 (Flutter Mobile Dev) focuses entirely on:
- Making data flow from Firestore to the screen correctly
- State management — what happens when data changes
- Real-time listeners, service classes, models, routing

Member 3 (UI/UX + Integration) focuses entirely on:
- Visual design — colors, fonts, spacing, card shapes (app_theme.dart)
- Firebase Auth flow — sign up, sign in, Google auth, session state, auth guards
- FCM Push Notifications — permission dialogs, token retrieval, foreground/background handlers, notification tap navigation

Auth and Notifications alone are a full job. If Member 1 had to do Auth + FCM + Design + Dashboard + Add Medicine simultaneously, everything would be half-done. The split allows both to move fast in parallel and produce complete, quality work.

---

### Phase 0 — Setup (All members, first session together)

Member 2 does this FIRST. Everyone waits for the firebase config file.

```
Member 2:
  1. Go to console.firebase.google.com → Create project "pillpal"
  2. Enable Firestore, Authentication (Email + Google), Cloud Functions, FCM
  3. Go to Project Settings → Add Android app → download google-services.json
  4. Share google-services.json with the entire team (WhatsApp / Drive)
  5. Run: firebase init functions  (in /functions folder)
  6. Takes ~45 minutes total

Member 1 (in parallel after receiving google-services.json):
  1. flutter create pillpal
  2. Place google-services.json in android/app/
  3. Add all packages to pubspec.yaml
  4. Run flutterfire configure

Member 3 (in parallel):
  1. Create lib/theme/app_theme.dart with colors, fonts, card styles
  2. Sketch wireframes for all 6 screens
  3. Add google_fonts, firebase_messaging, flutter_local_notifications to pubspec.yaml

Member 4 (in parallel):
  1. Set up GitHub repo, create all feature branches
  2. Clone repo, set up Android emulator
  3. Add pdf and printing packages to pubspec.yaml
```

---

### Phase 1 — Parallel Independent Build (No dependencies yet)

All 4 members work independently. No one blocks anyone else.

```
Member 2 builds (functions/src/):
  → generateDailyLogs.js      ← creates pending logs at midnight
  → autoMarkMissed.js         ← marks missed logs every 30 min
  → markAsTaken.js            ← callable, updates log + pillCount
  → calculateAdherence.js     ← Firestore trigger, recalculates score
  → sendReminder.js           ← sends FCM at medicine time
  → checkRefill.js            ← sends FCM when stock is low
  Test with: firebase emulators:start --only functions,firestore
  Deploy with: firebase deploy --only functions

Member 1 builds (lib/):
  → models/medicine.dart
  → models/log.dart
  → services/firestore_service.dart    ← all Firestore read/write methods
  → services/functions_service.dart   ← calls markAsTaken Cloud Function
  → screens/medicines/add_medicine_screen.dart
  → screens/dashboard/dashboard_screen.dart  ← use FAKE hardcoded data first

Member 3 builds (lib/):
  → theme/app_theme.dart               ← design system
  → services/auth_service.dart         ← signUp, signIn, Google, signOut
  → services/notification_service.dart ← FCM setup, token save
  → screens/auth/login_screen.dart
  → screens/auth/signup_screen.dart
  → widgets/status_badge.dart
  → widgets/adherence_card.dart
  → widgets/streak_counter.dart

Member 4 builds (lib/):
  → screens/history/history_screen.dart   ← use fake data first
  → PDF export function using pdf package
  → Refill tracker UI (progress bars)
  → Writes full test checklist
```

---

### Phase 2 — First Integration: Auth Connects to Dashboard

**Who:** Member 3 (provides auth) → Member 1 (uses it)

Member 3 tells Member 1: "AuthService is done."
Member 1 updates main.dart:

```dart
// lib/main.dart
StreamBuilder<User?>(
  stream: AuthService().authStateChanges,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return LoadingScreen();
    }
    if (snapshot.hasData) {
      return DashboardScreen(); // user is logged in
    }
    return LoginScreen();       // user is not logged in
  },
)
```

Member 1 now replaces any hardcoded userId with:
```dart
final uid = FirebaseAuth.instance.currentUser!.uid;
```

The dashboard now shows REAL data for whoever is logged in. This is the biggest integration point.

---

### Phase 3 — Second Integration: Dashboard Connects to Cloud Functions

**Who:** Member 2 (deploys functions) → Member 1 (calls them)

Member 2 deploys `markAsTaken` callable function.
Member 1 calls it from the "Mark as Taken" button in medicine_card.dart:

```dart
// lib/services/functions_service.dart
Future<void> markAsTaken(String logId, String medicineId) async {
  final callable = FirebaseFunctions.instance.httpsCallable('markAsTaken');
  await callable.call({'logId': logId, 'medicineId': medicineId});
}
```

```dart
// lib/screens/dashboard/medicine_card.dart
ElevatedButton(
  onPressed: () async {
    await FunctionsService().markAsTaken(log.id, log.medicineId);
    // No manual refresh needed — Firestore stream updates the UI automatically
  },
  child: Text("Mark as Taken"),
)
```

Member 2's `generateDailyLogs` creates log entries automatically at midnight.
Member 1's dashboard listens to Firestore with a stream — it updates instantly when logs change:

```dart
// lib/services/firestore_service.dart
Stream<List<MedicineLog>> getTodayLogs(String userId) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return FirebaseFirestore.instance
    .collection('logs')
    .where('userId', isEqualTo: userId)
    .where('date', isEqualTo: today)
    .snapshots()
    .map((snap) => snap.docs.map(MedicineLog.fromDoc).toList());
}
```

---

### Phase 4 — Third Integration: Notifications Connect Backend to Flutter

**Who:** Member 2 (sends FCM) ↔ Member 3 (receives FCM)

The only shared contract is the Firestore field `fcmToken` in `/users/{userId}`.

Member 3 saves the token when user logs in:
```dart
// lib/services/notification_service.dart
Future<void> saveFcmToken(String userId) async {
  final token = await FirebaseMessaging.instance.getToken();
  await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({'fcmToken': token});
}
```

Member 2's `sendReminder` reads that exact field and sends FCM:
```javascript
// functions/src/sendReminder.js
const userDoc = await db.collection('users').doc(log.userId).get();
const token = userDoc.data().fcmToken; // ← same field name
await admin.messaging().send({
  token: token,
  notification: {
    title: "Time for your medicine!",
    body: `Take your ${log.medicineName} ${log.dosage}`
  }
});
```

Member 3 handles the received notification in Flutter:
```dart
FirebaseMessaging.onMessage.listen((message) {
  // App is in foreground — show local notification banner
  NotificationService().showLocalNotification(message);
});
FirebaseMessaging.onMessageOpenedApp.listen((message) {
  // User tapped notification — navigate to dashboard
  Navigator.pushNamed(context, '/dashboard');
});
```

---

### Phase 5 — Fourth Integration: History + PDF Connects to Logs

**Who:** Member 4 reads logs already written by Members 1 and 2

No code handoff needed. Member 4 just queries the same `/logs` collection:

```dart
// lib/screens/history/history_screen.dart
Stream<List<MedicineLog>> getAllLogs(String userId) {
  return FirebaseFirestore.instance
    .collection('logs')
    .where('userId', isEqualTo: userId)
    .orderBy('date', descending: true)
    .snapshots()
    .map((snap) => snap.docs.map(MedicineLog.fromDoc).toList());
}
```

Member 2's `autoMarkMissed` already updates log statuses automatically.
Member 4's screen just reads and displays them — nothing extra needed.

PDF export takes the same fetched logs list and generates a document:
```dart
// When "Export PDF" is tapped
final pdf = pw.Document();
pdf.addPage(pw.Page(
  build: (context) => pw.Table.fromTextArray(
    headers: ['Date', 'Medicine', 'Dosage', 'Status'],
    data: logs.map((l) => [l.date, l.medicineName, l.dosage, l.status]).toList(),
  ),
));
await Printing.sharePdf(bytes: await pdf.save(), filename: 'pillpal_report.pdf');
```

---

### Phase 6 — Final Merge, Test, and Demo Build

**Who:** Member 4 owns this phase

```
1. Merge all feature branches into main (resolve any conflicts)
2. Run full test checklist from this document
3. Fix bugs — assign back to original member if needed
4. Build release APK:
     flutter build apk --release
     APK is at: build/app/outputs/flutter-apk/app-release.apk
5. Install on demo phone:
     flutter install
6. Run demo script 3-4 times end to end
7. Deploy Firebase Hosting (optional web version):
     flutter build web && firebase deploy --only hosting
```

---

### The 3 Key Integration Points in One Line Each

| # | Integration | One-Line Summary |
|---|---|---|
| 1 | Auth → Dashboard | Member 3 provides `authStateChanges` stream; Member 1 wraps app in `StreamBuilder` on it |
| 2 | Dashboard → Functions | Member 1 calls `markAsTaken` callable; Member 2 deployed it |
| 3 | Notifications | Member 3 saves `fcmToken` to Firestore; Member 2 reads it and sends FCM |

---

### One Rule Above All

> The `/logs`, `/medicines`, and `/users` Firestore field names in `architecture.md` are the team contract.
> No one renames a field without telling everyone. If you change a field name in your function or Flutter code without updating the contract, everyone else's code silently breaks.
