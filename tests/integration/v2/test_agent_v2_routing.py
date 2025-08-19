"""
Integration tests for Agent API v2 routing and authentication.

Tests the routing setup, authentication dependencies, and error handling
for the Agent API v2 endpoints.
"""

import pytest
from fastapi import status
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.factories.agent_factory import AgentFactory


class TestAgentV2Routing:
    """Test Agent API v2 routing and basic functionality."""

    @pytest.mark.asyncio
    async def test_v2_endpoints_are_registered(self, async_client: AsyncClient) -> None:
        """Test that all v2 endpoints are properly registered."""
        # Test registration endpoint (no auth required)
        response = await async_client.post("/api/v2/client/agents/register")
        # Should get 422 (validation error) not 404 (not found)
        assert response.status_code != status.HTTP_404_NOT_FOUND

        # Test heartbeat endpoint (auth required)
        response = await async_client.post("/api/v2/client/agents/heartbeat")
        # Should get 401 (unauthorized) not 404 (not found)
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

        # Test attack configuration endpoint (auth required)
        response = await async_client.get("/api/v2/client/agents/attacks/1")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

        # Test task assignment endpoint (auth required)
        response = await async_client.get("/api/v2/client/agents/tasks/next")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

        # Test progress update endpoint (auth required)
        response = await async_client.post("/api/v2/client/agents/tasks/1/progress")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

        # Test result submission endpoint (auth required)
        response = await async_client.post("/api/v2/client/agents/tasks/1/results")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

        # Test resource URL endpoint (auth required)
        response = await async_client.get("/api/v2/client/agents/resources/1/url")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED


class TestAgentV2Authentication:
    """Test Agent API v2 authentication and error handling."""

    @pytest.mark.asyncio
    async def test_missing_authorization_header(
        self, async_client: AsyncClient
    ) -> None:
        """Test that missing authorization header returns 401."""
        response = await async_client.post("/api/v2/client/agents/heartbeat")

        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        data = response.json()
        assert "error" in data
        assert data["error"] == "authentication_failed"

    @pytest.mark.asyncio
    async def test_invalid_authorization_format(
        self, async_client: AsyncClient
    ) -> None:
        """Test that invalid authorization format returns 401."""
        headers = {"Authorization": "Invalid format"}
        response = await async_client.post(
            "/api/v2/client/agents/heartbeat", headers=headers
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        data = response.json()
        assert data["error"] == "authentication_failed"

    @pytest.mark.asyncio
    async def test_wrong_token_prefix(self, async_client: AsyncClient) -> None:
        """Test that wrong token prefix returns 401."""
        headers = {"Authorization": "Bearer abc_123_wrongprefix"}
        response = await async_client.post(
            "/api/v2/client/agents/heartbeat", headers=headers
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        data = response.json()
        assert data["error"] == "authentication_failed"

    @pytest.mark.asyncio
    async def test_invalid_agent_token(self, async_client: AsyncClient) -> None:
        """Test that invalid agent token returns 401."""
        headers = {"Authorization": "Bearer csa_999_invalidtoken"}
        response = await async_client.post(
            "/api/v2/client/agents/heartbeat", headers=headers
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        data = response.json()
        assert data["error"] == "authentication_failed"

    @pytest.mark.asyncio
    async def test_valid_token_format_with_existing_agent(
        self, async_client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """Test that valid token format with existing agent passes authentication."""
        # Create an agent with a v2-format token
        agent = await AgentFactory.create_async(
            token="csa_123_validtokenstring123456789"
        )

        headers = {"Authorization": f"Bearer {agent.token}"}
        response = await async_client.post(
            "/api/v2/client/agents/heartbeat", headers=headers
        )

        # Should not get 401 (authentication error)
        # Will get other errors since endpoints are not implemented yet
        assert response.status_code != status.HTTP_401_UNAUTHORIZED


class TestAgentV2ErrorHandling:
    """Test Agent API v2 error handling middleware."""

    @pytest.mark.asyncio
    async def test_error_response_format(self, async_client: AsyncClient) -> None:
        """Test that error responses follow the v2 API format."""
        response = await async_client.post("/api/v2/client/agents/heartbeat")

        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        data = response.json()

        # Check v2 error response format
        assert "error" in data
        assert "message" in data
        assert "details" in data
        assert "timestamp" in data

        assert isinstance(data["error"], str)
        assert isinstance(data["message"], str)
        # details can be None
        # timestamp can be None if not set

    @pytest.mark.asyncio
    async def test_v2_middleware_only_applies_to_v2_routes(
        self, async_client: AsyncClient
    ) -> None:
        """Test that v2 middleware only applies to v2 routes."""
        # Test v1 route - should not use v2 error format
        response = await async_client.get("/api/v1/client/authenticate")

        # v1 routes should not use v2 error format
        if response.status_code == status.HTTP_401_UNAUTHORIZED:
            data = response.json()
            # v1 format should be different from v2 format
            # v1 typically uses {"error": "message"} or {"detail": "message"}
            assert (
                "timestamp" not in data or data.get("error") != "authentication_failed"
            )


class TestAgentV2OpenAPIDocumentation:
    """Test that v2 API endpoints are properly documented."""

    @pytest.mark.asyncio
    async def test_openapi_includes_v2_endpoints(
        self, async_client: AsyncClient
    ) -> None:
        """Test that OpenAPI schema includes v2 endpoints."""
        response = await async_client.get("/openapi.json")
        assert response.status_code == status.HTTP_200_OK

        openapi_schema = response.json()
        paths = openapi_schema["paths"]

        # Check that v2 endpoints are included
        v2_endpoints = [
            "/api/v2/client/agents/register",
            "/api/v2/client/agents/heartbeat",
            "/api/v2/client/agents/attacks/{attack_id}",
            "/api/v2/client/agents/tasks/next",
            "/api/v2/client/agents/tasks/{task_id}/progress",
            "/api/v2/client/agents/tasks/{task_id}/results",
            "/api/v2/client/agents/resources/{resource_id}/url",
        ]

        for endpoint in v2_endpoints:
            assert endpoint in paths, f"Endpoint {endpoint} not found in OpenAPI schema"

    @pytest.mark.asyncio
    async def test_v2_endpoints_have_proper_tags(
        self, async_client: AsyncClient
    ) -> None:
        """Test that v2 endpoints have proper tags for documentation."""
        response = await async_client.get("/openapi.json")
        openapi_schema = response.json()
        paths = openapi_schema["paths"]

        # Check that v2 endpoints have appropriate tags
        v2_paths = {k: v for k, v in paths.items() if "/api/v2/" in k}

        for path, methods in v2_paths.items():
            for method, details in methods.items():
                tags = details.get("tags", [])
                # Should have at least one tag
                assert len(tags) > 0, f"{method.upper()} {path} has no tags"
                # Should include Agent API v2 tag
                assert "Agent API v2" in tags, (
                    f"{method.upper()} {path} missing Agent API v2 tag"
                )
