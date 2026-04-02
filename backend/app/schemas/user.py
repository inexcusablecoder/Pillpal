import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str | None = Field(default=None, max_length=255)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    display_name: str | None = Field(default=None, max_length=255)
    phone_e164: str | None = Field(default=None, max_length=32)
    alarm_reminders_enabled: bool | None = None

    @field_validator("phone_e164", mode="before")
    @classmethod
    def empty_phone_to_none(cls, v: object) -> object:
        if v == "":
            return None
        return v


class UserOut(BaseModel):
    id: uuid.UUID
    email: str
    display_name: str | None
    phone_e164: str | None
    alarm_reminders_enabled: bool
    created_at: datetime

    model_config = {"from_attributes": True}
