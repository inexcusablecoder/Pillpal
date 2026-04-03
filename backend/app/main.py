import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.exception_handlers import http_exception_handler
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.responses import Response
from sqlalchemy import text

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.database import engine
from app.services.twilio_calls import startup_twilio_service

logger = logging.getLogger("pillpal")


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    )
    logger.info("Starting PillPal API (environment=%s)", settings.environment)
    logger.info("Starting Twilio Call Scheduler")
    startup_twilio_service()
    yield
    logger.info("Shutting down — disposing DB engine pool")
    await engine.dispose()


def create_app() -> FastAPI:
    docs_url = "/docs" if settings.environment != "production" else None
    redoc_url = "/redoc" if settings.environment != "production" else None

    application = FastAPI(
        title="PillPal API",
        version="1.0.0",
        description="Medicine reminders and intake history — REST API for the PillPal mobile app.",
        lifespan=lifespan,
        docs_url=docs_url,
        redoc_url=redoc_url,
    )

    origins = settings.cors_origin_list()
    allow_credentials = origins != ["*"]

    application.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=allow_credentials,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @application.exception_handler(RequestValidationError)
    async def validation_exception_handler(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        return JSONResponse(
            status_code=422,
            content={
                "detail": "Validation error",
                "errors": exc.errors(),
            },
        )

    @application.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        if isinstance(exc, HTTPException):
            return await http_exception_handler(request, exc)
        logger.exception("Unhandled error: %s %s", request.method, request.url.path)
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"},
        )

    application.include_router(api_router, prefix=settings.api_v1_prefix)

    @application.get("/", tags=["root"], summary="API entry")
    async def root() -> dict[str, str | None]:
        """Avoids 404 when opening the server base URL in a browser."""
        return {
            "service": "PillPal API",
            "version": "1.0.0",
            "docs": "/docs" if settings.environment != "production" else None,
            "health": "/health",
            "api": settings.api_v1_prefix,
        }

    @application.get("/favicon.ico", include_in_schema=False)
    async def favicon() -> Response:
        """Browsers request this automatically; return empty response instead of 404."""
        return Response(status_code=204)

    @application.get("/health", tags=["health"])
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": "pillpal-api"}

    @application.get("/health/ready", tags=["health"])
    async def readiness() -> dict[str, str]:
        try:
            async with engine.connect() as conn:
                await conn.execute(text("SELECT 1"))
        except Exception:
            logger.exception("Database readiness check failed")
            raise HTTPException(status_code=503, detail="Database unavailable") from None
        return {"status": "ready", "database": "ok"}

    return application


app = create_app()
