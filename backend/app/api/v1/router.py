from fastapi import APIRouter

from app.api.v1 import auth, dose_logs, medicines, users
from app.services.twilio_calls import router as twilio_router
from app.services.ai_chat import router as ai_chat_router

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(medicines.router, prefix="/medicines", tags=["medicines"])
api_router.include_router(dose_logs.router, prefix="/dose-logs", tags=["dose-logs"])
api_router.include_router(twilio_router, prefix="/calls", tags=["twilio-calls"])
api_router.include_router(ai_chat_router, prefix="/ai", tags=["ai-chat"])
