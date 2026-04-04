import re
import time
import threading
import schedule
import logging
from typing import List, Optional
from datetime import datetime, date, timezone
import uuid

from twilio.rest import Client
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, select, update, delete, create_engine, text
from sqlalchemy.orm import Session, sessionmaker, Mapped, mapped_column, relationship
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.postgresql import UUID

from app.core.config import settings
from app.core.database import Base, get_db as get_async_db
from app.core.deps import get_current_user
from app.models.user import User

logger = logging.getLogger("pillpal.twilio")

# Use router instead of app = FastAPI()
router = APIRouter(tags=["twilio_calls"])

# ==============================
# 🔐 AUDIO (Custom mp3)
# ==============================
DEFAULT_AUDIO_URL = "https://raw.githubusercontent.com/pranav16-king/apk/main/WhatsApp%20Audio%202026-03-20%20at%2023.41.07.mp3"

# ==============================
# 🗄️ SYNC DB FOR SCHEDULER
# ==============================
# The scheduler runs in a background thread and needs a sync connection
sync_engine = create_engine(settings.database_url)
SessionLocal = sessionmaker(bind=sync_engine)

# ==============================
# 📦 MODELS
# ==============================
class CallSchedule(Base):
    __tablename__ = "call_schedules"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    phone: Mapped[str] = mapped_column(String(32))
    times: Mapped[str] = mapped_column(String(255)) # comma separated
    message: Mapped[Optional[str]] = mapped_column(String(500))
    audio_url: Mapped[Optional[str]] = mapped_column(String(500))
    call_type: Mapped[str] = mapped_column(String(32), default="audio") # "text" or "audio"
    start_date: Mapped[str] = mapped_column(String(32))
    end_date: Mapped[str] = mapped_column(String(32))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    user: Mapped["User"] = relationship("User")

class CallHistory(Base):
    __tablename__ = "call_history"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    schedule_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("call_schedules.id", ondelete="SET NULL"))
    phone: Mapped[str] = mapped_column(String(32))
    status: Mapped[str] = mapped_column(String(32)) # "initiated", "failed"
    call_type: Mapped[str] = mapped_column(String(32))
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    error_message: Mapped[Optional[str]] = mapped_column(String(500))

# ==============================
# 🛠️ AUTO FIX DB (IMPORTANT)
# ==============================
def fix_db_schema():
    # Base.metadata.create_all(bind=sync_engine) # This can be handled by alembic, but for now:
    try:
        from sqlalchemy import inspect
        inspector = inspect(sync_engine)
        
        # 1. Create missing tables
        if "call_history" not in inspector.get_table_names():
            Base.metadata.create_all(bind=sync_engine)
            logger.info("Created missing twilio tables")
            
        # 2. Fix missing columns in call_schedules
        cols = [c["name"] for c in inspector.get_columns("call_schedules")]
        with sync_engine.connect() as conn:
            if "user_id" not in cols:
                # Assuming UUID for existing users, but easier to just add it
                # For safety in dev, we use a simple migration
                conn.execute(text('ALTER TABLE call_schedules ADD COLUMN user_id UUID REFERENCES users(id)'))
                logger.info("Added user_id to call_schedules")
            if "created_at" not in cols:
                conn.execute(text('ALTER TABLE call_schedules ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()'))
                logger.info("Added created_at to call_schedules")

            # 3. Fix missing columns in users table
            user_cols = [c["name"] for c in inspector.get_columns("users")]
            if "language" not in user_cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN language VARCHAR(10) DEFAULT 'en'"))
                logger.info("Added language column to users table")

            conn.commit()

    except Exception as e:
        logger.error(f"Error checking/fixing twilio schema: {e}")

# ==============================
# 📥 SCHEMAS
# ==============================
class CallCreate(BaseModel):
    phone: str
    times: List[str]
    start_date: str
    end_date: str
    call_type: str = "audio" # "text" or "audio"
    message: Optional[str] = "Please take your medicine on time"
    audio_url: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

# ==============================
# 🛠️ HELPERS
# ==============================
def get_twilio_client():
    if settings.twilio_account_sid and settings.twilio_auth_token:
        return Client(settings.twilio_account_sid, settings.twilio_auth_token)
    return None

def format_number(number: str) -> Optional[str]:
    if not number: return None
    number = number.strip()
    # If 10 digits, assume India default +91
    if re.fullmatch(r"\d{10}", number):
        return "+91" + number
    # If starts with +, it's already full format
    if number.startswith("+"):
        return number
    # If it starts with digits but has more than 10, maybe it's country code without +
    if re.fullmatch(r"\d{11,15}", number):
        return "+" + number
    return None

# ==============================
# 🔊 CALL ENGINE (Text vs Voice Choice)
# ==============================
def make_call(user_id, phone, message, audio_url, call_type, schedule_id=None):
    db = SessionLocal()
    history_entry = CallHistory(
        user_id=user_id,
        schedule_id=schedule_id,
        phone=phone,
        call_type=call_type,
        status="initiated"
    )
    try:
        client = get_twilio_client()
        if not client:
            logger.error("❌ Twilio client NOT configured.")
            history_entry.status = "failed"
            history_entry.error_message = "Twilio client NOT configured"
            db.add(history_entry)
            db.commit()
            return

        if call_type == "text":
            twiml = f"<Response><Say voice='alice'>{message}</Say></Response>"
            logger.info(f"📞 Calling {phone} (Text-to-Speech)")
        else:
            final_audio = audio_url if audio_url else DEFAULT_AUDIO_URL
            twiml = f"<Response><Play>{final_audio}</Play></Response>"
            logger.info(f"📞 Calling {phone} (Audio URL)")

        client.calls.create(
            twiml=twiml,
            to=phone,
            from_=settings.twilio_number
        )
        logger.info(f"✅ Call initiated successfully to {phone}")
        history_entry.status = "initiated"
        db.add(history_entry)
        db.commit()

    except Exception as e:
        logger.error(f"❌ Twilio Call error: {e}")
        history_entry.status = "failed"
        history_entry.error_message = str(e)
        db.add(history_entry)
        db.commit()
    finally:
        db.close()

# ==============================
# ⏰ SCHEDULER
# ==============================
def load_jobs():
    try:
        schedule.clear()
        db = SessionLocal()
        data = db.query(CallSchedule).all()

        today = date.today()

        for s in data:
            if not s.user_id:
                logger.warning(f"⚠️ Skipping record {s.id}: No user_id assigned.")
                continue
            try:
                # Ensure dates are parsed correctly
                start = datetime.strptime(s.start_date, "%Y-%m-%d").date()
                end = datetime.strptime(s.end_date, "%Y-%m-%d").date()

                if not (start <= today <= end):
                    continue

                for t in s.times.split(","):
                    try:
                        schedule.every().day.at(t).do(
                            make_call,
                            user_id=s.user_id,
                            phone=s.phone,
                            message=s.message,
                            audio_url=s.audio_url,
                            call_type=s.call_type,
                            schedule_id=s.id
                        )
                        logger.info(f"⏰ Scheduled {s.phone} at {t}")
                    except Exception as te:
                        logger.warning(f"Invalid time in record {s.id}: {t} -> {te}")

            except Exception as e:
                logger.warning(f"⚠️ Skipping invalid record {s.id}: {e}")

        db.close()
    except Exception as e:
        logger.error(f"❌ Scheduler load error: {e}")

def run_scheduler():
    while True:
        try:
            schedule.run_pending()
        except Exception as e:
            logger.error(f"Scheduler loop error: {e}")
        time.sleep(1)

# ==============================
# 🚀 STARTUP INIT
# ==============================
def startup_twilio_service():
    logger.info("🚀 Initializing Twilio Service with Multi-user support...")
    fix_db_schema()
    load_jobs()
    threading.Thread(target=run_scheduler, daemon=True).start()

# ==============================
# ➕ CREATE / POST
# ==============================
@router.post("/schedule")
async def create(
    data: CallCreate, 
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user)
):
    phone = format_number(data.phone)
    if not phone:
        raise HTTPException(400, "Invalid phone number format")

    obj = CallSchedule(
        user_id=current_user.id,
        phone=phone,
        times=",".join(data.times),
        message=data.message,
        audio_url=data.audio_url,
        call_type=data.call_type,
        start_date=data.start_date,
        end_date=data.end_date
    )

    db.add(obj)
    await db.commit() # Ensure persisted before scheduler reloads
    # Trigger job reload (syncly or via flag)
    load_jobs()
    return {"msg": "✅ Call scheduled successfully"}

# ==============================
# 📋 LIST / GET
# ==============================
@router.get("/schedules")
async def get_all(
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(CallSchedule).where(CallSchedule.user_id == current_user.id))
    items = result.scalars().all()
    
    return [
        {
            "id": i.id,
            "phone": i.phone,
            "times": i.times.split(","),
            "message": i.message,
            "audio_url": i.audio_url,
            "call_type": i.call_type,
            "start_date": i.start_date,
            "end_date": i.end_date
        } for i in items
    ]

@router.get("/history")
async def get_history(
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(CallHistory).where(CallHistory.user_id == current_user.id).order_by(CallHistory.timestamp.desc()))
    items = result.scalars().all()
    
    return [
        {
            "id": i.id,
            "phone": i.phone,
            "status": i.status,
            "call_type": i.call_type,
            "timestamp": i.timestamp.isoformat(),
            "error_message": i.error_message
        } for i in items
    ]

# ==============================
# 📱 LAST PHONE
# ==============================
@router.get("/last-phone")
async def last_phone(
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(CallSchedule).where(CallSchedule.user_id == current_user.id).order_by(CallSchedule.id.desc()))
    last = result.scalars().first()
    return {"phone": last.phone if last else ""}

# ==============================
# ✏️ UPDATE / PUT
# ==============================
@router.put("/schedule/{idx}")
async def update_schedule(
    idx: int, 
    data: CallCreate, 
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(CallSchedule).where((CallSchedule.id == idx) & (CallSchedule.user_id == current_user.id)))
    item = result.scalar_one_or_none()
    
    if not item:
        raise HTTPException(404, "Schedule not found")

    phone = format_number(data.phone)
    if not phone:
        raise HTTPException(400, "Invalid phone number")

    item.phone = phone
    item.times = ",".join(data.times)
    item.message = data.message
    item.audio_url = data.audio_url
    item.call_type = data.call_type
    item.start_date = data.start_date
    item.end_date = data.end_date

    await db.commit() # Ensure persisted before scheduler reloads
    load_jobs()
    return {"msg": "✅ Schedule updated successfully"}

# ==============================
# ❌ DELETE
# ==============================
@router.delete("/schedule/{idx}")
async def delete_schedule(
    idx: int, 
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(CallSchedule).where((CallSchedule.id == idx) & (CallSchedule.user_id == current_user.id)))
    item = result.scalar_one_or_none()
    
    if not item:
        raise HTTPException(404, "Not found")

    await db.delete(item)
    await db.flush()
    load_jobs()
    return {"msg": "✅ Removed"}
