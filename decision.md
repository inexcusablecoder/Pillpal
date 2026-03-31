# PillPal — Technology Decisions & Rationale

This document explains every major technology and architectural decision made for PillPal and the reasoning behind each choice.

---

## Decision 1 — Mobile Platform: Flutter (Android)

**Chosen:** Flutter (Dart) targeting Android

**Why Flutter over native Android (Kotlin/Java)?**
- Single codebase that can target Android, iOS, and Web in the future without rewriting
- Dart is easy to learn — team members with web/JS background can adapt quickly
- Flutter has first-class Firebase SDKs (`firebase_core`, `cloud_firestore`, `firebase_auth`, `firebase_messaging`) maintained officially by Google
- Hot reload speeds up development significantly during a hackathon
- Material Design widgets are built-in — no separate UI library needed
- Strong community and documentation for beginners

**Why not React Native?**
- Flutter has better performance (compiled to native ARM code, no JavaScript bridge)
- Flutter's widget system is more consistent across devices
- Firebase + Flutter integration is more seamless and better documented

**Why not a PWA (Progressive Web App)?**
- Android push notifications via browsers are inconsistent and unreliable
- FCM works far more reliably with a native Flutter app
- App feels more polished and professional as an installable APK

---

## Decision 2 — Backend Platform: Firebase

**Chosen:** Firebase (Firestore + Cloud Functions + Auth + FCM)

**Why Firebase over a custom Node.js/Express server?**
- Zero server management — no need to set up, host, or maintain a server
- Firestore provides real-time data sync to Flutter with a single line of code (`snapshots()`)
- Firebase Auth handles user sessions, token refresh, and Google Sign-In out of the box
- Cloud Functions scale automatically — no bottlenecks during peak usage
- Free Spark plan is sufficient for a hackathon demo
- All Firebase services work together under one project — no cross-service auth complexity

**Why not Supabase?**
- Firebase has a more mature Flutter SDK ecosystem
- FCM for push notifications is deeply integrated with Firebase — Supabase requires third-party setup
- Team familiarity and documentation availability favored Firebase

**Why not a REST API with Express + MongoDB?**
- Requires hosting a server (Heroku, Railway, Render) with potential cold start delays
- More code to write (routes, middleware, auth) which is counterproductive for a hackathon
- No built-in real-time updates — would need WebSockets or polling
- Firebase eliminates all of this complexity

---

## Decision 3 — Database: Cloud Firestore (not Realtime Database)

**Chosen:** Cloud Firestore

**Why Firestore over Firebase Realtime Database?**
- Firestore supports complex queries (filter by userId AND date AND status simultaneously)
- Realtime Database is one large JSON tree — querying is limited and inefficient for our log structure
- Firestore scales better for large collections (logs grow daily)
- Firestore has better offline support with more granular conflict resolution
- Firestore's Flutter SDK (`cloud_firestore`) is the officially recommended choice for new projects

---

## Decision 4 — Authentication: Firebase Auth

**Chosen:** Firebase Authentication with Email/Password + Google Sign-In

**Why not custom auth (JWT + bcrypt)?**
- Firebase Auth handles password hashing, token rotation, session management automatically
- Google Sign-In is one-line integration in Flutter with `google_sign_in` package
- Reduces attack surface — no passwords stored in Firestore
- Account recovery, email verification all handled by Firebase

---

## Decision 5 — Push Notifications: Firebase Cloud Messaging (FCM)

**Chosen:** FCM via `firebase_messaging` Flutter package

**Why FCM over local notifications only?**
- Local notifications (`flutter_local_notifications`) only fire if the app is running or scheduled locally — unreliable when phone restarts
- FCM delivers from the server even when the app is killed or the device restarts
- FCM tokens stored in Firestore allow Cloud Functions to target specific users
- Free and unlimited for our scale

**Combined approach used:**
- FCM for server-triggered notifications (sent by `sendReminder` Cloud Function)
- Local notifications as a fallback when app is in foreground

---

## Decision 6 — Cloud Functions Language: JavaScript (Node.js)

**Chosen:** Node.js (JavaScript) for Cloud Functions

**Why not Python or Go?**
- JavaScript is the most common language — all team members have exposure
- Firebase documentation for Cloud Functions is most detailed in JavaScript
- Same language ecosystem as the web ecosystem — easy to find solutions
- `firebase-admin` SDK is most mature in Node.js
- Cold start performance is acceptable for our use case (scheduled functions, callable functions)

---

## Decision 7 — Auto-Miss Detection: Scheduled Cloud Function (not client-side)

**Chosen:** Scheduled Cloud Function running every 30 minutes

**Why not detect missed medicines on the client (Flutter app)?**
- Client-side detection only works when the app is open — useless if user ignores the app
- A server-side function marks medicines as missed regardless of whether the user opened the app
- Single source of truth — no race conditions between multiple devices
- More reliable and auditable — the database is the authority, not the device

**Why every 30 minutes and not every minute?**
- 30 minutes is precise enough (1-hour missed window) while minimizing Cloud Function invocations
- Reduces Firebase billing (though within free tier easily)
- The exact missed timestamp is recorded when the function runs, not when the window expired

---

## Decision 8 — PDF Report: Client-Side in Flutter

**Chosen:** Generate PDF on-device using `pdf` and `printing` Flutter packages

**Why not server-side PDF generation?**
- Avoids a Cloud Function invocation for every export
- Data is already in Flutter's memory (fetched from Firestore) — no round trip needed
- `pdf` package in Flutter is powerful enough for a clean history report
- Works offline as long as the data is cached by Firestore

---

## Decision 9 — Adherence Score: Firestore Trigger Function

**Chosen:** Recalculate adherence on every log write via a Firestore-triggered Cloud Function

**Why not calculate on the client?**
- Centralized calculation ensures consistency — no discrepancy between devices
- The score is stored in Firestore (`users/{userId}.adherenceScore`) so it's readable instantly without recalculating
- Trigger-based approach means it always stays up-to-date automatically

**Formula:**
```
adherenceScore = (takenLogs / totalLogs) * 100
                 over the last 30 days
```

---

## Decision 10 — Offline Support: Firestore Persistence

**Chosen:** Enable Firestore offline persistence in Flutter

**Why?**
- Users may open the app in areas with poor connectivity
- With persistence enabled, Firestore caches the last fetched data locally
- The app still shows today's medicines and history without internet
- Writes (mark as taken) are queued and synced when connection restores
- One-line enablement: `FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true)`

---

## Summary Table

| Decision                | Choice                          | Key Reason                                      |
|-------------------------|---------------------------------|-------------------------------------------------|
| Mobile App              | Flutter (Android)               | Cross-platform, Firebase-native, fast dev       |
| Backend                 | Firebase                        | No server management, real-time sync, free tier |
| Database                | Cloud Firestore                 | Complex queries, real-time streams, scales well |
| Auth                    | Firebase Auth                   | Secure, zero-boilerplate, Google Sign-In        |
| Push Notifications      | FCM + Local Notifications       | Reliable server-push even when app is killed    |
| Functions Language      | Node.js (JavaScript)            | Team familiarity, best Firebase SDK support     |
| Auto-Miss Detection     | Scheduled Cloud Function        | Server-side, reliable, works without app open   |
| PDF Export              | Flutter `pdf` package           | Client-side, no server round-trip needed        |
| Adherence Score         | Firestore Trigger Function      | Centralized, always consistent                  |
| Offline Support         | Firestore Persistence (Flutter) | Works in poor connectivity areas                |
