from pydantic import BaseModel, Field


class MedicineCreate(BaseModel):
    name: str = Field(..., min_length=1)
    dosage: str = Field(..., min_length=1)
    scheduled_time: str = Field(..., pattern=r"^\d{2}:\d{2}$", description="24h HH:MM")
    frequency: str = Field(default="daily", pattern="^(daily|weekly|custom)$")
    days_of_week: list[int] = Field(default_factory=list, description="0=Sun..6=Sat, same as Flutter")
    pill_count: int = Field(default=30, ge=0)
    refill_at: int = Field(default=5, ge=0)
    member_name: str = Field(default="Self")
    active: bool = True


class MedicineUpdate(BaseModel):
    name: str | None = None
    dosage: str | None = None
    scheduled_time: str | None = Field(None, pattern=r"^\d{2}:\d{2}$")
    frequency: str | None = Field(None, pattern="^(daily|weekly|custom)$")
    days_of_week: list[int] | None = None
    pill_count: int | None = Field(None, ge=0)
    refill_at: int | None = Field(None, ge=0)
    member_name: str | None = None
    active: bool | None = None


class MedicineOut(BaseModel):
    id: str
    user_id: str
    name: str
    dosage: str
    scheduled_time: str
    frequency: str
    days_of_week: list[int]
    pill_count: int
    refill_at: int
    member_name: str
    active: bool
