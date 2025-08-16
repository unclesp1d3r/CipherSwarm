"""
Integration tests for complete Agent API v1 workflows.

This module tests complete agent workflows to ensure the API behaves correctly
for realistic agent usage patterns and maintains contract compliance throughout.
"""

import pytest
from fastapi.testclient import TestClient

from app.main import app
from tests.factories.agent_factory import AgentFactory
from tests.factories.attack_factory import AttackFactory
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.task_factory import TaskFactory
from tests.utils.contract_validation import validate_agent_api_v1_response
from tests.utils.hash_type_utils import get_or_create_hash_type


@pytest.fixture
def client() -> TestClient:
    """Create a test client for the FastAPI application."""
    return TestClient(app)


class TestAgentAPIv1Workflows:
    """Test complete Agent API v1 workflows."""

    @pytest.mark.asyncio
    async def test_complete_agent_lifecycle_workflow(
        self, client: TestClient, db_session
    ):
        """Test a complete agent lifecycle from registration to shutdown."""
        # Set factory sessions
        ProjectFactory.__async_session__ = db_session
        AgentFactory.__async_session__ = db_session

        # Create test data
        project = await ProjectFactory.create_async()
        agent = await AgentFactory.create_async(project_id=project.id)
        headers = {"Authorization": f"Bearer {agent.token}"}

        # 1. Agent authenticates
        auth_response = client.get("/api/v1/client/authenticate", headers=headers)
        assert auth_response.status_code == 200
        validate_agent_api_v1_response(
            auth_response.json(), "/api/v1/client/authenticate", "get", 200
        )

        # 2. Agent gets its configuration
        config_response = client.get("/api/v1/client/configuration", headers=headers)
        assert config_response.status_code == 200
        validate_agent_api_v1_response(
            config_response.json(), "/api/v1/client/configuration", "get", 200
        )

        # 3. Agent gets its own details
        agent_response = client.get(
            f"/api/v1/client/agents/{agent.id}", headers=headers
        )
        assert agent_response.status_code == 200
        validate_agent_api_v1_response(
            agent_response.json(), "/api/v1/client/agents/{id}", "get", 200
        )

        # 4. Agent sends heartbeat
        heartbeat_data = {
            "status": "running",
            "current_task_id": None,
            "devices_status": {"GPU0": "active"},
        }
        heartbeat_response = client.post(
            f"/api/v1/client/agents/{agent.id}/heartbeat",
            json=heartbeat_data,
            headers=headers,
        )
        assert heartbeat_response.status_code in [200, 204]

        # 5. Agent submits benchmark
        benchmark_data = {
            "hash_type": 0,  # MD5
            "runtime": 1000,
            "hash_speed": 1000000.0,
            "device": 0,
        }
        benchmark_response = client.post(
            f"/api/v1/client/agents/{agent.id}/submit_benchmark",
            json=benchmark_data,
            headers=headers,
        )
        assert benchmark_response.status_code in [200, 201, 204]

        # 6. Agent shuts down
        shutdown_response = client.post(
            f"/api/v1/client/agents/{agent.id}/shutdown", headers=headers
        )
        assert shutdown_response.status_code in [200, 204]

    @pytest.mark.asyncio
    async def test_complete_task_execution_workflow(
        self, client: TestClient, db_session
    ):
        """Test a complete task execution workflow."""
        # Set factory sessions
        ProjectFactory.__async_session__ = db_session
        AgentFactory.__async_session__ = db_session
        CampaignFactory.__async_session__ = db_session
        AttackFactory.__async_session__ = db_session
        TaskFactory.__async_session__ = db_session
        HashListFactory.__async_session__ = db_session

        # Create test data
        project = await ProjectFactory.create_async()
        agent = await AgentFactory.create_async(project_id=project.id)

        # Create hash type and hash list
        hash_type = await get_or_create_hash_type(db_session, 0, "MD5")
        hash_list = await HashListFactory.create_async(
            project_id=project.id, hash_type_id=hash_type.id
        )

        campaign = await CampaignFactory.create_async(
            project_id=project.id, hash_list_id=hash_list.id
        )
        attack = await AttackFactory.create_async(campaign_id=campaign.id)
        task = await TaskFactory.create_async(
            attack_id=attack.id,
            agent_id=None,  # Unassigned initially
        )

        headers = {"Authorization": f"Bearer {agent.token}"}

        # 1. Agent requests a new task
        new_task_response = client.get("/api/v1/client/tasks/new", headers=headers)

        if new_task_response.status_code == 200:
            # Task was assigned
            task_data = new_task_response.json()
            task_id = task_data["id"]

            # 2. Agent gets task details
            task_details_response = client.get(
                f"/api/v1/client/tasks/{task_id}", headers=headers
            )
            assert task_details_response.status_code == 200

            # 3. Agent accepts the task
            accept_response = client.post(
                f"/api/v1/client/tasks/{task_id}/accept_task", headers=headers
            )
            assert accept_response.status_code in [200, 204]

            # 4. Agent gets attack details
            attack_id = task_data.get("attack_id") or attack.id
            attack_response = client.get(
                f"/api/v1/client/attacks/{attack_id}", headers=headers
            )
            assert attack_response.status_code == 200
            validate_agent_api_v1_response(
                attack_response.json(), "/api/v1/client/attacks/{id}", "get", 200
            )

            # 5. Agent gets hash list for the attack
            hash_list_response = client.get(
                f"/api/v1/client/attacks/{attack_id}/hash_list", headers=headers
            )
            assert hash_list_response.status_code == 200

            # 6. Agent submits status updates
            status_data = {
                "status": "running",
                "progress": 25.0,
                "estimated_completion": "2024-01-01T12:00:00Z",
            }
            status_response = client.post(
                f"/api/v1/client/tasks/{task_id}/submit_status",
                json=status_data,
                headers=headers,
            )
            assert status_response.status_code in [200, 204]

            # 7. Agent submits a crack result
            crack_data = {
                "hash": "5d41402abc4b2a76b9719d911017c592",  # MD5 of "hello"
                "plain_text": "hello",
            }
            crack_response = client.post(
                f"/api/v1/client/tasks/{task_id}/submit_crack",
                json=crack_data,
                headers=headers,
            )
            assert crack_response.status_code in [200, 201, 204]

            # 8. Agent exhausts the task
            exhaust_response = client.post(
                f"/api/v1/client/tasks/{task_id}/exhausted", headers=headers
            )
            assert exhaust_response.status_code in [200, 204]

        elif new_task_response.status_code == 404:
            # No tasks available - this is also valid
            assert "error" in new_task_response.json()

    @pytest.mark.asyncio
    async def test_error_reporting_workflow(self, client: TestClient, db_session):
        """Test agent error reporting workflow."""
        # Set factory sessions
        ProjectFactory.__async_session__ = db_session
        AgentFactory.__async_session__ = db_session
        CampaignFactory.__async_session__ = db_session
        AttackFactory.__async_session__ = db_session

        # Create test data
        project = await ProjectFactory.create_async()
        agent = await AgentFactory.create_async(project_id=project.id)
        campaign = await CampaignFactory.create_async(project_id=project.id)
        attack = await AttackFactory.create_async(campaign_id=campaign.id)

        headers = {"Authorization": f"Bearer {agent.token}"}

        # 1. Agent reports a general error
        general_error_data = {
            "message": "General agent error occurred",
            "severity": "error",
            "attack_id": None,
        }
        error_response = client.post(
            f"/api/v1/client/agents/{agent.id}/submit_error",
            json=general_error_data,
            headers=headers,
        )
        assert error_response.status_code in [200, 201, 204]

        # 2. Agent reports an attack-specific error
        attack_error_data = {
            "message": "Attack execution failed",
            "severity": "error",
            "attack_id": attack.id,
        }
        attack_error_response = client.post(
            f"/api/v1/client/agents/{agent.id}/submit_error",
            json=attack_error_data,
            headers=headers,
        )
        assert attack_error_response.status_code in [200, 201, 204]

        # 3. Agent reports a warning
        warning_data = {
            "message": "Performance degraded",
            "severity": "warning",
            "attack_id": None,
        }
        warning_response = client.post(
            f"/api/v1/client/agents/{agent.id}/submit_error",
            json=warning_data,
            headers=headers,
        )
        assert warning_response.status_code in [200, 201, 204]

    @pytest.mark.asyncio
    async def test_task_abandonment_workflow(self, client: TestClient, db_session):
        """Test task abandonment workflow."""
        # Set factory sessions
        ProjectFactory.__async_session__ = db_session
        AgentFactory.__async_session__ = db_session
        CampaignFactory.__async_session__ = db_session
        AttackFactory.__async_session__ = db_session
        TaskFactory.__async_session__ = db_session

        # Create test data
        project = await ProjectFactory.create_async()
        agent = await AgentFactory.create_async(project_id=project.id)
        campaign = await CampaignFactory.create_async(project_id=project.id)
        attack = await AttackFactory.create_async(campaign_id=campaign.id)
        task = await TaskFactory.create_async(attack_id=attack.id, agent_id=agent.id)

        headers = {"Authorization": f"Bearer {agent.token}"}

        # 1. Agent accepts the task
        accept_response = client.post(
            f"/api/v1/client/tasks/{task.id}/accept_task", headers=headers
        )
        assert accept_response.status_code in [200, 204]

        # 2. Agent starts working and reports progress
        status_data = {
            "status": "running",
            "progress": 10.0,
            "estimated_completion": "2024-01-01T12:00:00Z",
        }
        status_response = client.post(
            f"/api/v1/client/tasks/{task.id}/submit_status",
            json=status_data,
            headers=headers,
        )
        assert status_response.status_code in [200, 204]

        # 3. Agent encounters an issue and abandons the task
        abandon_response = client.post(
            f"/api/v1/client/tasks/{task.id}/abandon", headers=headers
        )
        assert abandon_response.status_code in [200, 204]

        # 4. Agent reports the error that caused abandonment
        error_data = {
            "message": "Task abandoned due to hardware failure",
            "severity": "error",
            "attack_id": attack.id,
        }
        error_response = client.post(
            f"/api/v1/client/agents/{agent.id}/submit_error",
            json=error_data,
            headers=headers,
        )
        assert error_response.status_code in [200, 201, 204]

    @pytest.mark.asyncio
    async def test_cracker_update_workflow(self, client: TestClient, db_session):
        """Test cracker update checking workflow."""
        # Set factory sessions
        ProjectFactory.__async_session__ = db_session
        AgentFactory.__async_session__ = db_session

        # Create test data
        project = await ProjectFactory.create_async()
        agent = await AgentFactory.create_async(project_id=project.id)
        headers = {"Authorization": f"Bearer {agent.token}"}

        # Agent checks for cracker updates
        update_response = client.get(
            "/api/v1/client/crackers/check_for_cracker_update", headers=headers
        )
        assert update_response.status_code == 200

        # Validate response structure
        update_data = update_response.json()
        assert isinstance(update_data, dict)

    @pytest.mark.asyncio
    async def test_task_zaps_workflow(self, client: TestClient, db_session):
        """Test task zaps retrieval workflow."""
        # Set factory sessions
        ProjectFactory.__async_session__ = db_session
        AgentFactory.__async_session__ = db_session
        CampaignFactory.__async_session__ = db_session
        AttackFactory.__async_session__ = db_session
        TaskFactory.__async_session__ = db_session

        # Create test data
        project = await ProjectFactory.create_async()
        agent = await AgentFactory.create_async(project_id=project.id)
        campaign = await CampaignFactory.create_async(project_id=project.id)
        attack = await AttackFactory.create_async(campaign_id=campaign.id)
        task = await TaskFactory.create_async(attack_id=attack.id, agent_id=agent.id)

        headers = {"Authorization": f"Bearer {agent.token}"}

        # Agent gets task zaps
        zaps_response = client.get(
            f"/api/v1/client/tasks/{task.id}/get_zaps", headers=headers
        )
        assert zaps_response.status_code == 200

        # Validate response is a list
        zaps_data = zaps_response.json()
        assert isinstance(zaps_data, list)

    def test_unauthorized_access_patterns(self, client: TestClient):
        """Test various unauthorized access patterns."""
        # Test without authorization header
        response = client.get("/api/v1/client/agents/1")
        assert response.status_code == 401
        validate_agent_api_v1_response(
            response.json(), "/api/v1/client/agents/{id}", "get", 401
        )

        # Test with invalid token
        headers = {"Authorization": "Bearer invalid_token"}
        response = client.get("/api/v1/client/agents/1", headers=headers)
        assert response.status_code == 401
        validate_agent_api_v1_response(
            response.json(), "/api/v1/client/agents/{id}", "get", 401
        )

        # Test with malformed authorization header
        headers = {"Authorization": "InvalidFormat"}
        response = client.get("/api/v1/client/agents/1", headers=headers)
        assert response.status_code == 401

    def test_not_found_patterns(self, client: TestClient, db_session):
        """Test not found response patterns."""
        # Create a valid agent for authentication
        ProjectFactory.__async_session__ = db_session
        AgentFactory.__async_session__ = db_session

        project = ProjectFactory.build()
        db_session.add(project)
        db_session.commit()

        agent = AgentFactory.build(project_id=project.id)
        db_session.add(agent)
        db_session.commit()

        headers = {"Authorization": f"Bearer {agent.token}"}

        # Test accessing non-existent resources
        response = client.get("/api/v1/client/agents/999999", headers=headers)
        assert response.status_code == 404

        response = client.get("/api/v1/client/attacks/999999", headers=headers)
        assert response.status_code == 404

        response = client.get("/api/v1/client/tasks/999999", headers=headers)
