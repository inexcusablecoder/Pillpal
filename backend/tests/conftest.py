import uuid

import pytest
from starlette.testclient import TestClient

from app.main import app


def postgres_available() -> bool:
    """True if DATABASE_URL points to a reachable PostgreSQL (integration tests)."""
    try:
        import psycopg2

        from app.core.config import settings

        url = settings.database_url
        if url.startswith("postgresql+asyncpg://"):
            url = url.replace("postgresql+asyncpg://", "postgresql://", 1)
        conn = psycopg2.connect(url)
        conn.close()
        return True
    except Exception:
        return False


def pytest_configure(config: pytest.Config) -> None:
    config.addinivalue_line(
        "markers",
        "integration: requires PostgreSQL (DATABASE_URL in backend/.env)",
    )


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    if postgres_available():
        return
    skip = pytest.mark.skip(reason="PostgreSQL not reachable — set DATABASE_URL in backend/.env")
    for item in items:
        if item.get_closest_marker("integration"):
            item.add_marker(skip)


@pytest.fixture(scope="session")
def client() -> TestClient:
    """Sync TestClient — runs the ASGI app on one event loop (works with async SQLAlchemy)."""
    with TestClient(app, raise_server_exceptions=True) as c:
        yield c


@pytest.fixture
def auth_headers(client: TestClient) -> dict[str, str]:
    """Register a throwaway user and return Authorization header dict."""
    email = f"t_{uuid.uuid4().hex[:16]}@example.com"
    password = "testpass123"
    r = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "display_name": "Integration"},
    )
    assert r.status_code == 201, r.text
    r2 = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert r2.status_code == 200, r2.text
    token = r2.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}
