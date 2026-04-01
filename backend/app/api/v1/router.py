from fastapi import APIRouter

from app.api.v1 import auth, dose_logs, medicines, users

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(medicines.router, prefix="/medicines", tags=["medicines"])
api_router.include_router(dose_logs.router, prefix="/dose-logs", tags=["dose-logs"])
