from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from google.cloud.firestore import FieldFilter, SERVER_TIMESTAMP

from app.core.security import get_current_user_uid
from app.core.firebase import get_db
from app.schemas.medicine import MedicineCreate, MedicineOut, MedicineUpdate

router = APIRouter(prefix="/medicines", tags=["medicines"])


def _doc_to_out(doc_id: str, data: dict[str, Any]) -> MedicineOut:
    return MedicineOut(
        id=doc_id,
        user_id=data.get("userId", ""),
        name=data.get("name", ""),
        dosage=data.get("dosage", ""),
        scheduled_time=data.get("scheduledTime", "08:00"),
        frequency=data.get("frequency", "daily"),
        days_of_week=list(data.get("daysOfWeek", []) or []),
        pill_count=int(data.get("pillCount", 0)),
        refill_at=int(data.get("refillAt", 5)),
        member_name=data.get("memberName", "Self"),
        active=bool(data.get("active", True)),
    )


@router.get("", response_model=list[MedicineOut])
def list_medicines(uid: str = Depends(get_current_user_uid)):
    db = get_db()
    q = db.collection("medicines").where(filter=FieldFilter("userId", "==", uid)).stream()
    return [_doc_to_out(d.id, d.to_dict() or {}) for d in q]


@router.get("/{medicine_id}", response_model=MedicineOut)
def get_medicine(medicine_id: str, uid: str = Depends(get_current_user_uid)):
    db = get_db()
    doc = db.collection("medicines").document(medicine_id).get()
    if not doc.exists:
        raise HTTPException(404, "Medicine not found")
    data = doc.to_dict() or {}
    if data.get("userId") != uid:
        raise HTTPException(403, "Not your medicine")
    return _doc_to_out(doc.id, data)


@router.post("", response_model=dict)
def create_medicine(body: MedicineCreate, uid: str = Depends(get_current_user_uid)):
    db = get_db()
    payload: dict[str, Any] = {
        "userId": uid,
        "memberName": body.member_name,
        "name": body.name,
        "dosage": body.dosage,
        "scheduledTime": body.scheduled_time,
        "frequency": body.frequency,
        "daysOfWeek": body.days_of_week,
        "pillCount": body.pill_count,
        "refillAt": body.refill_at,
        "active": body.active,
    }
    payload["createdAt"] = SERVER_TIMESTAMP
    doc_ref = db.collection("medicines").add(payload)
    return {"id": doc_ref.id}


@router.patch("/{medicine_id}")
def update_medicine(
    medicine_id: str,
    body: MedicineUpdate,
    uid: str = Depends(get_current_user_uid),
):
    db = get_db()
    ref = db.collection("medicines").document(medicine_id)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(404, "Medicine not found")
    if (doc.to_dict() or {}).get("userId") != uid:
        raise HTTPException(403, "Not your medicine")

    updates: dict[str, Any] = {}
    if body.name is not None:
        updates["name"] = body.name
    if body.dosage is not None:
        updates["dosage"] = body.dosage
    if body.scheduled_time is not None:
        updates["scheduledTime"] = body.scheduled_time
    if body.frequency is not None:
        updates["frequency"] = body.frequency
    if body.days_of_week is not None:
        updates["daysOfWeek"] = body.days_of_week
    if body.pill_count is not None:
        updates["pillCount"] = body.pill_count
    if body.refill_at is not None:
        updates["refillAt"] = body.refill_at
    if body.member_name is not None:
        updates["memberName"] = body.member_name
    if body.active is not None:
        updates["active"] = body.active

    if updates:
        ref.update(updates)
    return {"ok": True}


@router.delete("/{medicine_id}")
def delete_medicine(medicine_id: str, uid: str = Depends(get_current_user_uid)):
    db = get_db()
    ref = db.collection("medicines").document(medicine_id)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(404, "Medicine not found")
    if (doc.to_dict() or {}).get("userId") != uid:
        raise HTTPException(403, "Not your medicine")
    ref.delete()
    return {"ok": True}
