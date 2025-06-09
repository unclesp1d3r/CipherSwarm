"""Test Control API error handling with RFC9457 Problem Details format."""

from typing import Never

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.control_exceptions import (
    CampaignNotFoundError,
    InsufficientPermissionsError,
    InvalidAttackConfigError,
    ProjectAccessDeniedError,
)
from app.core.control_rfc9457_middleware import ControlRFC9457Middleware


@pytest.fixture
def test_app() -> FastAPI:
    """Create a test FastAPI app with Control RFC9457 middleware."""
    app = FastAPI()

    # Add Control API RFC9457 middleware
    app.add_middleware(ControlRFC9457Middleware)

    # Add test routes that raise custom exceptions (using Control API paths)
    @app.get("/api/v1/control/test/campaign-not-found", response_model=None)
    async def test_campaign_not_found() -> Never:
        raise CampaignNotFoundError(detail="Campaign with ID 'test-123' not found")

    @app.get("/api/v1/control/test/insufficient-permissions", response_model=None)
    async def test_insufficient_permissions() -> Never:
        raise InsufficientPermissionsError(detail="User lacks required permissions")

    @app.get("/api/v1/control/test/invalid-attack-config", response_model=None)
    async def test_invalid_attack_config() -> Never:
        raise InvalidAttackConfigError(detail="Attack configuration is invalid")

    @app.get("/api/v1/control/test/project-access-denied", response_model=None)
    async def test_project_access_denied() -> Never:
        raise ProjectAccessDeniedError(detail="Access denied to project 'test-project'")

    return app


@pytest.fixture
def client(test_app: FastAPI) -> TestClient:
    """Create a test client."""
    return TestClient(test_app)


def test_campaign_not_found_error_format(client: TestClient) -> None:
    """Test that CampaignNotFoundError returns RFC9457 format."""
    response = client.get("/api/v1/control/test/campaign-not-found")

    assert response.status_code == 404
    assert response.headers["content-type"] == "application/problem+json"

    data = response.json()
    assert "type" in data
    assert "title" in data
    assert "status" in data
    assert "detail" in data
    assert "instance" in data

    assert data["title"] == "Campaign Not Found"
    assert data["status"] == 404
    assert data["detail"] == "Campaign with ID 'test-123' not found"
    assert data["instance"] == "/api/v1/control/test/campaign-not-found"


def test_insufficient_permissions_error_format(client: TestClient) -> None:
    """Test that InsufficientPermissionsError returns RFC9457 format."""
    response = client.get("/api/v1/control/test/insufficient-permissions")

    assert response.status_code == 403
    assert response.headers["content-type"] == "application/problem+json"

    data = response.json()
    assert data["title"] == "Insufficient Permissions"
    assert data["status"] == 403
    assert data["detail"] == "User lacks required permissions"


def test_invalid_attack_config_error_format(client: TestClient) -> None:
    """Test that InvalidAttackConfigError returns RFC9457 format."""
    response = client.get("/api/v1/control/test/invalid-attack-config")

    assert response.status_code == 400
    assert response.headers["content-type"] == "application/problem+json"

    data = response.json()
    assert data["title"] == "Invalid Attack Configuration"
    assert data["status"] == 400
    assert data["detail"] == "Attack configuration is invalid"


def test_project_access_denied_error_format(client: TestClient) -> None:
    """Test that ProjectAccessDeniedError returns RFC9457 format."""
    response = client.get("/api/v1/control/test/project-access-denied")

    assert response.status_code == 403
    assert response.headers["content-type"] == "application/problem+json"

    data = response.json()
    assert data["title"] == "Project Access Denied"
    assert data["status"] == 403
    assert data["detail"] == "Access denied to project 'test-project'"


def test_error_response_has_required_fields(client: TestClient) -> None:
    """Test that error responses contain all required RFC9457 fields."""
    response = client.get("/api/v1/control/test/campaign-not-found")

    data = response.json()

    # Required fields according to RFC9457
    required_fields = ["type", "title", "status", "detail", "instance"]

    for field in required_fields:
        assert field in data, f"Required field '{field}' missing from error response"

    # Verify field types
    assert isinstance(data["type"], str)
    assert isinstance(data["title"], str)
    assert isinstance(data["status"], int)
    assert isinstance(data["detail"], str)
    assert isinstance(data["instance"], str)


def test_error_type_format(client: TestClient) -> None:
    """Test that error type follows kebab-case convention."""
    response = client.get("/api/v1/control/test/campaign-not-found")

    data = response.json()
    error_type = data["type"]

    # Should be kebab-case format
    assert "-" in error_type
    assert error_type.islower()
    assert " " not in error_type
