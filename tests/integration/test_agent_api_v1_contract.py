"""
Contract testing for Agent API v1 compliance.

This module validates that all Agent API v1 endpoints conform exactly to the
OpenAPI specification defined in contracts/v1_api_swagger.json.
"""

import json
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from jsonschema import ValidationError, validate

from app.main import app
from tests.factories.agent_factory import AgentFactory
from tests.factories.attack_factory import AttackFactory
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.task_factory import TaskFactory


@pytest.fixture(scope="module")
def v1_api_contract() -> dict[str, Any]:
    """Load the Agent API v1 OpenAPI contract specification."""
    contract_path = (
        Path(__file__).parent.parent.parent / "contracts" / "v1_api_swagger.json"
    )
    with open(contract_path) as f:
        return json.load(f)


@pytest.fixture
def client() -> TestClient:
    """Create a test client for the FastAPI application."""
    return TestClient(app)


@pytest.fixture
async def agent_with_token(db_session):
    """Create an agent with authentication token for testing."""
    # Set factory sessions
    AgentFactory.__async_session__ = db_session

    # Create test data
    agent = await AgentFactory.create_async()

    return agent


def validate_response_schema(
    response_data: dict[str, Any],
    contract: dict[str, Any],
    path: str,
    method: str,
    status_code: int,
) -> None:
    """Validate response data against the OpenAPI schema."""
    try:
        # Get the schema for this endpoint and status code
        endpoint_spec = contract["paths"][path][method.lower()]
        response_spec = endpoint_spec["responses"][str(status_code)]

        if (
            "content" in response_spec
            and "application/json" in response_spec["content"]
        ):
            schema = response_spec["content"]["application/json"]["schema"]

            # Resolve schema references
            if "$ref" in schema:
                ref_path = schema["$ref"].split("/")
                resolved_schema = contract
                for part in ref_path[1:]:  # Skip the first '#'
                    resolved_schema = resolved_schema[part]
                schema = resolved_schema

            # Validate the response data
            validate(instance=response_data, schema=schema)
    except KeyError as e:
        pytest.fail(f"Schema not found for {method} {path} {status_code}: {e}")
    except ValidationError as e:
        pytest.fail(f"Response validation failed for {method} {path}: {e}")


class TestAgentAPIv1Contract:
    """Test suite for Agent API v1 contract compliance."""

    @pytest.mark.asyncio
    async def test_get_agent_endpoint_contract(
        self, client: TestClient, agent_with_token, v1_api_contract: dict[str, Any]
    ):
        """Test GET /api/v1/client/agents/{id} endpoint contract compliance."""
        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        response = client.get(f"/api/v1/client/agents/{agent.id}", headers=headers)

        # Validate status code
        assert response.status_code == 200

        # Validate response schema
        response_data = response.json()
        validate_response_schema(
            response_data, v1_api_contract, "/api/v1/client/agents/{id}", "get", 200
        )

        # Validate required fields are present
        required_fields = [
            "id",
            "host_name",
            "client_signature",
            "operating_system",
            "devices",
            "state",
            "advanced_configuration",
        ]
        for field in required_fields:
            assert field in response_data, (
                f"Required field '{field}' missing from response"
            )

        # Validate field types and constraints
        assert isinstance(response_data["id"], int)
        assert isinstance(response_data["host_name"], str)
        assert isinstance(response_data["client_signature"], str)
        assert isinstance(response_data["operating_system"], str)
        assert isinstance(response_data["devices"], list)
        assert response_data["state"] in ["pending", "active", "stopped", "error"]
        assert isinstance(response_data["advanced_configuration"], dict)

    @pytest.mark.asyncio
    async def test_get_agent_unauthorized_contract(
        self, client: TestClient, v1_api_contract: dict[str, Any]
    ):
        """Test GET /api/v1/client/agents/{id} unauthorized response contract."""
        response = client.get("/api/v1/client/agents/1")

        # Validate status code
        assert response.status_code == 401

        # Validate response schema
        response_data = response.json()
        validate_response_schema(
            response_data, v1_api_contract, "/api/v1/client/agents/{id}", "get", 401
        )

        # Validate error object structure
        assert "error" in response_data
        assert isinstance(response_data["error"], str)

    @pytest.mark.asyncio
    async def test_agent_heartbeat_endpoint_contract(
        self, client: TestClient, agent_with_token, v1_api_contract: dict[str, Any]
    ):
        """Test POST /api/v1/client/agents/{id}/heartbeat endpoint contract compliance."""
        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        # Valid heartbeat payload
        heartbeat_data = {
            "status": "running",
            "current_task_id": None,
            "devices_status": {"GPU0": "active", "GPU1": "idle"},
        }

        response = client.post(
            f"/api/v1/client/agents/{agent.id}/heartbeat",
            json=heartbeat_data,
            headers=headers,
        )

        # Validate status code (should be 200 or 204 based on implementation)
        assert response.status_code in [200, 204]

        # If there's a response body, validate it
        if response.status_code == 200 and response.content:
            response_data = response.json()
            # Validate basic response structure
            assert isinstance(response_data, dict)

    @pytest.mark.asyncio
    async def test_submit_benchmark_endpoint_contract(
        self, client: TestClient, agent_with_token, v1_api_contract: dict[str, Any]
    ):
        """Test POST /api/v1/client/agents/{id}/submit_benchmark endpoint contract compliance."""
        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        # Valid benchmark payload
        benchmark_data = {
            "hash_type": 0,  # MD5
            "runtime": 1000,
            "hash_speed": 1000000.0,
            "device": 0,
        }

        response = client.post(
            f"/api/v1/client/agents/{agent.id}/submit_benchmark",
            json=benchmark_data,
            headers=headers,
        )

        # Validate status code
        assert response.status_code in [200, 201, 204]

    @pytest.mark.asyncio
    async def test_submit_error_endpoint_contract(
        self, client: TestClient, agent_with_token, v1_api_contract: dict[str, Any]
    ):
        """Test POST /api/v1/client/agents/{id}/submit_error endpoint contract compliance."""
        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        # Valid error payload
        error_data = {
            "message": "Test error message",
            "severity": "error",
            "attack_id": None,
        }

        response = client.post(
            f"/api/v1/client/agents/{agent.id}/submit_error",
            json=error_data,
            headers=headers,
        )

        # Validate status code
        assert response.status_code in [200, 201, 204]

    @pytest.mark.asyncio
    async def test_agent_shutdown_endpoint_contract(
        self, client: TestClient, agent_with_token, v1_api_contract: dict[str, Any]
    ):
        """Test POST /api/v1/client/agents/{id}/shutdown endpoint contract compliance."""
        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        response = client.post(
            f"/api/v1/client/agents/{agent.id}/shutdown", headers=headers
        )

        # Validate status code
        assert response.status_code in [200, 204]

    @pytest.mark.asyncio
    async def test_get_attack_endpoint_contract(
        self,
        client: TestClient,
        agent_with_token,
        v1_api_contract: dict[str, Any],
        db_session,
    ):
        """Test GET /api/v1/client/attacks/{id} endpoint contract compliance."""
        # Set factory sessions
        from tests.factories.hash_list_factory import HashListFactory

        ProjectFactory.__async_session__ = db_session
        HashListFactory.__async_session__ = db_session
        CampaignFactory.__async_session__ = db_session
        AttackFactory.__async_session__ = db_session

        # Create test attack
        project = await ProjectFactory.create_async()
        hash_list = await HashListFactory.create_async_with_hash_type(
            project_id=project.id
        )
        campaign = await CampaignFactory.create_async(
            project_id=project.id, hash_list_id=hash_list.id
        )
        attack = await AttackFactory.create_async(campaign_id=campaign.id)

        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        response = client.get(f"/api/v1/client/attacks/{attack.id}", headers=headers)

        # Validate status code
        assert response.status_code == 200

        # Validate response schema
        response_data = response.json()
        validate_response_schema(
            response_data, v1_api_contract, "/api/v1/client/attacks/{id}", "get", 200
        )

        # Validate required fields
        assert "id" in response_data
        assert "attack_mode" in response_data
        assert "attack_mode_hashcat" in response_data
        assert isinstance(response_data["id"], int)
        assert response_data["attack_mode"] in [
            "dictionary",
            "mask",
            "hybrid_dictionary",
            "hybrid_mask",
        ]
        assert isinstance(response_data["attack_mode_hashcat"], int)
        assert 0 <= response_data["attack_mode_hashcat"] <= 7

    @pytest.mark.asyncio
    async def test_get_attack_hash_list_endpoint_contract(
        self,
        client: TestClient,
        agent_with_token,
        v1_api_contract: dict[str, Any],
        db_session,
    ):
        """Test GET /api/v1/client/attacks/{id}/hash_list endpoint contract compliance."""
        # Set factory sessions
        from tests.factories.hash_list_factory import HashListFactory

        ProjectFactory.__async_session__ = db_session
        HashListFactory.__async_session__ = db_session
        CampaignFactory.__async_session__ = db_session
        AttackFactory.__async_session__ = db_session

        # Create test attack
        project = await ProjectFactory.create_async()
        hash_list = await HashListFactory.create_async_with_hash_type(
            project_id=project.id
        )
        campaign = await CampaignFactory.create_async(
            project_id=project.id, hash_list_id=hash_list.id
        )
        attack = await AttackFactory.create_async(campaign_id=campaign.id)

        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        response = client.get(
            f"/api/v1/client/attacks/{attack.id}/hash_list", headers=headers
        )

        # Validate status code
        assert response.status_code == 200

        # Response should be a list of hashes
        response_data = response.json()
        assert isinstance(response_data, list)

    @pytest.mark.asyncio
    async def test_check_cracker_update_endpoint_contract(
        self, client: TestClient, agent_with_token, v1_api_contract: dict[str, Any]
    ):
        """Test GET /api/v1/client/crackers/check_for_cracker_update endpoint contract compliance."""
        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        response = client.get(
            "/api/v1/client/crackers/check_for_cracker_update", headers=headers
        )

        # Validate status code
        assert response.status_code == 200

        # Validate response is JSON
        response_data = response.json()
        assert isinstance(response_data, dict)

    @pytest.mark.asyncio
    async def test_request_new_task_endpoint_contract(
        self, client: TestClient, agent_with_token, v1_api_contract: dict[str, Any]
    ):
        """Test GET /api/v1/client/tasks/new endpoint contract compliance."""
        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        response = client.get("/api/v1/client/tasks/new", headers=headers)

        # Should return 200 with task or 404 if no tasks available
        assert response.status_code in [200, 404]

        if response.status_code == 200:
            response_data = response.json()
            # Validate task structure
            assert "id" in response_data
            assert isinstance(response_data["id"], int)

    @pytest.mark.asyncio
    async def test_get_task_endpoint_contract(
        self,
        client: TestClient,
        agent_with_token,
        v1_api_contract: dict[str, Any],
        db_session,
    ):
        """Test GET /api/v1/client/tasks/{id} endpoint contract compliance."""
        # Set factory sessions
        from tests.factories.hash_list_factory import HashListFactory

        ProjectFactory.__async_session__ = db_session
        HashListFactory.__async_session__ = db_session
        CampaignFactory.__async_session__ = db_session
        AttackFactory.__async_session__ = db_session
        TaskFactory.__async_session__ = db_session

        # Create test task
        project = await ProjectFactory.create_async()
        hash_list = await HashListFactory.create_async_with_hash_type(
            project_id=project.id
        )
        campaign = await CampaignFactory.create_async(
            project_id=project.id, hash_list_id=hash_list.id
        )
        attack = await AttackFactory.create_async(campaign_id=campaign.id)
        task = await TaskFactory.create_async(
            attack_id=attack.id, agent_id=agent_with_token.id
        )

        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        response = client.get(f"/api/v1/client/tasks/{task.id}", headers=headers)

        # Validate status code
        assert response.status_code == 200

        # Validate response structure
        response_data = response.json()
        assert "id" in response_data
        assert isinstance(response_data["id"], int)

    @pytest.mark.asyncio
    async def test_submit_crack_endpoint_contract(
        self,
        client: TestClient,
        agent_with_token,
        v1_api_contract: dict[str, Any],
        db_session,
    ):
        """Test POST /api/v1/client/tasks/{id}/submit_crack endpoint contract compliance."""
        # Set factory sessions
        from tests.factories.hash_list_factory import HashListFactory

        ProjectFactory.__async_session__ = db_session
        HashListFactory.__async_session__ = db_session
        CampaignFactory.__async_session__ = db_session
        AttackFactory.__async_session__ = db_session
        TaskFactory.__async_session__ = db_session

        # Create test task
        project = await ProjectFactory.create_async()
        hash_list = await HashListFactory.create_async_with_hash_type(
            project_id=project.id
        )
        campaign = await CampaignFactory.create_async(
            project_id=project.id, hash_list_id=hash_list.id
        )
        attack = await AttackFactory.create_async(campaign_id=campaign.id)
        task = await TaskFactory.create_async(
            attack_id=attack.id, agent_id=agent_with_token.id
        )

        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        # Valid crack submission
        crack_data = {
            "hash": "5d41402abc4b2a76b9719d911017c592",  # MD5 of "hello"
            "plain_text": "hello",
        }

        response = client.post(
            f"/api/v1/client/tasks/{task.id}/submit_crack",
            json=crack_data,
            headers=headers,
        )

        # Validate status code
        assert response.status_code in [200, 201, 204]

    @pytest.mark.asyncio
    async def test_submit_status_endpoint_contract(
        self,
        client: TestClient,
        agent_with_token,
        v1_api_contract: dict[str, Any],
        db_session,
    ):
        """Test POST /api/v1/client/tasks/{id}/submit_status endpoint contract compliance."""
        # Set factory sessions
        CampaignFactory.__async_session__ = db_session
        AttackFactory.__async_session__ = db_session
        TaskFactory.__async_session__ = db_session

        # Create test task
        project = await ProjectFactory.create_async()
        campaign = await CampaignFactory.create_async(project_id=project.id)
        attack = await AttackFactory.create_async(campaign_id=campaign.id)
        task = await TaskFactory.create_async(
            attack_id=attack.id, agent_id=agent_with_token.id
        )

        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        # Valid status submission
        status_data = {
            "status": "running",
            "progress": 25.5,
            "estimated_completion": "2024-01-01T12:00:00Z",
        }

        response = client.post(
            f"/api/v1/client/tasks/{task.id}/submit_status",
            json=status_data,
            headers=headers,
        )

        # Validate status code
        assert response.status_code in [200, 204]

    @pytest.mark.asyncio
    async def test_accept_task_endpoint_contract(
        self,
        client: TestClient,
        agent_with_token,
        v1_api_contract: dict[str, Any],
        db_session,
    ):
        """Test POST /api/v1/client/tasks/{id}/accept_task endpoint contract compliance."""
        # Set factory sessions
        CampaignFactory.__async_session__ = db_session
        AttackFactory.__async_session__ = db_session
        TaskFactory.__async_session__ = db_session

        # Create test task
        project = await ProjectFactory.create_async()
        campaign = await CampaignFactory.create_async(project_id=project.id)
        attack = await AttackFactory.create_async(campaign_id=campaign.id)
        task = await TaskFactory.create_async(
            attack_id=attack.id, agent_id=agent_with_token.id
        )

        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        response = client.post(
            f"/api/v1/client/tasks/{task.id}/accept_task", headers=headers
        )

        # Validate status code
        assert response.status_code in [200, 204]

    @pytest.mark.asyncio
    async def test_exhaust_task_endpoint_contract(
        self,
        client: TestClient,
        agent_with_token,
        v1_api_contract: dict[str, Any],
        db_session,
    ):
        """Test POST /api/v1/client/tasks/{id}/exhausted endpoint contract compliance."""
        # Set factory sessions
        CampaignFactory.__async_session__ = db_session
        AttackFactory.__async_session__ = db_session
        TaskFactory.__async_session__ = db_session

        # Create test task
        project = await ProjectFactory.create_async()
        campaign = await CampaignFactory.create_async(project_id=project.id)
        attack = await AttackFactory.create_async(campaign_id=campaign.id)
        task = await TaskFactory.create_async(
            attack_id=attack.id, agent_id=agent_with_token.id
        )

        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        response = client.post(
            f"/api/v1/client/tasks/{task.id}/exhausted", headers=headers
        )

        # Validate status code
        assert response.status_code in [200, 204]

    @pytest.mark.asyncio
    async def test_abandon_task_endpoint_contract(
        self,
        client: TestClient,
        agent_with_token,
        v1_api_contract: dict[str, Any],
        db_session,
    ):
        """Test POST /api/v1/client/tasks/{id}/abandon endpoint contract compliance."""
        # Set factory sessions
        CampaignFactory.__async_session__ = db_session
        AttackFactory.__async_session__ = db_session
        TaskFactory.__async_session__ = db_session

        # Create test task
        project = await ProjectFactory.create_async()
        campaign = await CampaignFactory.create_async(project_id=project.id)
        attack = await AttackFactory.create_async(campaign_id=campaign.id)
        task = await TaskFactory.create_async(
            attack_id=attack.id, agent_id=agent_with_token.id
        )

        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        response = client.post(
            f"/api/v1/client/tasks/{task.id}/abandon", headers=headers
        )

        # Validate status code
        assert response.status_code in [200, 204]

    @pytest.mark.asyncio
    async def test_get_task_zaps_endpoint_contract(
        self,
        client: TestClient,
        agent_with_token,
        v1_api_contract: dict[str, Any],
        db_session,
    ):
        """Test GET /api/v1/client/tasks/{id}/get_zaps endpoint contract compliance."""
        # Set factory sessions
        CampaignFactory.__async_session__ = db_session
        AttackFactory.__async_session__ = db_session
        TaskFactory.__async_session__ = db_session

        # Create test task
        project = await ProjectFactory.create_async()
        campaign = await CampaignFactory.create_async(project_id=project.id)
        attack = await AttackFactory.create_async(campaign_id=campaign.id)
        task = await TaskFactory.create_async(
            attack_id=attack.id, agent_id=agent_with_token.id
        )

        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        response = client.get(
            f"/api/v1/client/tasks/{task.id}/get_zaps", headers=headers
        )

        # Validate status code
        assert response.status_code == 200

        # Response should be a list
        response_data = response.json()
        assert isinstance(response_data, list)

    @pytest.mark.asyncio
    async def test_get_configuration_endpoint_contract(
        self, client: TestClient, agent_with_token, v1_api_contract: dict[str, Any]
    ):
        """Test GET /api/v1/client/configuration endpoint contract compliance."""
        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        response = client.get("/api/v1/client/configuration", headers=headers)

        # Validate status code
        assert response.status_code == 200

        # Validate response is JSON
        response_data = response.json()
        assert isinstance(response_data, dict)

    @pytest.mark.asyncio
    async def test_authenticate_endpoint_contract(
        self, client: TestClient, agent_with_token, v1_api_contract: dict[str, Any]
    ):
        """Test GET /api/v1/client/authenticate endpoint contract compliance."""
        agent = agent_with_token
        headers = {"Authorization": f"Bearer {agent.token}"}

        response = client.get("/api/v1/client/authenticate", headers=headers)

        # Validate status code
        assert response.status_code == 200

        # Validate response is JSON
        response_data = response.json()
        assert isinstance(response_data, dict)

    def test_error_response_format_compliance(
        self, client: TestClient, v1_api_contract: dict[str, Any]
    ):
        """Test that error responses follow the contract format."""
        # Test unauthorized access
        response = client.get("/api/v1/client/agents/1")

        assert response.status_code == 401
        response_data = response.json()

        # Validate error object structure
        assert "error" in response_data
        assert isinstance(response_data["error"], str)

        # Validate against schema
        validate_response_schema(
            response_data, v1_api_contract, "/api/v1/client/agents/{id}", "get", 401
        )
