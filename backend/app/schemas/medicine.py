import uuid
from datetime import datetime, time

from pydantic import BaseModel, Field


class MedicineCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    dosage: str = Field(min_length=1, max_length=255)
    scheduled_time: time
    frequency: str = Field(default="daily", max_length=32)
    active: bool = True
    reminder_enabled: bool = True
    pill_count: int | None = Field(default=None, ge=0)


class MedicineUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    dosage: str | None = Field(default=None, min_length=1, max_length=255)
    scheduled_time: time | None = None
    frequency: str | None = Field(default=None, max_length=32)
    active: bool | None = None
    reminder_enabled: bool | None = None
    pill_count: int | None = Field(default=None, ge=0)


class LabelPreviewOut(BaseModel):
    product_name: str | None = None
    strength: str | None = None
    form: str | None = None
    summary: str | None = None


class MedicineOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    name: str
    dosage: str
    scheduled_time: time
    frequency: str
    active: bool
    reminder_enabled: bool
    pill_count: int | None
    label_image_key: str | None = None
    label_analysis_text: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}
