from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.dose_log import DoseLog, DoseStatus
from app.models.medicine import Medicine


def today_utc() -> date:
    return datetime.now(timezone.utc).date()


async def ensure_today_dose_rows(db: AsyncSession, user_id: uuid.UUID, today: date) -> int:
    """Idempotent inserts for each active medicine. Returns count of rows inserted."""
    result = await db.execute(
        select(Medicine).where(Medicine.user_id == user_id, Medicine.active.is_(True))
    )
    medicines = list(result.scalars().all())
    created = 0
    for m in medicines:
        stmt = (
            insert(DoseLog)
            .values(
                id=uuid.uuid4(),
                user_id=user_id,
                medicine_id=m.id,
                scheduled_date=today,
                scheduled_time=m.scheduled_time,
                status=DoseStatus.pending,
                created_at=datetime.now(timezone.utc),
            )
            .on_conflict_do_nothing(constraint="uq_dose_medicine_date")
        )
        r = await db.execute(stmt)
        if r.rowcount and r.rowcount > 0:
            created += int(r.rowcount)
    return created


async def apply_missed_logic(
    db: AsyncSession, user_id: uuid.UUID, as_of: date, grace_minutes: int | None = None
) -> int:
    """Mark pending today's (as_of) doses as missed if past scheduled time + grace. Returns updates count."""
    grace = grace_minutes if grace_minutes is not None else settings.dose_grace_minutes
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(DoseLog).where(
            DoseLog.user_id == user_id,
            DoseLog.scheduled_date == as_of,
            DoseLog.status == DoseStatus.pending,
        )
    )
    rows = list(result.scalars().all())
    marked = 0
    delta = timedelta(minutes=grace)
    for row in rows:
        scheduled_dt = datetime.combine(row.scheduled_date, row.scheduled_time, tzinfo=timezone.utc)
        if now > scheduled_dt + delta:
            row.status = DoseStatus.missed
            marked += 1
    return marked


async def list_today_with_medicine_names(
    db: AsyncSession, user_id: uuid.UUID, today: date
) -> list[dict]:
    result = await db.execute(
        select(DoseLog, Medicine.name)
        .join(Medicine, Medicine.id == DoseLog.medicine_id)
        .where(DoseLog.user_id == user_id, DoseLog.scheduled_date == today)
        .order_by(DoseLog.scheduled_time)
    )
    out: list[dict] = []
    for dose, med_name in result.all():
        out.append(
            {
                "id": dose.id,
                "user_id": dose.user_id,
                "medicine_id": dose.medicine_id,
                "medicine_name": med_name,
                "scheduled_date": dose.scheduled_date,
                "scheduled_time": dose.scheduled_time,
                "status": dose.status.value,
                "taken_at": dose.taken_at,
                "created_at": dose.created_at,
            }
        )
    return out


async def list_history(
    db: AsyncSession,
    user_id: uuid.UUID,
    from_date: date,
    to_date: date,
) -> list[dict]:
    result = await db.execute(
        select(DoseLog, Medicine.name)
        .join(Medicine, Medicine.id == DoseLog.medicine_id)
        .where(
            DoseLog.user_id == user_id,
            DoseLog.scheduled_date >= from_date,
            DoseLog.scheduled_date <= to_date,
        )
        .order_by(DoseLog.scheduled_date.desc(), DoseLog.scheduled_time)
    )
    out: list[dict] = []
    for dose, med_name in result.all():
        out.append(
            {
                "id": dose.id,
                "user_id": dose.user_id,
                "medicine_id": dose.medicine_id,
                "medicine_name": med_name,
                "scheduled_date": dose.scheduled_date,
                "scheduled_time": dose.scheduled_time,
                "status": dose.status.value,
                "taken_at": dose.taken_at,
                "created_at": dose.created_at,
            }
        )
    return out


async def take_dose(
    db: AsyncSession, user_id: uuid.UUID, log_id: uuid.UUID
) -> tuple[DoseLog | None, str | None]:
    """
    Mark dose as taken. Returns (log, error).
    error is 'not_found' | 'not_pending' | None.
    """
    result = await db.execute(select(DoseLog).where(DoseLog.id == log_id, DoseLog.user_id == user_id))
    log = result.scalar_one_or_none()
    if log is None:
        return None, "not_found"
    if log.status != DoseStatus.pending:
        return log, "not_pending"
    log.status = DoseStatus.taken
    log.taken_at = datetime.now(timezone.utc)
    return log, None
