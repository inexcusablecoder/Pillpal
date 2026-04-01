from fastapi import APIRouter, Depends, HTTPException

from app.core.security import get_current_user_uid
from app.core.firebase import get_db

router = APIRouter(tags=["users"])


@router.get("/me")
def get_me(uid: str = Depends(get_current_user_uid)):
    db = get_db()
    doc = db.collection("users").document(uid).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="User profile not found")
    data = doc.to_dict() or {}
    data["uid"] = doc.id
    return data
