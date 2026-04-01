from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from google.cloud.firestore import FieldFilter

from app.core.security import get_current_user_uid
from app.core.firebase import get_db
from app.schemas.log import LogOut, MarkTakenBody, StartupResult
from app.services import pillpal_logic

router = APIRouter(prefix="/logs", tags=["logs"])


def _log_to_out(doc_id: str, data: dict[str, Any]) -> LogOut:
    t = data.get("takenAt")
    taken_str: str | None = None
    if t is not None:
        taken_str = t.isoformat() if hasattr(t, "isoformat") else str(t)

    return LogOut(
        id=doc_id,
        user_id=data.get("userId", ""),
        medicine_id=data.get("medicineId", ""),
        medicine_name=data.get("medicineName", ""),
        dosage=data.get("dosage", ""),
        scheduled_time=data.get("scheduledTime", ""),
        date=data.get("date", ""),
        status=data.get("status", "pending"),
        taken_at=taken_str,
    )


@router.get("/today", response_model=list[LogOut])
def today_logs(uid: str = Depends(get_current_user_uid)):
    db = get_db()
    today = pillpal_logic.today_str()
    q = (
        db.collection("logs")
        .where(filter=FieldFilter("userId", "==", uid))
        .where(filter=FieldFilter("date", "==", today))
        .stream()
    )
    rows = [_log_to_out(d.id, d.to_dict() or {}) for d in q]
    rows.sort(key=lambda x: x.scheduled_time)
    return rows


@router.get("/history", response_model=list[LogOut])
def history_logs(uid: str = Depends(get_current_user_uid)):
    db = get_db()
    from datetime import datetime, timedelta

    base = datetime.now().astimezone().date()
    from_date = (base - timedelta(days=30)).isoformat()
    q = (
        db.collection("logs")
        .where(filter=FieldFilter("userId", "==", uid))
        .where(filter=FieldFilter("date", ">=", from_date))
        .stream()
    )
    rows = [_log_to_out(d.id, d.to_dict() or {}) for d in q]
    rows.sort(key=lambda x: (x.date, x.scheduled_time), reverse=True)
    return rows


@router.post("/startup", response_model=StartupResult)
def startup(uid: str = Depends(get_current_user_uid)):
    db = get_db()
    n1, n2 = pillpal_logic.run_startup(db, uid)
    return StartupResult(
        logs_generated=n1,
        marked_missed=n2,
        message="Today's logs ensured; overdue pending marked missed.",
    )


@router.post("/generate-today")
def generate_today(uid: str = Depends(get_current_user_uid)):
    db = get_db()
    n = pillpal_logic.generate_today_logs(db, uid)
    return {"logs_created": n}


@router.post("/mark-missed")
def mark_missed(uid: str = Depends(get_current_user_uid)):
    db = get_db()
    n = pillpal_logic.auto_mark_missed(db, uid)
    return {"marked_missed": n}


@router.post("/mark-taken")
def mark_taken(body: MarkTakenBody, uid: str = Depends(get_current_user_uid)):
    db = get_db()
    try:
        pillpal_logic.mark_as_taken(db, uid, body.log_id, body.medicine_id)
    except ValueError as e:
        raise HTTPException(404, str(e)) from e
    except PermissionError as e:
        raise HTTPException(403, str(e)) from e
    return {"ok": True}


@router.post("/recalculate-adherence")
def recalc(uid: str = Depends(get_current_user_uid)):
    db = get_db()
    pillpal_logic.recalculate_adherence(db, uid)
    return {"ok": True}
