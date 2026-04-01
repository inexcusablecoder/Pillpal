"""
Server-side business logic — mirrors pillpal_app/lib/services/backend_service.dart
Uses Firestore Admin SDK (bypasses security rules).
"""

from datetime import datetime, timedelta
from typing import Any

from google.cloud import firestore
from google.cloud.firestore_v1 import FieldFilter


def today_str() -> str:
    # Match Flutter DateFormat('yyyy-MM-dd') on device local calendar
    return datetime.now().astimezone().date().isoformat()


def _dart_day_of_week() -> int:
    """Match Flutter: DateTime.weekday % 7 where Dart 1=Mon..7=Sun → (py_weekday+1)%7."""
    d = datetime.now().astimezone()
    return (d.weekday() + 1) % 7


def _parse_time_minutes(scheduled_time: str) -> int:
    parts = scheduled_time.split(":")
    return int(parts[0]) * 60 + int(parts[1])


def generate_today_logs(db: firestore.Client, user_id: str) -> int:
    """Create pending log rows for active medicines for today. Returns count created."""
    today = today_str()
    meds = (
        db.collection("medicines")
        .where(filter=FieldFilter("userId", "==", user_id))
        .where(filter=FieldFilter("active", "==", True))
        .stream()
    )

    created = 0
    dow = _dart_day_of_week()

    for doc in meds:
        data = doc.to_dict() or {}
        freq = data.get("frequency", "daily")
        days = list(data.get("daysOfWeek", []) or [])

        should_log = False
        if freq == "daily":
            should_log = True
        elif freq in ("weekly", "custom"):
            should_log = dow in days

        if not should_log:
            continue

        if log_exists_today(db, user_id, doc.id, today):
            continue

        log_data: dict[str, Any] = {
            "userId": user_id,
            "medicineId": doc.id,
            "medicineName": data.get("name", ""),
            "dosage": data.get("dosage", ""),
            "scheduledTime": data.get("scheduledTime", "08:00"),
            "date": today,
            "status": "pending",
            "takenAt": None,
            "createdAt": firestore.SERVER_TIMESTAMP,
        }
        db.collection("logs").add(log_data)
        created += 1

    return created


def log_exists_today(db: firestore.Client, user_id: str, medicine_id: str, today: str) -> bool:
    q = (
        db.collection("logs")
        .where(filter=FieldFilter("userId", "==", user_id))
        .where(filter=FieldFilter("medicineId", "==", medicine_id))
        .where(filter=FieldFilter("date", "==", today))
        .limit(1)
    )
    return len(list(q.stream())) > 0


def auto_mark_missed(db: firestore.Client, user_id: str) -> int:
    """Mark pending logs as missed if scheduled time + 60 min passed. Returns count updated."""
    today = today_str()
    now_local = datetime.now().astimezone()
    current_minutes = now_local.hour * 60 + now_local.minute

    q = (
        db.collection("logs")
        .where(filter=FieldFilter("userId", "==", user_id))
        .where(filter=FieldFilter("status", "==", "pending"))
        .where(filter=FieldFilter("date", "==", today))
    )

    batch = db.batch()
    count = 0
    for doc in q.stream():
        data = doc.to_dict() or {}
        st = data.get("scheduledTime", "00:00")
        try:
            scheduled_minutes = _parse_time_minutes(st)
        except (ValueError, IndexError):
            continue
        deadline_minutes = scheduled_minutes + 60
        if current_minutes > deadline_minutes:
            batch.update(doc.reference, {"status": "missed"})
            count += 1

    if count > 0:
        batch.commit()
        recalculate_adherence(db, user_id)
    return count


def mark_as_taken(db: firestore.Client, user_id: str, log_id: str, medicine_id: str) -> None:
    log_ref = db.collection("logs").document(log_id)
    med_ref = db.collection("medicines").document(medicine_id)

    log_snap = log_ref.get()
    if not log_snap.exists:
        raise ValueError("Log not found")
    log_data = log_snap.to_dict() or {}
    if log_data.get("userId") != user_id:
        raise PermissionError("Not your log")
    if log_data.get("status") == "taken":
        return

    med_snap = med_ref.get()
    if not med_snap.exists:
        raise ValueError("Medicine not found")
    m = med_snap.to_dict() or {}
    if m.get("userId") != user_id:
        raise PermissionError("Not your medicine")

    batch = db.batch()
    batch.update(log_ref, {"status": "taken", "takenAt": firestore.SERVER_TIMESTAMP})
    pc = m.get("pillCount", 0) or 0
    if pc > 0:
        batch.update(med_ref, {"pillCount": pc - 1})

    batch.commit()
    recalculate_adherence(db, user_id)


def recalculate_adherence(db: firestore.Client, user_id: str) -> None:
    base = datetime.now().astimezone().date()
    thirty_days_ago = (base - timedelta(days=30)).isoformat()

    q = (
        db.collection("logs")
        .where(filter=FieldFilter("userId", "==", user_id))
        .where(filter=FieldFilter("date", ">=", thirty_days_ago))
    )

    total = 0
    taken = 0
    day_map: dict[str, dict[str, int]] = {}

    for doc in q.stream():
        data = doc.to_dict() or {}
        total += 1
        status = data.get("status", "")
        if status == "taken":
            taken += 1

        d = data.get("date", "")
        if d not in day_map:
            day_map[d] = {"total": 0, "taken": 0}
        day_map[d]["total"] += 1
        if status == "taken":
            day_map[d]["taken"] += 1

    if total == 0:
        return

    adherence_score = round((taken / total) * 100)

    streak = 0
    for i in range(30):
        d = (base - timedelta(days=i)).isoformat()
        day = day_map.get(d)
        if day and day["total"] > 0 and day["taken"] == day["total"]:
            streak += 1
        else:
            break

    db.collection("users").document(user_id).update(
        {"adherenceScore": adherence_score, "streakCount": streak}
    )


def run_startup(db: firestore.Client, user_id: str) -> tuple[int, int]:
    """Generate today's logs, then auto-mark missed. Returns (generated, missed_count)."""
    n1 = generate_today_logs(db, user_id)
    n2 = auto_mark_missed(db, user_id)
    return n1, n2
