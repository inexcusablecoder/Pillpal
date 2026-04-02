import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.medicine import Medicine
from app.models.reference_medicine import ReferenceMedicine
from app.models.user import User
from app.schemas.medicine import MedicineCreate, MedicineOut, MedicineUpdate
from app.schemas.reference_medicine import ReferenceMedicineOut

router = APIRouter()


@router.get("/catalog", response_model=list[ReferenceMedicineOut])
async def list_medicine_catalog(
    db: AsyncSession = Depends(get_db),
) -> list[ReferenceMedicine]:
    """Curated medicine names for app dropdowns (seeded in DB; same on cloud and local Postgres)."""
    q = select(ReferenceMedicine).order_by(ReferenceMedicine.sort_order, ReferenceMedicine.name)
    result = await db.execute(q)
    return list(result.scalars().all())


@router.get("", response_model=list[MedicineOut])
async def list_medicines(
    db: AsyncSession = Depends(get_db),
    current: User = Depends(get_current_user),
    active_only: bool = Query(False, description="If true, only active medicines"),
) -> list[Medicine]:
    q = select(Medicine).where(Medicine.user_id == current.id)
    if active_only:
        q = q.where(Medicine.active.is_(True))
    q = q.order_by(Medicine.scheduled_time)
    result = await db.execute(q)
    return list(result.scalars().all())


@router.post("", response_model=MedicineOut, status_code=status.HTTP_201_CREATED)
async def create_medicine(
    body: MedicineCreate,
    db: AsyncSession = Depends(get_db),
    current: User = Depends(get_current_user),
) -> Medicine:
    med = Medicine(
        user_id=current.id,
        name=body.name,
        dosage=body.dosage,
        scheduled_time=body.scheduled_time,
        frequency=body.frequency,
        active=body.active,
        reminder_enabled=body.reminder_enabled,
        pill_count=body.pill_count,
    )
    db.add(med)
    await db.flush()
    await db.refresh(med)
    return med


@router.patch("/{medicine_id}", response_model=MedicineOut)
async def update_medicine(
    medicine_id: uuid.UUID,
    body: MedicineUpdate,
    db: AsyncSession = Depends(get_db),
    current: User = Depends(get_current_user),
) -> Medicine:
    result = await db.execute(
        select(Medicine).where(Medicine.id == medicine_id, Medicine.user_id == current.id)
    )
    med = result.scalar_one_or_none()
    if med is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medicine not found")
    data = body.model_dump(exclude_unset=True)
    for k, v in data.items():
        setattr(med, k, v)
    await db.flush()
    await db.refresh(med)
    return med


@router.delete("/{medicine_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_medicine(
    medicine_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current: User = Depends(get_current_user),
) -> None:
    result = await db.execute(
        select(Medicine).where(Medicine.id == medicine_id, Medicine.user_id == current.id)
    )
    med = result.scalar_one_or_none()
    if med is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medicine not found")
    await db.delete(med)
