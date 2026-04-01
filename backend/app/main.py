from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.firebase import init_firebase
from app.api.v1.health import router as health_router
from app.api.v1.users import router as users_router
from app.api.v1.medicines import router as medicines_router
from app.api.v1.logs import router as logs_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_firebase()
    yield


app = FastAPI(
    title="PillPal API",
    description="FastAPI backend for PillPal — Firebase Auth + Firestore (Admin SDK).",
    version="1.0.0",
    lifespan=lifespan,
)

origins = [o.strip() for o in settings.cors_origins.split(",")] if settings.cors_origins != "*" else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router, prefix="/v1")
app.include_router(users_router, prefix="/v1")
app.include_router(medicines_router, prefix="/v1")
app.include_router(logs_router, prefix="/v1")


@app.get("/")
def root():
    return {"service": "pillpal-api", "docs": "/docs", "health": "/v1/health"}
