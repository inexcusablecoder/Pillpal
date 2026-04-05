"""Regression: v1 routers stay mounted on the FastAPI app (matches ApiClient + OpenAPI)."""

import pytest

from app.main import app


def _method_path_pairs():
    pairs: set[tuple[str, str]] = set()
    for route in app.routes:
        path = getattr(route, "path", None)
        methods = getattr(route, "methods", None)
        if not path or not methods:
            continue
        for m in methods:
            if m != "HEAD":
                pairs.add((m, path))
    return pairs


@pytest.fixture
def routes():
    return _method_path_pairs()


@pytest.mark.parametrize(
    "method,path",
    [
        ("POST", "/api/v1/auth/register"),
        ("POST", "/api/v1/auth/login"),
        ("POST", "/api/v1/auth/token"),
        ("GET", "/api/v1/users/me"),
        ("PATCH", "/api/v1/users/me"),
        ("GET", "/api/v1/medicines/catalog"),
        ("POST", "/api/v1/medicines/analyze-label-preview"),
        ("GET", "/api/v1/medicines"),
        ("POST", "/api/v1/medicines"),
        ("GET", "/api/v1/dose-logs/today"),
        ("GET", "/api/v1/dose-logs/history"),
        ("POST", "/api/v1/dose-logs/sync"),
        ("GET", "/api/v1/calls/reminder-status"),
        ("POST", "/api/v1/calls/test"),
        ("GET", "/api/v1/calls/schedules"),
        ("POST", "/api/v1/calls/schedule"),
        ("GET", "/api/v1/calls/history"),
        ("POST", "/api/v1/ai/chat"),
        ("GET", "/api/v1/translate/get-language"),
        ("POST", "/api/v1/translate/translate"),
        ("GET", "/health"),
        ("GET", "/health/ready"),
    ],
)
def test_expected_route_registered(routes, method, path):
    assert (method, path) in routes, f"missing {method} {path}"
