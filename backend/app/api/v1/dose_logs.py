import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.medicine import Medicine
from app.models.user import User
from app.schemas.dose_log import DoseLogOut, SyncResponse
from app.services import dose_log_service

router = APIRouter()


@router.post("/sync", response_model=SyncResponse)
async def sync_dose_logs(
    db: AsyncSession = Depends(get_db),
    current: User = Depends(get_current_user),
) -> SyncResponse:
    today = dose_log_service.today_utc()
    created = await dose_log_service.ensure_today_dose_rows(db, current.id, today)
    missed = await dose_log_service.apply_missed_logic(db, current.id, today)
    return SyncResponse(today=today, dose_logs_created=created, missed_marked=missed)


@router.get("/today", response_model=list[DoseLogOut])
async def today_dose_logs(
    db: AsyncSession = Depends(get_db),
    current: User = Depends(get_current_user),
) -> list[DoseLogOut]:
    today = dose_log_service.today_utc()
    rows = await dose_log_service.list_today_with_medicine_names(db, current.id, today)
    return [DoseLogOut.model_validate(r) for r in rows]


@router.get("/history", response_model=list[DoseLogOut])
async def history_dose_logs(
    db: AsyncSession = Depends(get_db),
    current: User = Depends(get_current_user),
    days: int = Query(30, ge=1, le=366),
    range_from: date | None = Query(None, alias="from"),
    range_to: date | None = Query(None, alias="to"),
) -> list[DoseLogOut]:
    today = dose_log_service.today_utc()
    if (range_from is None) ^ (range_to is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Provide both from and to query params, or neither",
        )
    if range_from is not None and range_to is not None:
        if range_from > range_to:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="from must be <= to",
            )
        from_date, to_date = range_from, range_to
    else:
        to_date = today
        from_date = today - timedelta(days=days - 1)
    rows = await dose_log_service.list_history(db, current.id, from_date, to_date)
    return [DoseLogOut.model_validate(r) for r in rows]


@router.post("/{log_id}/take", response_model=DoseLogOut)
async def take_dose(
    log_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current: User = Depends(get_current_user),
) -> DoseLogOut:
    log, err = await dose_log_service.take_dose(db, current.id, log_id)
    if err == "not_found":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Dose log not found")
    if err == "not_pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Dose is not pending",
        )
    assert log is not None
    result = await db.execute(select(Medicine.name).where(Medicine.id == log.medicine_id))
    med_name = result.scalar_one()
    return DoseLogOut.model_validate(
        {
            "id": log.id,
            "user_id": log.user_id,
            "medicine_id": log.medicine_id,
            "medicine_name": med_name,
            "scheduled_date": log.scheduled_date,
            "scheduled_time": log.scheduled_time,
            "status": log.status.value,
            "taken_at": log.taken_at,
            "created_at": log.created_at,
        }
    )
