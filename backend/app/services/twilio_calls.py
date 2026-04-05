import logging
import re
import uuid
import xml.sax.saxutils as xml_esc
from datetime import date, datetime, timedelta, timezone
from typing import Optional
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict
from sqlalchemy import DateTime, ForeignKey, Integer, String, create_engine, select, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column, relationship, sessionmaker
from twilio.base.exceptions import TwilioRestException
from twilio.rest import Client

from app.core.config import settings
from app.core.database import Base, get_db as get_async_db
from app.core.deps import get_current_user
from app.models.user import User

logger = logging.getLogger("pillpal.twilio")

# Twilio <Say language="..."> — use codes Twilio documents for Say (hi-IN, en-IN, en-US). Other app langs → en-IN.
_TTS_LANG_BY_APP: dict[str, str] = {
    "en": "en-US",
    "hi": "hi-IN",
    "bn": "en-IN",
    "te": "en-IN",
    "mr": "en-IN",
    "ta": "en-IN",
    "gu": "en-IN",
    "kn": "en-IN",
}

_call_scheduler: BackgroundScheduler | None = None

router = APIRouter(tags=["twilio_calls"])

DEFAULT_AUDIO_URL = "https://raw.githubusercontent.com/pranav16-king/apk/main/WhatsApp%20Audio%202026-03-20%20at%2023.41.07.mp3"


def _sync_database_url(url: str) -> str:
    if url.startswith("postgresql+asyncpg://"):
        url = url.replace("postgresql+asyncpg://", "postgresql://", 1)
    parsed = urlparse(url)
    pairs = [
        (k, v)
        for k, v in parse_qsl(parsed.query, keep_blank_values=True)
        if k.lower() != "channel_binding"
    ]
    return urlunparse(parsed._replace(query=urlencode(pairs)))


sync_engine = create_engine(
    _sync_database_url(settings.database_url),
    pool_pre_ping=True,
)
SessionLocal = sessionmaker(bind=sync_engine)


class CallSchedule(Base):
    __tablename__ = "call_schedules"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    phone: Mapped[str] = mapped_column(String(32))
    times: Mapped[str] = mapped_column(String(255))
    message: Mapped[Optional[str]] = mapped_column(String(500))
    audio_url: Mapped[Optional[str]] = mapped_column(String(500))
    call_type: Mapped[str] = mapped_column(String(32), default="audio")
    start_date: Mapped[str] = mapped_column(String(32))
    end_date: Mapped[str] = mapped_column(String(32))
    schedule_timezone: Mapped[str] = mapped_column(String(64), default="Asia/Kolkata")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    user: Mapped["User"] = relationship("User")


class CallHistory(Base):
    __tablename__ = "call_history"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    schedule_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("call_schedules.id", ondelete="SET NULL"))
    phone: Mapped[str] = mapped_column(String(32))
    status: Mapped[str] = mapped_column(String(32))
    call_type: Mapped[str] = mapped_column(String(32))
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    error_message: Mapped[Optional[str]] = mapped_column(String(500))


def fix_db_schema():
    try:
        from sqlalchemy import inspect

        inspector = inspect(sync_engine)

        if "call_history" not in inspector.get_table_names():
            Base.metadata.create_all(bind=sync_engine)
            logger.info("Created missing twilio tables")

        if "call_schedules" not in inspector.get_table_names():
            return

        cols = [c["name"] for c in inspector.get_columns("call_schedules")]
        with sync_engine.connect() as conn:
            if "user_id" not in cols:
                conn.execute(text("ALTER TABLE call_schedules ADD COLUMN user_id UUID REFERENCES users(id)"))
                logger.info("Added user_id to call_schedules")
            if "created_at" not in cols:
                conn.execute(
                    text("ALTER TABLE call_schedules ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()")
                )
                logger.info("Added created_at to call_schedules")
            if "schedule_timezone" not in cols:
                conn.execute(
                    text(
                        "ALTER TABLE call_schedules ADD COLUMN schedule_timezone VARCHAR(64) "
                        "NOT NULL DEFAULT 'Asia/Kolkata'"
                    )
                )
                logger.info("Added schedule_timezone to call_schedules")

            user_cols = [c["name"] for c in inspector.get_columns("users")]
            if "language" not in user_cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN language VARCHAR(10) DEFAULT 'en'"))
                logger.info("Added language column to users table")

            conn.commit()

    except Exception as e:
        logger.error("Error checking/fixing twilio schema: %s", e)


class CallCreate(BaseModel):
    phone: str
    times: list[str]
    start_date: str
    end_date: str
    call_type: str = "audio"
    message: Optional[str] = "Please take your medicine on time"
    audio_url: Optional[str] = None
    schedule_timezone: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class TestCallBody(BaseModel):
    """Optional override phone; otherwise uses profile phone_e164."""

    phone: Optional[str] = None
    mode: str = "text"  # "text" | "audio"

    model_config = ConfigDict(from_attributes=True)


def get_twilio_client():
    if settings.twilio_account_sid and settings.twilio_auth_token:
        return Client(settings.twilio_account_sid, settings.twilio_auth_token)
    return None


def _twilio_from_number() -> Optional[str]:
    raw = (settings.twilio_number or "").strip().replace(" ", "")
    return raw or None


def format_number(number: str) -> Optional[str]:
    if not number:
        return None
    number = number.strip().replace(" ", "").replace("-", "")
    if re.fullmatch(r"\d{10}", number):
        return "+91" + number
    if number.startswith("+"):
        return number
    if re.fullmatch(r"\d{11,15}", number):
        return "+" + number
    return None


def _resolve_timezone(name: Optional[str]) -> ZoneInfo:
    raw = (name or settings.call_schedule_default_timezone or "UTC").strip()
    try:
        return ZoneInfo(raw)
    except ZoneInfoNotFoundError:
        logger.warning("Unknown IANA timezone %r; using UTC", raw)
        return ZoneInfo("UTC")


def _twilio_say_language(app_lang: Optional[str]) -> str:
    raw = (app_lang or "en").strip().lower()
    code = raw.split("-")[0][:2] if raw else "en"
    return _TTS_LANG_BY_APP.get(code, "en-US")


def _normalize_hhmm(t: str) -> Optional[str]:
    t = t.strip()
    if not t:
        return None
    parts = t.split(":")
    if len(parts) < 2:
        return None
    try:
        h = int(parts[0])
        m = int(parts[1])
    except ValueError:
        return None
    if not (0 <= h <= 23 and 0 <= m <= 59):
        return None
    return f"{h:02d}:{m:02d}"


def make_call(user_id, phone, message, audio_url, call_type, schedule_id=None):
    db = SessionLocal()
    history_entry = CallHistory(
        user_id=user_id,
        schedule_id=schedule_id,
        phone=phone,
        call_type=call_type,
        status="initiated",
    )
    try:
        user_row = db.execute(select(User).where(User.id == user_id)).scalar_one_or_none()
        user_lang = (user_row.language if user_row else None) or "en"
        tts_lang = _twilio_say_language(user_lang)

        from_num = _twilio_from_number()
        if not from_num:
            logger.error("TWILIO_NUMBER is not set")
            history_entry.status = "failed"
            history_entry.error_message = "TWILIO_NUMBER not configured"
            db.add(history_entry)
            db.commit()
            return

        client = get_twilio_client()
        if not client:
            logger.error("Twilio client NOT configured (SID/token)")
            history_entry.status = "failed"
            history_entry.error_message = "Twilio client NOT configured"
            db.add(history_entry)
            db.commit()
            return

        if call_type == "text":
            safe = xml_esc.escape(message or "Please take your medicine on time")
            twiml_lang = f'<Response><Say language="{tts_lang}">{safe}</Say></Response>'
            twiml_plain = f"<Response><Say>{safe}</Say></Response>"
            logger.info("Calling %s (TTS lang=%s)", phone, tts_lang)
            try:
                client.calls.create(twiml=twiml_lang, to=phone, from_=from_num)
            except TwilioRestException as tre:
                # Some subaccounts reject certain language codes; default English Say works widely.
                logger.warning("Localized Say failed (code=%s), retrying default voice: %s", getattr(tre, "code", None), tre)
                client.calls.create(twiml=twiml_plain, to=phone, from_=from_num)
        else:
            final_audio = audio_url if audio_url else DEFAULT_AUDIO_URL
            twiml = f"<Response><Play>{xml_esc.escape(final_audio)}</Play></Response>"
            logger.info("Calling %s (audio URL)", phone)
            client.calls.create(twiml=twiml, to=phone, from_=from_num)
        logger.info("Call initiated to %s", phone)
        history_entry.status = "initiated"
        db.add(history_entry)
        db.commit()

    except Exception as e:
        logger.exception("Twilio call error: %s", e)
        history_entry.status = "failed"
        history_entry.error_message = str(e)[:500]
        db.add(history_entry)
        db.commit()
    finally:
        db.close()


# (schedule_id, normalized "HH:MM") -> local calendar date we already fired on
_fired_local_day: dict[tuple[int, str], date] = {}


def _prune_fired() -> None:
    global _fired_local_day
    cutoff = date.today() - timedelta(days=3)
    _fired_local_day = {k: v for k, v in _fired_local_day.items() if v >= cutoff}


def tick_reminder_calls() -> None:
    """
    Fire outbound calls when wall-clock HH:MM in the schedule's IANA timezone matches.
    The old `schedule` library used the *server OS* timezone, so calls never lined up on UTC hosts.
    """
    global _fired_local_day
    _prune_fired()
    now_utc = datetime.now(timezone.utc)

    db = SessionLocal()
    try:
        rows = db.execute(select(CallSchedule)).scalars().all()
        for s in rows:
            if not s.user_id:
                logger.warning("Skipping call_schedule id=%s: missing user_id", s.id)
                continue
            try:
                start = datetime.strptime(s.start_date.strip(), "%Y-%m-%d").date()
                end = datetime.strptime(s.end_date.strip(), "%Y-%m-%d").date()
            except ValueError:
                logger.warning("Invalid dates on schedule id=%s", s.id)
                continue

            tz = _resolve_timezone(getattr(s, "schedule_timezone", None))
            local_now = now_utc.astimezone(tz)
            today_local = local_now.date()
            if not (start <= today_local <= end):
                continue

            hm = f"{local_now.hour:02d}:{local_now.minute:02d}"
            for raw in (s.times or "").replace("\r", "").split(","):
                slot = _normalize_hhmm(raw)
                if not slot or slot != hm:
                    continue
                key = (s.id, slot)
                if _fired_local_day.get(key) == today_local:
                    continue
                _fired_local_day[key] = today_local
                logger.info(
                    "Medicine reminder firing schedule_id=%s phone=%s tz=%s local=%s",
                    s.id,
                    s.phone,
                    tz.key,
                    hm,
                )
                make_call(
                    s.user_id,
                    s.phone,
                    s.message,
                    s.audio_url,
                    s.call_type,
                    schedule_id=s.id,
                )
    except Exception:
        logger.exception("tick_reminder_calls failed")
    finally:
        db.close()


def load_jobs():
    """Kept for API compatibility after create/update/delete; engine reads DB each tick."""
    pass


def startup_twilio_service() -> None:
    """Start APScheduler background jobs (README: worker uses APScheduler for Twilio triggers)."""
    global _call_scheduler
    logger.info("Initializing Twilio call scheduler (APScheduler + timezone-aware ticks)")
    fix_db_schema()
    if _call_scheduler is not None:
        return
    sched = BackgroundScheduler(timezone="UTC")
    sched.add_job(
        tick_reminder_calls,
        trigger=IntervalTrigger(seconds=10),
        id="pillpal_twilio_reminder_ticks",
        replace_existing=True,
        max_instances=1,
        coalesce=True,
        misfire_grace_time=45,
    )
    sched.start()
    _call_scheduler = sched
    logger.info("APScheduler started (10s interval for medicine reminder calls)")


def shutdown_twilio_service() -> None:
    global _call_scheduler
    if _call_scheduler is not None:
        _call_scheduler.shutdown(wait=False)
        _call_scheduler = None
        logger.info("APScheduler shut down")


@router.get("/reminder-status")
async def reminder_status(
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user),
) -> dict:
    """Debug: Twilio env + APScheduler + how many schedules you have saved."""
    global _call_scheduler
    sched = _call_scheduler
    jobs: list[dict] = []
    if sched is not None:
        for j in sched.get_jobs():
            nr = j.next_run_time
            jobs.append({"id": j.id, "next_run_time": nr.isoformat() if nr else None})
    res = await db.execute(select(CallSchedule).where(CallSchedule.user_id == current_user.id))
    n_sched = len(res.scalars().all())
    return {
        "scheduler_running": sched is not None and getattr(sched, "running", False),
        "scheduler_jobs": jobs,
        "twilio_account_sid_set": bool((settings.twilio_account_sid or "").strip()),
        "twilio_auth_token_set": bool((settings.twilio_auth_token or "").strip()),
        "twilio_from_number_set": bool(_twilio_from_number()),
        "profile_phone_e164_set": bool((current_user.phone_e164 or "").strip()),
        "your_saved_schedules": n_sched,
        "notes": [
            "Twilio trial accounts can only call verified destination numbers (Twilio Console → Verified Caller IDs).",
            "Reminder times use the timezone shown when you save a schedule; start/end dates must include today.",
        ],
    }


@router.post("/test")
async def test_call_now(
    body: TestCallBody,
    current_user: User = Depends(get_current_user),
) -> dict:
    """Place one immediate test call (uses same Twilio path as scheduled reminders)."""
    raw = (body.phone or current_user.phone_e164 or "").strip()
    phone = format_number(raw)
    if not phone:
        raise HTTPException(
            status_code=400,
            detail="Enter a phone number in this form or save Mobile under Profile.",
        )
    mode = (body.mode or "text").strip().lower()
    if mode not in ("text", "audio"):
        mode = "text"
    msg = "This is a PillPal test call. If you hear this, reminder calls can reach your phone."
    make_call(
        current_user.id,
        phone,
        msg,
        None,
        mode,
        schedule_id=None,
    )
    return {
        "ok": True,
        "phone": phone,
        "mode": mode,
        "detail": "Check your phone and Recent Call Activity for status or errors.",
    }


@router.post("/schedule")
async def create(
    data: CallCreate,
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user),
):
    phone = format_number(data.phone)
    if not phone:
        raise HTTPException(400, "Invalid phone number format")

    try:
        start = datetime.strptime(data.start_date, "%Y-%m-%d").date()
        end = datetime.strptime(data.end_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(400, "start_date and end_date must be YYYY-MM-DD") from None
    if start > end:
        raise HTTPException(400, "start_date must be on or before end_date")

    tz_name = (data.schedule_timezone or settings.call_schedule_default_timezone).strip()

    obj = CallSchedule(
        user_id=current_user.id,
        phone=phone,
        times=",".join(data.times),
        message=data.message,
        audio_url=data.audio_url,
        call_type=data.call_type,
        start_date=data.start_date,
        end_date=data.end_date,
        schedule_timezone=tz_name,
    )

    db.add(obj)
    await db.commit()
    load_jobs()
    return {"msg": "Call scheduled successfully"}


@router.get("/schedules")
async def get_all(
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user),
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
            "end_date": i.end_date,
            "schedule_timezone": i.schedule_timezone,
        }
        for i in items
    ]


@router.get("/history")
async def get_history(
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(CallHistory)
        .where(CallHistory.user_id == current_user.id)
        .order_by(CallHistory.timestamp.desc())
    )
    items = result.scalars().all()

    return [
        {
            "id": i.id,
            "phone": i.phone,
            "status": i.status,
            "call_type": i.call_type,
            "timestamp": i.timestamp.isoformat(),
            "error_message": i.error_message,
        }
        for i in items
    ]


@router.get("/last-phone")
async def last_phone(
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(CallSchedule).where(CallSchedule.user_id == current_user.id).order_by(CallSchedule.id.desc())
    )
    last = result.scalars().first()
    return {"phone": last.phone if last else ""}


@router.put("/schedule/{idx}")
async def update_schedule(
    idx: int,
    data: CallCreate,
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(CallSchedule).where((CallSchedule.id == idx) & (CallSchedule.user_id == current_user.id))
    )
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(404, "Schedule not found")

    phone = format_number(data.phone)
    if not phone:
        raise HTTPException(400, "Invalid phone number")

    try:
        start = datetime.strptime(data.start_date, "%Y-%m-%d").date()
        end = datetime.strptime(data.end_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(400, "start_date and end_date must be YYYY-MM-DD") from None
    if start > end:
        raise HTTPException(400, "start_date must be on or before end_date")

    tz_name = (data.schedule_timezone or settings.call_schedule_default_timezone).strip()

    item.phone = phone
    item.times = ",".join(data.times)
    item.message = data.message
    item.audio_url = data.audio_url
    item.call_type = data.call_type
    item.start_date = data.start_date
    item.end_date = data.end_date
    item.schedule_timezone = tz_name

    await db.commit()
    load_jobs()
    return {"msg": "Schedule updated successfully"}


@router.delete("/schedule/{idx}")
async def delete_schedule(
    idx: int,
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(CallSchedule).where((CallSchedule.id == idx) & (CallSchedule.user_id == current_user.id))
    )
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(404, "Not found")

    await db.delete(item)
    await db.flush()
    load_jobs()
    return {"msg": "Removed"}
