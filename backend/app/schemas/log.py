from pydantic import BaseModel, Field


class LogOut(BaseModel):
    id: str
    user_id: str
    medicine_id: str
    medicine_name: str
    dosage: str
    scheduled_time: str
    date: str
    status: str
    taken_at: str | None = None


class MarkTakenBody(BaseModel):
    log_id: str = Field(..., min_length=1)
    medicine_id: str = Field(..., min_length=1)


class StartupResult(BaseModel):
    logs_generated: int
    marked_missed: int
    message: str
