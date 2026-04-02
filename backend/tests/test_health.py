from starlette.testclient import TestClient


def test_health_ok(client: TestClient) -> None:
    r = client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "ok"
    assert data["service"] == "pillpal-api"


def test_readiness_returns_200_or_503(client: TestClient) -> None:
    r = client.get("/health/ready")
    assert r.status_code in (200, 503)
    body = r.json()
    assert "status" in body or "detail" in body


def test_root_not_404(client: TestClient) -> None:
    r = client.get("/")
    assert r.status_code == 200
    data = r.json()
    assert data["service"] == "PillPal API"
    assert data["api"] == "/api/v1"


def test_favicon_not_404(client: TestClient) -> None:
    r = client.get("/favicon.ico")
    assert r.status_code == 204
