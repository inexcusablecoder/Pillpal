import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_ok(client: AsyncClient) -> None:
    r = await client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "ok"
    assert data["service"] == "pillpal-api"


@pytest.mark.asyncio
async def test_readiness_returns_200_or_503(client: AsyncClient) -> None:
    r = await client.get("/health/ready")
    assert r.status_code in (200, 503)
    body = r.json()
    assert "status" in body
