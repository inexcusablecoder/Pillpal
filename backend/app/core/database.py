from collections.abc import AsyncGenerator
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings


def _asyncpg_url_and_ssl(url: str) -> tuple[str, dict]:
    """
    asyncpg.connect() does not accept libpq query params like sslmode= or channel_binding=.
    Strip those and pass SSL via connect_args when required (e.g. Neon).
    """
    if not url.startswith(("postgresql://", "postgresql+asyncpg://")):
        return url, {}

    raw = url.replace("postgresql+asyncpg://", "postgresql://", 1)
    parsed = urlparse(raw)
    pairs = parse_qsl(parsed.query, keep_blank_values=True)
    connect_args: dict = {}
    want_ssl = False
    kept: list[tuple[str, str]] = []
    for k, v in pairs:
        kl = k.lower()
        if kl == "sslmode":
            want_ssl = v != "disable" and v != ""
            continue
        if kl == "channel_binding":
            continue
        kept.append((k, v))

    host = (parsed.hostname or "").lower()
    if "neon.tech" in host or "neon.build" in host:
        want_ssl = True

    if want_ssl:
        connect_args["ssl"] = True

    new_query = urlencode(kept)
    clean = urlunparse(parsed._replace(query=new_query))
    async_url = clean.replace("postgresql://", "postgresql+asyncpg://", 1)
    return async_url, connect_args


_async_url, _connect_args = _asyncpg_url_and_ssl(settings.database_url)

engine = create_async_engine(
    _async_url,
    echo=False,
    pool_pre_ping=True,
    connect_args=_connect_args,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
