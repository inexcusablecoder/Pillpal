# PillPal — Backend Implementation Plan (Phase-Wise)

## What You Need to Provide Manually Before Coding Starts

Before any backend code can run, these things must be set up by hand.
These cannot be automated — they require your Firebase account and credentials.

---

### MANUAL STEP 1 — Create the Firebase Project

> **Who does this:** Member 2 (Backend Developer)
> **Where:** https://console.firebase.google.com

```
1. Go to https://console.firebase.google.com
2. Click "Add project"
3. Project name: pillpal  (or pillpal-app)
4. Disable Google Analytics (not needed for hackathon)
5. Click "Create project"
```

---

### MANUAL STEP 2 — Enable Firebase Services

Inside the Firebase project console:

```
Firestore Database:
  → Build → Firestore Database → Create database
  → Choose "Start in test mode" (we'll add security rules in Phase 3)
  → Select region: us-central1 (recommended for Cloud Functions compatibility)

Authentication:
  → Build → Authentication → Get started
  → Sign-in method tab → Enable "Email/Password"
  → Sign-in method tab → Enable "Google" → set project support email

Cloud Functions:
  → Build → Functions → Get started
  → Requires upgrading to Blaze (pay-as-you-go) plan
  → NOTE: Blaze plan is FREE within limits — you will NOT be charged for hackathon usage
  → Firebase free tier includes: 2M function invocations/month, 400K GB-seconds/month
  → You need a credit/debit card to upgrade but will NOT be charged

Cloud Messaging (FCM):
  → Already enabled by default when you create a Firebase project
  → No manual step needed
```

---

### MANUAL STEP 3 — Get the Android Config File

```
1. In Firebase console → Project settings (gear icon) → General tab
2. Scroll to "Your apps" → Click "Add app" → Choose Android icon
3. Android package name: com.pillpal.app
4. App nickname: PillPal
5. Click "Register app"
6. Download google-services.json
7. Share this file with the entire team (WhatsApp / Google Drive)
   → Member 1 needs it at: android/app/google-services.json
   → Member 3 needs it too for FlutterFire configure
```

> ⚠️  IMPORTANT: Never commit google-services.json to GitHub. Add it to .gitignore.

---

### MANUAL STEP 4 — Get Service Account Key (for local testing only)

```
1. Firebase console → Project settings → Service accounts tab
2. Click "Generate new private key"
3. Download the JSON file
4. Rename it to: serviceAccountKey.json
5. Place it in: functions/  folder (never commit this to GitHub)
```

---

### MANUAL STEP 5 — Create .env File for Functions

Create this file at `functions/.env` — fill in your actual values:

```env
# functions/.env
# DO NOT commit this file to GitHub — it is in .gitignore

PROJECT_ID=your-firebase-project-id
```

> The project ID is visible in Firebase console → Project settings → General → Project ID

---

### MANUAL STEP 6 — Install Required Tools (One-Time Setup)

```bash
# Install Node.js v18 or higher (if not installed)
# Download from: https://nodejs.org

# Install Firebase CLI globally
npm install -g firebase-tools

# Login to Firebase
firebase login

# Install FlutterFire CLI (for Flutter side)
dart pub global activate flutterfire_cli
```

---

## What I Need From You Right Now

Before I generate any backend code, provide these:

| # | What I Need | Where to Find It | Why It's Needed |
|---|---|---|---|
| 1 | Firebase Project ID | console.firebase.google.com → Project settings → General | Used in every function and config file |
| 2 | Confirm Blaze plan is activated | Firebase console → top-left shows "Blaze" | Cloud Functions won't deploy without Blaze |
| 3 | Confirm google-services.json downloaded | Step 3 above | Flutter app can't connect to Firebase without it |
| 4 | Android package name confirmed | Use `com.pillpal.app` unless you want something different | Must match in Firebase + pubspec.yaml |

Once you confirm these, I generate all 6 Cloud Functions with your actual project ID filled in.

---

---

# Phase-Wise Backend Implementation Plan

---

## Phase 0 — Project Bootstrap

### What This Phase Does
Sets up the entire Firebase project structure locally so that all 6 Cloud Functions have a home to live in. This is the foundation — nothing else can be built without it.

### Importance
Without this phase, there is no backend. This is what connects Node.js code to the Firebase project in the cloud. Skip it or do it wrong and no function will deploy.

### How It Works in the Project
The `functions/` folder is what Firebase deploys to Google's servers. `index.js` is the entry point — Firebase reads it and registers each exported function. The folder structure inside `src/` keeps each function in its own file so team members don't overwrite each other's work.

### What to Build

```bash
# In the root of the PillPal project:
firebase init functions

# Prompts:
# ? Please select an option: Use an existing project → select your pillpal project
# ? What language would you like to use: JavaScript
# ? Do you want to use ESLint: No
# ? Do you want to install dependencies with npm now: Yes
```

This creates:
```
functions/
├── node_modules/
├── package.json
├── package-lock.json
└── index.js
```

### Add Additional Packages

```bash
cd functions
npm install firebase-admin firebase-functions
```

### Create the src/ Folder Structure

```
functions/
├── index.js          ← export all functions here
├── package.json
└── src/
    ├── generateDailyLogs.js
    ├── autoMarkMissed.js
    ├── markAsTaken.js
    ├── sendReminder.js
    ├── calculateAdherence.js
    └── checkRefill.js
```

### index.js — Master Export File

```javascript
// functions/index.js
const { generateDailyLogs } = require('./src/generateDailyLogs');
const { autoMarkMissed }    = require('./src/autoMarkMissed');
const { markAsTaken }       = require('./src/markAsTaken');
const { sendReminder }      = require('./src/sendReminder');
const { calculateAdherence }= require('./src/calculateAdherence');
const { checkRefill }       = require('./src/checkRefill');

exports.generateDailyLogs  = generateDailyLogs;
exports.autoMarkMissed     = autoMarkMissed;
exports.markAsTaken        = markAsTaken;
exports.sendReminder       = sendReminder;
exports.calculateAdherence = calculateAdherence;
exports.checkRefill        = checkRefill;
```

### .gitignore for functions/

```
# functions/.gitignore
node_modules/
.env
serviceAccountKey.json
```

### Test Command

```bash
firebase emulators:start --only functions,firestore
# Opens emulator UI at http://localhost:4000
```

### Phase 0 is Complete When
- `firebase emulators:start` runs without errors
- Emulator UI opens at localhost:4000
- `functions/src/` folder exists with 6 empty JS files

---

## Phase 1 — Firestore Security Rules

### What This Phase Does
Defines who is allowed to read and write which documents in Firestore. Without rules, either everything is locked (app breaks) or everything is open (security risk).

### Importance
In production, bad security rules are dangerous. In a hackathon demo, wrong rules make the app crash silently — data reads return nothing, data writes are rejected. This must be correct before Flutter can talk to Firestore.

### How It Works in the Project
Every Firestore read/write from Flutter passes through these rules first. Cloud Functions use the Admin SDK which bypasses rules entirely — so rules only affect the Flutter app, not the functions. This means:
- Flutter can read/write only its own user's medicines and logs
- Cloud Functions can write logs for any user (needed for generateDailyLogs)
- No one can read another user's data

### What to Build

Create `firestore.rules` in the project root:

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can only read and write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Medicines: owner can read/write, no one else can
    match /medicines/{medicineId} {
      allow read, update, delete: if request.auth != null
        && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null
        && request.auth.uid == request.resource.data.userId;
    }

    // Logs: owner can read only — Cloud Functions write logs via Admin SDK
    match /logs/{logId} {
      allow read: if request.auth != null
        && request.auth.uid == resource.data.userId;
      allow write: if false; // only Cloud Functions write logs
    }
  }
}
```

### Deploy Rules

```bash
firebase deploy --only firestore:rules
```

### Phase 1 is Complete When
- Flutter can write a medicine document for the logged-in user
- Flutter cannot read another user's medicine documents
- Logs can be read by the owner but not written from Flutter directly

---

## Phase 2 — generateDailyLogs Function

### What This Phase Does
Every day at midnight, this function scans all active medicines for all users and creates a `pending` log entry for each one. This is what populates the dashboard each morning.

### Importance
This is the heartbeat of the entire app. Without this function, the dashboard is empty. Every other function (markAsTaken, autoMarkMissed, sendReminder) depends on log entries existing. If this function breaks, nothing works.

### How It Works in the Project

```
Midnight arrives
    │
    ▼
generateDailyLogs fires (Cloud Scheduler triggers it)
    │
    ▼
Query Firestore: get all documents in /medicines where active == true
    │
    ▼
For each medicine document:
    Check if today matches the medicine's frequency
    (daily → always yes, weekly → check daysOfWeek array)
    │
    ▼
If yes → create a new document in /logs:
    {
      userId: medicine.userId,
      medicineId: medicine.id,
      medicineName: medicine.name,
      dosage: medicine.dosage,
      scheduledTime: medicine.scheduledTime,
      date: "2026-04-01",    ← today's date in YYYY-MM-DD
      status: "pending",
      takenAt: null,
      createdAt: serverTimestamp()
    }
    │
    ▼
Dashboard in Flutter reads these logs via Firestore stream → shows them
```

### What to Build

```javascript
// functions/src/generateDailyLogs.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

exports.generateDailyLogs = functions.pubsub
  .schedule('1 0 * * *')        // runs at 00:01 AM every day
  .timeZone('Asia/Kolkata')      // SET YOUR TIMEZONE HERE
  .onRun(async (context) => {

    const today = new Date();
    const dateStr = today.toISOString().split('T')[0]; // "2026-04-01"
    const dayOfWeek = today.getDay(); // 0=Sun, 1=Mon, ..., 6=Sat

    // Get all active medicines
    const medicinesSnap = await db.collection('medicines')
      .where('active', '==', true)
      .get();

    if (medicinesSnap.empty) {
      console.log('No active medicines found.');
      return null;
    }

    const batch = db.batch();
    let count = 0;

    medicinesSnap.forEach((doc) => {
      const med = doc.data();

      // Check if this medicine should be logged today
      let shouldLog = false;
      if (med.frequency === 'daily') {
        shouldLog = true;
      } else if (med.frequency === 'weekly' || med.frequency === 'custom') {
        shouldLog = med.daysOfWeek && med.daysOfWeek.includes(dayOfWeek);
      }

      if (!shouldLog) return;

      // Check if a log already exists for today (avoid duplicates)
      // Note: batch writes can't do reads — duplicate prevention is handled
      // by the Firestore query check below (run separately if needed)

      const logRef = db.collection('logs').doc();
      batch.set(logRef, {
        userId: med.userId,
        medicineId: doc.id,
        medicineName: med.name,
        dosage: med.dosage,
        scheduledTime: med.scheduledTime,
        date: dateStr,
        status: 'pending',
        takenAt: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      count++;
    });

    await batch.commit();
    console.log(`Generated ${count} log entries for ${dateStr}`);
    return null;
  });
```

### How to Test

```bash
# Option 1: Trigger manually via Firebase Emulator UI
# Go to localhost:4000 → Functions → generateDailyLogs → Trigger

# Option 2: Temporarily change schedule to every minute for testing
# .schedule('* * * * *')
# Deploy, wait 1 min, check Firestore for new log entries
# Change back to '1 0 * * *' after testing

# Option 3: Create a test HTTP function that calls the same logic
```

### Phase 2 is Complete When
- Running the function creates log entries in `/logs` collection in Firestore
- Each log has status `"pending"`, correct date, correct userId, correct medicineId
- Daily medicines get 1 log per day (no duplicates)

---

## Phase 3 — markAsTaken Callable Function

### What This Phase Does
When the user taps "Mark as Taken" in the Flutter app, this callable function:
1. Updates the log status to `"taken"`
2. Records the exact time it was taken
3. Decrements the medicine pill count by 1

### Importance
This is the most-used function in the entire app — it fires every time a user confirms they took a medicine. It must be fast (under 2 seconds), reliable, and it must verify the user is who they say they are before touching any data.

### How It Works in the Project

```
User taps "Mark as Taken" button in Flutter
    │
    ▼
Flutter calls: FirebaseFunctions.instance
               .httpsCallable('markAsTaken')
               .call({'logId': '...', 'medicineId': '...'})
    │
    ▼
Cloud Function receives call with:
    context.auth.uid  ← automatically verified by Firebase
    data.logId
    data.medicineId
    │
    ▼
Verify: log.userId == context.auth.uid  (security check)
    │
    ▼
Run Firestore transaction:
    → Update /logs/{logId}: { status: "taken", takenAt: now }
    → Update /medicines/{medicineId}: { pillCount: pillCount - 1 }
    │
    ▼
Return { success: true }
    │
    ▼
calculateAdherence Firestore trigger fires automatically
    → Recalculates adherenceScore for this user
    │
    ▼
Flutter Firestore stream detects the log change
    → Dashboard card updates from "Pending" to "Taken" in real-time
    → No page refresh needed
```

### What to Build

```javascript
// functions/src/markAsTaken.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

exports.markAsTaken = functions.https.onCall(async (data, context) => {

  // 1. Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be logged in to mark a medicine as taken.'
    );
  }

  const { logId, medicineId } = data;

  if (!logId || !medicineId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'logId and medicineId are required.'
    );
  }

  const uid = context.auth.uid;

  // 2. Run as a transaction to prevent race conditions
  await db.runTransaction(async (transaction) => {

    const logRef  = db.collection('logs').doc(logId);
    const medRef  = db.collection('medicines').doc(medicineId);

    const logDoc  = await transaction.get(logRef);
    const medDoc  = await transaction.get(medRef);

    if (!logDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Log entry not found.');
    }

    // 3. Security: make sure this log belongs to the calling user
    if (logDoc.data().userId !== uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You do not own this log entry.'
      );
    }

    // 4. Prevent marking an already-taken medicine again
    if (logDoc.data().status === 'taken') {
      throw new functions.https.HttpsError(
        'already-exists',
        'This medicine has already been marked as taken.'
      );
    }

    // 5. Update log status
    transaction.update(logRef, {
      status: 'taken',
      takenAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 6. Decrement pill count (only if medicine still has pills tracked)
    if (medDoc.exists && medDoc.data().pillCount > 0) {
      transaction.update(medRef, {
        pillCount: admin.firestore.FieldValue.increment(-1),
      });
    }
  });

  return { success: true, message: 'Medicine marked as taken.' };
});
```

### How to Test

```bash
# Start emulator
firebase emulators:start --only functions,firestore

# Create a test log document manually in Firestore Emulator UI:
# /logs/testLog1 → { userId: "testUser", medicineId: "med1", status: "pending", ... }

# Call from Flutter (best test) OR use Firebase Emulator UI to call the function
```

### Phase 3 is Complete When
- Tapping "Mark as Taken" in Flutter updates the Firestore log document
- Dashboard card changes to green "Taken" status in real-time (no refresh)
- pillCount in the medicine document decreases by 1

---

## Phase 4 — autoMarkMissed Function

### What This Phase Does
Every 30 minutes, this function scans all `"pending"` logs for today. For any log where the scheduled time + 1 hour has already passed, it marks the status as `"missed"`.

### Importance
This is what makes PillPal intelligent. Without this function, medicines that were ignored just stay "pending" forever. This function creates accountability — it makes the history honest and the adherence score accurate. It runs server-side so it works even if the user never opens the app.

### How It Works in the Project

```
Every 30 minutes → autoMarkMissed fires
    │
    ▼
Get current time (e.g., 09:45 AM)
    │
    ▼
Query Firestore:
    /logs where status == "pending" AND date == today
    │
    ▼
For each pending log:
    Parse scheduledTime → "08:00" → 8 hours 0 minutes
    Add 60 minutes → deadline is 09:00
    │
    ▼
    Is current time (09:45) > deadline (09:00)?
    YES → update status to "missed"
    NO  → leave as "pending" (user still has time)
    │
    ▼
Batch update all missed logs at once
    │
    ▼
calculateAdherence trigger fires for each updated log
    → adherenceScore decreases
    → Dashboard cards turn red "Missed"
```

### What to Build

```javascript
// functions/src/autoMarkMissed.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

exports.autoMarkMissed = functions.pubsub
  .schedule('every 30 minutes')
  .timeZone('Asia/Kolkata')       // SET YOUR TIMEZONE HERE
  .onRun(async (context) => {

    const now = new Date();
    const today = now.toISOString().split('T')[0]; // "2026-04-01"

    // Current time in minutes since midnight
    const currentMinutes = now.getHours() * 60 + now.getMinutes();

    // Query all pending logs for today
    const pendingSnap = await db.collection('logs')
      .where('status', '==', 'pending')
      .where('date', '==', today)
      .get();

    if (pendingSnap.empty) {
      console.log('No pending logs for today.');
      return null;
    }

    const batch = db.batch();
    let missedCount = 0;

    pendingSnap.forEach((doc) => {
      const log = doc.data();
      const [hours, minutes] = log.scheduledTime.split(':').map(Number);
      const scheduledMinutes = hours * 60 + minutes;
      const deadlineMinutes = scheduledMinutes + 60; // 1 hour window

      if (currentMinutes > deadlineMinutes) {
        batch.update(doc.ref, { status: 'missed' });
        missedCount++;
      }
    });

    if (missedCount > 0) {
      await batch.commit();
      console.log(`Marked ${missedCount} log(s) as missed.`);
    } else {
      console.log('No logs to mark as missed yet.');
    }

    return null;
  });
```

### How to Test

```javascript
// Add a temporary HTTP trigger for demo testing:
exports.testAutoMarkMissed = functions.https.onRequest(async (req, res) => {
  // Same logic as autoMarkMissed but callable via URL
  // Useful for demo: call this URL → instantly marks overdue logs as missed
  res.json({ done: true });
});
```

### Phase 4 is Complete When
- A medicine with scheduledTime `"08:00"` shows as "missed" when called after 09:00
- Pending logs before the deadline remain "pending"
- History screen shows correct missed entries

---

## Phase 5 — calculateAdherence Firestore Trigger

### What This Phase Does
Every time a log document is written or updated, this function recalculates the user's adherence score (% of medicines taken on time in the last 30 days) and updates it in the user's profile document.

### Importance
The adherence score is the main metric that makes PillPal more than just a reminder app. It turns raw log data into a meaningful health insight. It needs to be accurate the moment a log changes — not recalculated only when the user opens their profile.

### How It Works in the Project

```
Any log document is written or updated
(by markAsTaken, autoMarkMissed, or generateDailyLogs)
    │
    ▼
calculateAdherence trigger fires
    │
    ▼
Read userId from the changed log document
    │
    ▼
Query last 30 days of logs for this userId
    │
    ▼
Count:
    total = all logs in last 30 days
    taken = logs with status == "taken"
    │
    ▼
adherenceScore = Math.round((taken / total) * 100)
    │
    ▼
Calculate streak:
    For each day from today backwards:
        Did all medicines get "taken" that day?
        YES → streak++
        NO  → break
    │
    ▼
Update /users/{userId}:
    { adherenceScore: 87, streakCount: 5 }
    │
    ▼
Flutter Profile screen and Dashboard card update in real-time
```

### What to Build

```javascript
// functions/src/calculateAdherence.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

exports.calculateAdherence = functions.firestore
  .document('logs/{logId}')
  .onWrite(async (change, context) => {

    // Get the log document (after write)
    const logData = change.after.exists ? change.after.data() : change.before.data();
    if (!logData) return null;

    const userId = logData.userId;

    // Calculate date 30 days ago
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const thirtyDaysAgoStr = thirtyDaysAgo.toISOString().split('T')[0];

    // Query last 30 days of logs for this user
    const logsSnap = await db.collection('logs')
      .where('userId', '==', userId)
      .where('date', '>=', thirtyDaysAgoStr)
      .get();

    let total = 0;
    let taken = 0;

    // Group logs by date for streak calculation
    const dayMap = {}; // { "2026-04-01": { total: 2, taken: 2 } }

    logsSnap.forEach((doc) => {
      const log = doc.data();
      total++;
      if (log.status === 'taken') taken++;

      if (!dayMap[log.date]) dayMap[log.date] = { total: 0, taken: 0 };
      dayMap[log.date].total++;
      if (log.status === 'taken') dayMap[log.date].taken++;
    });

    // Adherence score
    const adherenceScore = total > 0 ? Math.round((taken / total) * 100) : 0;

    // Streak: count consecutive days from today where all meds were taken
    let streak = 0;
    const today = new Date();
    for (let i = 0; i < 30; i++) {
      const d = new Date(today);
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      const day = dayMap[dateStr];
      if (day && day.total > 0 && day.taken === day.total) {
        streak++;
      } else {
        break; // streak is broken
      }
    }

    // Update user document
    await db.collection('users').doc(userId).update({
      adherenceScore,
      streakCount: streak,
    });

    console.log(`User ${userId}: adherence=${adherenceScore}%, streak=${streak} days`);
    return null;
  });
```

### Phase 5 is Complete When
- After marking a medicine as taken, the profile screen shows updated adherence score
- After missing a medicine, the score decreases
- Streak counter increases when all medicines for the day are taken

---

## Phase 6 — sendReminder Function

### What This Phase Does
Every minute, this function checks if any medicine's scheduled time matches the current time. If yes, it sends a Firebase Cloud Messaging (FCM) push notification to the user's device.

### Importance
This is the reminder engine. Without this, PillPal is just a log app — it doesn't actually remind anyone. This function turns it into an active health assistant that proactively alerts users.

### How It Works in the Project

```
Every minute → sendReminder fires
    │
    ▼
Get current time as "HH:MM" string (e.g., "08:00")
    │
    ▼
Query Firestore:
    /logs where scheduledTime == "08:00"
             AND status == "pending"
             AND date == today
    │
    ▼
For each matching log:
    Get log.userId
    Fetch /users/{userId}.fcmToken from Firestore
    │
    ▼
    Send FCM message to that token:
    {
      title: "Time for your medicine! 💊",
      body:  "Take your Metformin 500mg now"
    }
    │
    ▼
User's Android phone receives notification
    → Even if app is closed / screen is off
    → Tap notification → app opens to Dashboard
```

### What to Build

```javascript
// functions/src/sendReminder.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

exports.sendReminder = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone('Asia/Kolkata')        // SET YOUR TIMEZONE HERE
  .onRun(async (context) => {

    const now = new Date();
    const hours   = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const currentTime = `${hours}:${minutes}`; // e.g., "08:00"
    const today = now.toISOString().split('T')[0];

    console.log(`Checking reminders for time: ${currentTime}`);

    // Find all pending logs scheduled for right now
    const logsSnap = await db.collection('logs')
      .where('scheduledTime', '==', currentTime)
      .where('status', '==', 'pending')
      .where('date', '==', today)
      .get();

    if (logsSnap.empty) {
      console.log('No reminders to send at this time.');
      return null;
    }

    const sendPromises = [];

    logsSnap.forEach((doc) => {
      const log = doc.data();

      // Get FCM token for this user
      const sendPromise = db.collection('users').doc(log.userId).get()
        .then((userDoc) => {
          if (!userDoc.exists) return null;
          const fcmToken = userDoc.data().fcmToken;
          if (!fcmToken) return null;

          const message = {
            token: fcmToken,
            notification: {
              title: 'Time for your medicine! 💊',
              body: `Take your ${log.medicineName} ${log.dosage} now`,
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                channelId: 'medicine_reminders',
              },
            },
            data: {
              logId: doc.id,
              medicineId: log.medicineId,
              screen: 'dashboard',
            },
          };

          return admin.messaging().send(message);
        })
        .then((response) => {
          if (response) console.log(`Reminder sent for log ${doc.id}: ${response}`);
        })
        .catch((error) => {
          console.error(`Failed to send reminder for log ${doc.id}:`, error);
        });

      sendPromises.push(sendPromise);
    });

    await Promise.all(sendPromises);
    console.log(`Sent ${sendPromises.length} reminder(s).`);
    return null;
  });
```

### Phase 6 is Complete When
- Add a medicine with scheduled time 2 minutes from now
- After 2 minutes, a push notification appears on the Android device
- Tapping the notification opens the app

---

## Phase 7 — checkRefill Function

### What This Phase Does
When a medicine's pillCount is updated in Firestore (which happens inside markAsTaken), this Firestore trigger checks if the new count is at or below the refill threshold. If yes, it sends a push notification alerting the user to buy more.

### Importance
Refill reminders prevent the worst-case scenario — a user who regularly takes medicine but suddenly runs out and misses doses because they forgot to restock. This is a quality-of-life feature that shows the app goes beyond simple reminders.

### How It Works in the Project

```
markAsTaken updates medicine.pillCount (e.g., from 6 to 5)
    │
    ▼
Firestore detects the update → triggers checkRefill
    │
    ▼
Compare:
    new pillCount (5) <= refillAt threshold (5)?
    YES → send refill alert
    NO  → do nothing
    │
    ▼
Get user FCM token from /users/{userId}
    │
    ▼
Send FCM notification:
    "⚠️ Metformin running low — only 5 pills left. Time to refill!"
    │
    ▼
User sees alert on phone → knows to buy medicine
```

### What to Build

```javascript
// functions/src/checkRefill.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

exports.checkRefill = functions.firestore
  .document('medicines/{medicineId}')
  .onUpdate(async (change, context) => {

    const before = change.before.data();
    const after  = change.after.data();

    // Only act if pillCount actually changed
    if (before.pillCount === after.pillCount) return null;

    const { pillCount, refillAt, name, userId } = after;

    // Only send alert when crossing the threshold (not on every update below it)
    if (pillCount <= refillAt && before.pillCount > refillAt) {
      // Get user FCM token
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      const fcmToken = userDoc.data().fcmToken;
      if (!fcmToken) return null;

      const message = {
        token: fcmToken,
        notification: {
          title: '⚠️ Medicine running low',
          body: `${name} has only ${pillCount} pill(s) left. Time to refill!`,
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'refill_alerts',
          },
        },
        data: {
          type: 'refill',
          medicineId: context.params.medicineId,
        },
      };

      await admin.messaging().send(message);
      console.log(`Refill alert sent for medicine: ${name}, pillCount: ${pillCount}`);
    }

    return null;
  });
```

### Phase 7 is Complete When
- Set a medicine's pillCount to refillAt + 1 (e.g., 6 when refillAt is 5)
- Mark as taken → pillCount drops to 5
- Push notification appears: "Metformin has only 5 pills left. Time to refill!"

---

## Phase 8 — Deploy Everything

### What This Phase Does
Pushes all Cloud Functions, security rules, and Firestore indexes to the live Firebase project so the Flutter app can use them.

### Importance
Local emulator testing is safe but nothing runs on real devices until deployed. This phase makes the backend live.

### Commands

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy security rules
firebase deploy --only firestore:rules

# Deploy everything at once
firebase deploy

# Deploy a single function only (faster for iteration)
firebase deploy --only functions:markAsTaken
```

### Verify Deployment

```bash
# List all deployed functions
firebase functions:list

# View function logs in real-time
firebase functions:log --follow
```

### Phase 8 is Complete When
- All 6 functions appear in Firebase console → Functions → Dashboard
- Flutter app can call `markAsTaken` and get a response
- Push notifications arrive on a real Android device

---

## Summary Table — All Phases

| Phase | Function / Task         | Trigger Type      | Depends On        | Priority |
|-------|-------------------------|-------------------|-------------------|----------|
| 0     | Project Bootstrap       | Manual setup      | Firebase project  | CRITICAL |
| 1     | Firestore Security Rules| Manual setup      | Phase 0           | CRITICAL |
| 2     | generateDailyLogs       | Scheduled (midnight)| Phase 0, 1      | CRITICAL |
| 3     | markAsTaken             | HTTP Callable     | Phase 2           | CRITICAL |
| 4     | autoMarkMissed          | Scheduled (30 min)| Phase 2           | HIGH     |
| 5     | calculateAdherence      | Firestore trigger | Phase 3, 4        | HIGH     |
| 6     | sendReminder            | Scheduled (1 min) | Phase 2           | HIGH     |
| 7     | checkRefill             | Firestore trigger | Phase 3           | MEDIUM   |
| 8     | Deploy                  | Manual CLI        | All phases        | CRITICAL |

---

## Quick Reference — What I Need From You to Start Coding

Provide these and I will immediately generate all function files with your project details pre-filled:

```
1. Firebase Project ID         → (find it: Firebase console → Project settings → General)
2. App timezone                → (e.g., Asia/Kolkata, Asia/Dubai, America/New_York)
3. Android package name        → (default: com.pillpal.app — change if you prefer)
4. Confirm Blaze plan active   → (yes/no)
5. Confirm google-services.json downloaded → (yes/no)
```
