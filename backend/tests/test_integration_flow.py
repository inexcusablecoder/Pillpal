"""Full API integration tests — require PostgreSQL (see @pytest.mark.integration)."""

import uuid

import pytest
from starlette.testclient import TestClient

pytestmark = pytest.mark.integration


def test_register_duplicate_email_returns_400(client: TestClient) -> None:
    email = f"dup_{uuid.uuid4().hex[:12]}@example.com"
    body = {"email": email, "password": "testpass123"}
    r1 = client.post("/api/v1/auth/register", json=body)
    assert r1.status_code == 201
    r2 = client.post("/api/v1/auth/register", json=body)
    assert r2.status_code == 400
    assert "already" in r2.json()["detail"].lower()


def test_login_wrong_password_returns_401(client: TestClient) -> None:
    email = f"login_{uuid.uuid4().hex[:12]}@example.com"
    client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "rightpass123"},
    )
    r = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "wrongpass999"},
    )
    assert r.status_code == 401


def test_me_without_token_returns_401(client: TestClient) -> None:
    r = client.get("/api/v1/users/me")
    assert r.status_code == 401


def test_me_and_patch_profile(client: TestClient, auth_headers: dict[str, str]) -> None:
    r = client.get("/api/v1/users/me", headers=auth_headers)
    assert r.status_code == 200
    data = r.json()
    assert "email" in data
    assert data["display_name"] == "Integration"
    r2 = client.patch(
        "/api/v1/users/me",
        headers=auth_headers,
        json={"display_name": "Updated Name"},
    )
    assert r2.status_code == 200
    assert r2.json()["display_name"] == "Updated Name"


def test_medicine_crud(client: TestClient, auth_headers: dict[str, str]) -> None:
    create_body = {
        "name": "Metformin",
        "dosage": "500mg",
        "scheduled_time": "08:30:00",
        "frequency": "daily",
        "active": True,
    }
    r = client.post(
        "/api/v1/medicines",
        headers=auth_headers,
        json=create_body,
    )
    assert r.status_code == 201, r.text
    med = r.json()
    mid = med["id"]
    assert med["name"] == "Metformin"

    r_list = client.get("/api/v1/medicines", headers=auth_headers)
    assert r_list.status_code == 200
    assert len(r_list.json()) >= 1

    r_patch = client.patch(
        f"/api/v1/medicines/{mid}",
        headers=auth_headers,
        json={"dosage": "850mg"},
    )
    assert r_patch.status_code == 200
    assert r_patch.json()["dosage"] == "850mg"

    r_del = client.delete(f"/api/v1/medicines/{mid}", headers=auth_headers)
    assert r_del.status_code == 204


def test_dose_sync_today_take_flow(client: TestClient, auth_headers: dict[str, str]) -> None:
    # Late time so apply_missed_logic (grace after scheduled) does not mark it missed during CI/local runs.
    client.post(
        "/api/v1/medicines",
        headers=auth_headers,
        json={
            "name": "Aspirin",
            "dosage": "75mg",
            "scheduled_time": "23:59:00",
            "frequency": "daily",
            "active": True,
        },
    )
    rs = client.post("/api/v1/dose-logs/sync", headers=auth_headers)
    assert rs.status_code == 200
    sync = rs.json()
    assert "today" in sync
    assert sync["dose_logs_created"] >= 1

    rt = client.get("/api/v1/dose-logs/today", headers=auth_headers)
    assert rt.status_code == 200
    today = rt.json()
    assert len(today) >= 1
    pending = next((d for d in today if d["status"] == "pending"), None)
    assert pending is not None
    log_id = pending["id"]

    rtake = client.post(
        f"/api/v1/dose-logs/{log_id}/take",
        headers=auth_headers,
    )
    assert rtake.status_code == 200
    assert rtake.json()["status"] == "taken"
    assert rtake.json()["taken_at"] is not None

    rt2 = client.get("/api/v1/dose-logs/today", headers=auth_headers)
    row = next(r for r in rt2.json() if r["id"] == log_id)
    assert row["status"] == "taken"


def test_dose_history_returns_200(client: TestClient, auth_headers: dict[str, str]) -> None:
    rh = client.get("/api/v1/dose-logs/history?days=7", headers=auth_headers)
    assert rh.status_code == 200
    assert isinstance(rh.json(), list)
