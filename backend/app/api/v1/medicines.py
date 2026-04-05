import uuid

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.medicine import Medicine
from app.models.reference_medicine import ReferenceMedicine
from app.models.user import User
from app.schemas.medicine import LabelPreviewOut, MedicineCreate, MedicineOut, MedicineUpdate
from app.schemas.reference_medicine import ReferenceMedicineOut
from app.services.cohere_label_analysis import analyze_label_preview_fields, analyze_medicine_label
from app.services.medicine_label_images import (
    delete_stored_file,
    file_path_for_key,
    mime_for_storage_key,
    read_label_upload_bytes,
    save_label_upload,
)

router = APIRouter()


@router.get("/catalog", response_model=list[ReferenceMedicineOut])
async def list_medicine_catalog(
    db: AsyncSession = Depends(get_db),
) -> list[ReferenceMedicine]:
    """Curated medicine names for app dropdowns (seeded in DB; same on cloud and local Postgres)."""
    q = select(ReferenceMedicine).order_by(ReferenceMedicine.sort_order, ReferenceMedicine.name)
    result = await db.execute(q)
    return list(result.scalars().all())


@router.post("/analyze-label-preview", response_model=LabelPreviewOut)
async def analyze_label_preview(
    file: UploadFile = File(...),
    _current: User = Depends(get_current_user),
) -> LabelPreviewOut:
    """Cohere vision: extract name/strength/form from a label photo (no medicine row required)."""
    image_bytes, content_type = await read_label_upload_bytes(file)
    fields = await analyze_label_preview_fields(image_bytes, content_type)
    if fields is None:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not read the label. Check the photo or try again.",
        )
    return LabelPreviewOut(**fields)


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


@router.post("/{medicine_id}/label-image", response_model=MedicineOut)
async def upload_medicine_label_image(
    medicine_id: uuid.UUID,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current: User = Depends(get_current_user),
) -> Medicine:
    result = await db.execute(
        select(Medicine).where(Medicine.id == medicine_id, Medicine.user_id == current.id)
    )
    med = result.scalar_one_or_none()
    if med is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medicine not found")
    old_key = med.label_image_key
    new_key = await save_label_upload(medicine_id, file)
    med.label_image_key = new_key
    med.label_analysis_text = None
    await db.flush()
    await db.refresh(med)
    delete_stored_file(old_key)
    return med


@router.get("/{medicine_id}/label-image")
async def get_medicine_label_image(
    medicine_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current: User = Depends(get_current_user),
) -> FileResponse:
    result = await db.execute(
        select(Medicine).where(Medicine.id == medicine_id, Medicine.user_id == current.id)
    )
    med = result.scalar_one_or_none()
    if med is None or not med.label_image_key:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No label image")
    path = file_path_for_key(med.label_image_key)
    if not path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File missing")
    media = mime_for_storage_key(med.label_image_key)
    return FileResponse(path, media_type=media)


@router.delete("/{medicine_id}/label-image", response_model=MedicineOut)
async def delete_medicine_label_image(
    medicine_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current: User = Depends(get_current_user),
) -> Medicine:
    result = await db.execute(
        select(Medicine).where(Medicine.id == medicine_id, Medicine.user_id == current.id)
    )
    med = result.scalar_one_or_none()
    if med is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medicine not found")
    delete_stored_file(med.label_image_key)
    med.label_image_key = None
    med.label_analysis_text = None
    await db.flush()
    await db.refresh(med)
    return med


@router.post("/{medicine_id}/analyze-label", response_model=MedicineOut)
async def analyze_medicine_label_text(
    medicine_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current: User = Depends(get_current_user),
) -> Medicine:
    result = await db.execute(
        select(Medicine).where(Medicine.id == medicine_id, Medicine.user_id == current.id)
    )
    med = result.scalar_one_or_none()
    if med is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medicine not found")
    if not med.label_image_key:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Upload a label image first")
    path = file_path_for_key(med.label_image_key)
    if not path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Label file missing")
    raw = path.read_bytes()
    ct = mime_for_storage_key(med.label_image_key)
    summary = await analyze_medicine_label(raw, ct)
    if not summary:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not analyze the label. Check COHERE_API_KEY or try another photo.",
        )
    med.label_analysis_text = summary
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
    delete_stored_file(med.label_image_key)
    await db.delete(med)
