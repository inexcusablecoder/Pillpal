import re
import time
import threading
import schedule
from typing import List, Optional
from datetime import datetime, date

from twilio.rest import Client
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, validator
from sqlalchemy import create_engine, Column, Integer, String, text
from sqlalchemy.orm import sessionmaker, declarative_base, Session
from app.core.config import settings

# Use router instead of app = FastAPI()
router = APIRouter(tags=["twilio_calls"])

# ==============================
# 🔐 AUDIO (Custom mp3)
# ==============================
DEFAULT_AUDIO_URL = "https://raw.githubusercontent.com/pranav16-king/apk/main/WhatsApp%20Audio%202026-03-20%20at%2023.41.07.mp3"

# ==============================
# 🗄️ DB (PostgreSQL)
# ==============================
DATABASE_URL = settings.database_url

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()

# ==============================
# 📦 MODEL
# ==============================
class CallSchedule(Base):
    __tablename__ = "call_schedules"

    id = Column(Integer, primary_key=True)
    phone = Column(String)
    times = Column(String)
    message = Column(String)
    audio_url = Column(String)
    call_type = Column(String, default="audio") # "text" or "audio"
    start_date = Column(String)
    end_date = Column(String)

# ==============================
# 🛠️ AUTO FIX DB (IMPORTANT)
# ==============================
def fix_db_schema():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    # ensure columns exist
    for col in ["start_date", "end_date", "audio_url", "call_type"]:
        try:
            db.execute(text(f"ALTER TABLE call_schedules ADD COLUMN {col} TEXT"))
        except Exception:
            pass

    db.commit()
    db.close()

# ==============================
# 📥 SCHEMA
# ==============================
class CallCreate(BaseModel):
    phone: str
    times: List[str]
    start_date: str
    end_date: str
    call_type: str = "audio" # "text" or "audio"
    message: Optional[str] = "Please take your medicine on time"
    audio_url: Optional[str] = None

    @validator("times")
    def validate_times(cls, v):
        if not v:
            raise ValueError("At least one time is required")
        if len(v) > 3:
            raise ValueError("Max 3 times allowed")
        for t in v:
            if not re.match(r"^\d{2}:\d{2}$", t):
                raise ValueError(f"Invalid time format: {t}. Expected HH:MM")
        return v

# ==============================
# 🛠️ HELPERS
# ==============================
def get_twilio_client():
    if settings.twilio_account_sid and settings.twilio_auth_token:
        return Client(settings.twilio_account_sid, settings.twilio_auth_token)
    return None

def format_number(number):
    if not number: return None
    number = number.strip()
    if re.fullmatch(r"\d{10}", number):
        return "+91" + number
    if number.startswith("+"):
        return number
    return None

# ==============================
# 🔊 CALL ENGINE (Text vs Voice Choice)
# ==============================
def make_call(phone, message, audio_url, call_type):
    try:
        client = get_twilio_client()
        if not client:
            print("❌ Twilio client NOT configured in Settings.")
            return

        if call_type == "text":
            twiml = f"<Response><Say voice='alice'>{message}</Say></Response>"
            print(f"📞 Calling {phone} (Text-to-Speech: {message})")
        else:
            # Use explicitly passed audio_url or the default one
            final_audio = audio_url if audio_url else DEFAULT_AUDIO_URL
            twiml = f"<Response><Play>{final_audio}</Play></Response>"
            print(f"📞 Calling {phone} (Audio URL: {final_audio})")

        client.calls.create(
            twiml=twiml,
            to=phone,
            from_=settings.twilio_number
        )

        print(f"✅ Call initiated successfully to {phone}")

    except Exception as e:
        print("❌ Twilio Call error:", e)

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
            try:
                start = datetime.strptime(s.start_date, "%Y-%m-%d").date()
                end = datetime.strptime(s.end_date, "%Y-%m-%d").date()

                if not (start <= today <= end):
                    continue

                for t in s.times.split(","):
                    schedule.every().day.at(t).do(
                        make_call,
                        phone=s.phone,
                        message=s.message,
                        audio_url=s.audio_url,
                        call_type=s.call_type
                    )

                    print(f"⏰ Scheduled {s.phone} at {t} (Type: {s.call_type})")

            except Exception as e:
                print("⚠️ Skipping invalid record in scheduler load:", e)

        db.close()

    except Exception as e:
        print("❌ Scheduler load error:", e)

def run_scheduler():
    while True:
        schedule.run_pending()
        time.sleep(1)

# ==============================
# 🚀 STARTUP INIT
# ==============================
def startup_twilio_service():
    print("🚀 Initializing Twilio Service (v3 Text vs Music Fixed)...")
    fix_db_schema()
    load_jobs()
    threading.Thread(target=run_scheduler, daemon=True).start()

# ==============================
# 📦 DB DEP
# ==============================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ==============================
# ➕ CREATE / POST
# ==============================
@router.post("/schedule")
def create(data: CallCreate, db: Session = Depends(get_db)):
    phone = format_number(data.phone)
    if not phone:
        raise HTTPException(400, "Invalid phone number format")

    obj = CallSchedule(
        phone=phone,
        times=",".join(data.times),
        message=data.message,
        audio_url=data.audio_url,
        call_type=data.call_type,
        start_date=data.start_date,
        end_date=data.end_date
    )

    db.add(obj)
    db.commit()
    load_jobs()
    return {"msg": "✅ Call scheduled successfully"}

# ==============================
# 📋 LIST / GET
# ==============================
@router.get("/schedules", response_model=List[dict])
def get_all(db: Session = Depends(get_db)):
    items = db.query(CallSchedule).all()
    # return as list of dicts for simple frontend consumption
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

# ==============================
# 📱 LAST PHONE
# ==============================
@router.get("/last-phone")
def last_phone(db: Session = Depends(get_db)):
    last = db.query(CallSchedule).order_by(CallSchedule.id.desc()).first()
    return {"phone": last.phone if last else ""}

# ==============================
# ✏️ UPDATE / PUT
# ==============================
@router.put("/schedule/{idx}")
def update(idx: int, data: CallCreate, db: Session = Depends(get_db)):
    item = db.query(CallSchedule).filter(CallSchedule.id == idx).first()
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

    db.commit()
    load_jobs()
    return {"msg": "✅ Schedule updated successfully"}

# ==============================
# ❌ DELETE
# ==============================
@router.delete("/schedule/{idx}")
def delete(idx: int, db: Session = Depends(get_db)):
    item = db.query(CallSchedule).filter(CallSchedule.id == idx).first()
    if not item:
        raise HTTPException(404, "Not found")

    db.delete(item)
    db.commit()
    load_jobs()
    return {"msg": "✅ Removed"}
