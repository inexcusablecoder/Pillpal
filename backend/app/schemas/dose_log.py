import uuid
from datetime import date, datetime, time

from pydantic import BaseModel


class DoseLogOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    medicine_id: uuid.UUID
    medicine_name: str
    scheduled_date: date
    scheduled_time: time
    status: str
    taken_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


class DoseLogTodayItem(DoseLogOut):
    pass


class SyncResponse(BaseModel):
    today: date
    dose_logs_created: int
    missed_marked: int
