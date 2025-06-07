"""
Integration tests for SSE campaign triggers.

Tests that SSE events are properly broadcast when campaign, attack, and task
operations occur through the service layer.
"""

from datetime import UTC, timedelta
from unittest.mock import patch

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.agent_service import submit_task_status_service
from app.core.services.attack_service import (
    bulk_delete_attacks_service,
    create_attack_service,
    delete_attack_service,
    duplicate_attack_service,
    move_attack_service,
    update_attack_service,
)
from app.core.services.campaign_service import (
    archive_campaign_service,
    create_campaign_service,
    delete_campaign_service,
    relaunch_campaign_service,
    reorder_attacks_service,
    start_campaign_service,
    stop_campaign_service,
    update_campaign_service,
)
from app.models.attack import AttackMode
from app.models.task import TaskStatus
from app.schemas.attack import AttackCreate, AttackMoveDirection, AttackUpdate
from app.schemas.campaign import CampaignCreate, CampaignUpdate
from app.schemas.task import DeviceStatus, HashcatGuess, TaskStatusUpdate
from tests.factories.agent_factory import AgentFactory
from tests.factories.attack_factory import AttackFactory
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.task_factory import TaskFactory


@pytest.mark.asyncio
async def test_campaign_create_triggers_sse_event(
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that creating a campaign triggers an SSE event."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)

    with patch(
        "app.core.services.campaign_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        campaign_data = CampaignCreate(
            name="Test Campaign",
            description="Test Description",
            project_id=project.id,
            hash_list_id=hash_list.id,
        )

        campaign = await create_campaign_service(campaign_data, db_session)

        # Verify SSE event was triggered
        mock_broadcast.assert_called_once_with(campaign.id, campaign.project_id)


@pytest.mark.asyncio
async def test_campaign_update_triggers_sse_event(
    db_session: AsyncSession,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that updating a campaign triggers an SSE event."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )

    with patch(
        "app.core.services.campaign_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        update_data = CampaignUpdate(name="Updated Campaign Name")
        await update_campaign_service(campaign.id, update_data, db_session)

        # Verify SSE event was triggered
        mock_broadcast.assert_called_once_with(campaign.id, campaign.project_id)


@pytest.mark.asyncio
async def test_campaign_delete_triggers_sse_event(
    db_session: AsyncSession,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that deleting a campaign triggers an SSE event."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )

    with patch(
        "app.core.services.campaign_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        await delete_campaign_service(campaign.id, db_session)

        # Verify SSE event was triggered with campaign ID and project ID
        mock_broadcast.assert_called_once_with(campaign.id, project.id)


@pytest.mark.asyncio
async def test_campaign_start_triggers_sse_event(
    db_session: AsyncSession,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that starting a campaign triggers an SSE event."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )

    with patch(
        "app.core.services.campaign_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        await start_campaign_service(campaign.id, db_session)

        # Verify SSE event was triggered
        mock_broadcast.assert_called_once_with(campaign.id, campaign.project_id)


@pytest.mark.asyncio
async def test_campaign_stop_triggers_sse_event(
    db_session: AsyncSession,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that stopping a campaign triggers an SSE event."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    # Create campaign in ACTIVE state so it can be stopped
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id, state="active"
    )

    with patch(
        "app.core.services.campaign_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        await stop_campaign_service(campaign.id, db_session)

        # Verify SSE event was triggered
        mock_broadcast.assert_called_once_with(campaign.id, campaign.project_id)


@pytest.mark.asyncio
async def test_campaign_archive_triggers_sse_event(
    db_session: AsyncSession,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that archiving a campaign triggers an SSE event."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )

    with patch(
        "app.core.services.campaign_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        await archive_campaign_service(campaign.id, db_session)

        # Verify SSE event was triggered
        mock_broadcast.assert_called_once_with(campaign.id, campaign.project_id)


@pytest.mark.asyncio
async def test_campaign_relaunch_triggers_sse_event(
    db_session: AsyncSession,
    campaign_factory: CampaignFactory,
    attack_factory: AttackFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that relaunching a campaign triggers an SSE event."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    # Add a failed attack to the campaign so relaunch can work
    await attack_factory.create_async(
        campaign_id=campaign.id, hash_list_id=hash_list.id, state="failed"
    )

    with patch(
        "app.core.services.campaign_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        await relaunch_campaign_service(campaign.id, db_session)

        # Verify SSE event was triggered
        mock_broadcast.assert_called_once_with(campaign.id, campaign.project_id)


@pytest.mark.asyncio
async def test_reorder_attacks_triggers_sse_event(
    db_session: AsyncSession,
    campaign_factory: CampaignFactory,
    attack_factory: AttackFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that reordering attacks triggers an SSE event."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack1 = await attack_factory.create_async(
        campaign_id=campaign.id, hash_list_id=hash_list.id, position=0
    )
    attack2 = await attack_factory.create_async(
        campaign_id=campaign.id, hash_list_id=hash_list.id, position=1
    )

    with patch(
        "app.core.services.campaign_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        # Reorder attacks
        await reorder_attacks_service(campaign.id, [attack2.id, attack1.id], db_session)

        # Verify SSE event was triggered
        mock_broadcast.assert_called_once_with(campaign.id, campaign.project_id)


@pytest.mark.asyncio
async def test_attack_create_triggers_sse_event(
    db_session: AsyncSession,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that creating an attack triggers an SSE event."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )

    with patch(
        "app.core.services.attack_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        attack_data = AttackCreate(
            name="Test Attack",
            attack_mode=AttackMode.DICTIONARY,
            campaign_id=campaign.id,
            hash_list_id=hash_list.id,
            hash_list_url="http://example.com/wordlist.txt",
            hash_list_checksum="abc123",
        )

        attack = await create_attack_service(attack_data, db_session)

        # Verify SSE event was triggered
        mock_broadcast.assert_called_once_with(attack.campaign_id, None)


@pytest.mark.asyncio
async def test_attack_update_triggers_sse_event(
    db_session: AsyncSession,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that updating an attack triggers an SSE event."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack = await attack_factory.create_async(
        campaign_id=campaign.id, hash_list_id=hash_list.id
    )

    with patch(
        "app.core.services.attack_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        update_data = AttackUpdate(name="Updated Attack Name")
        await update_attack_service(attack.id, update_data, db_session)

        # Verify SSE event was triggered
        mock_broadcast.assert_called_once_with(attack.campaign_id, None)


@pytest.mark.asyncio
async def test_attack_delete_triggers_sse_event(
    db_session: AsyncSession,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that deleting an attack triggers an SSE event."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack = await attack_factory.create_async(
        campaign_id=campaign.id, hash_list_id=hash_list.id
    )

    with patch(
        "app.core.services.attack_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        await delete_attack_service(attack.id, db_session)

        # Verify SSE event was triggered
        mock_broadcast.assert_called_once_with(campaign.id, None)


@pytest.mark.asyncio
async def test_attack_move_triggers_sse_event(
    db_session: AsyncSession,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that moving an attack triggers an SSE event."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack1 = await attack_factory.create_async(
        campaign_id=campaign.id, hash_list_id=hash_list.id, position=0
    )
    await attack_factory.create_async(
        campaign_id=campaign.id, hash_list_id=hash_list.id, position=1
    )

    with patch(
        "app.core.services.attack_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        await move_attack_service(attack1.id, AttackMoveDirection.DOWN, db_session)

        # Verify SSE event was triggered
        mock_broadcast.assert_called_once()


@pytest.mark.asyncio
async def test_attack_duplicate_triggers_sse_event(
    db_session: AsyncSession,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that duplicating an attack triggers an SSE event."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack = await attack_factory.create_async(
        campaign_id=campaign.id, hash_list_id=hash_list.id
    )

    with patch(
        "app.core.services.attack_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        await duplicate_attack_service(attack.id, db_session)

        # Verify SSE event was triggered
        mock_broadcast.assert_called_once_with(attack.campaign_id, None)


@pytest.mark.asyncio
async def test_attack_bulk_delete_triggers_sse_event(
    db_session: AsyncSession,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that bulk deleting attacks triggers SSE events."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack1 = await attack_factory.create_async(
        campaign_id=campaign.id, hash_list_id=hash_list.id
    )
    attack2 = await attack_factory.create_async(
        campaign_id=campaign.id, hash_list_id=hash_list.id
    )

    with patch(
        "app.core.services.attack_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        await bulk_delete_attacks_service([attack1.id, attack2.id], db_session)

        # Verify SSE event was triggered for the campaign
        mock_broadcast.assert_called_with(campaign.id, None)


@pytest.mark.asyncio
async def test_task_status_update_triggers_sse_event(
    db_session: AsyncSession,
    task_factory: TaskFactory,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    agent_factory: AgentFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that task status updates trigger SSE events."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack = await attack_factory.create_async(
        campaign_id=campaign.id, hash_list_id=hash_list.id
    )
    # Create agent with proper token
    agent_token = f"csa_{12345}_test_token"
    agent = await agent_factory.create_async(token=agent_token)
    task = await task_factory.create_async(
        attack_id=attack.id, agent_id=agent.id, status=TaskStatus.RUNNING
    )

    with patch(
        "app.api.v1.endpoints.web.live.broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        # Create task status update
        from datetime import datetime

        status_update = TaskStatusUpdate(
            original_line="STATUS\t1\t2\t3\t4\t5\t6\t7\t8\t9\t10\t11\t12\t13\t14",
            time=datetime.now(UTC),
            session="test_session",
            hashcat_guess=HashcatGuess(
                guess_base="?a?a?a?a",
                guess_base_count=1000,
                guess_base_offset=0,
                guess_base_percentage=50.0,
                guess_mod="wordlist.txt",
                guess_mod_count=500,
                guess_mod_offset=0,
                guess_mod_percentage=25.0,
                guess_mode=0,
            ),
            status=2,
            target="test_target",
            progress=[50, 100],
            restore_point=0,
            recovered_hashes=[1, 2],
            recovered_salts=[0, 1],
            rejected=0,
            device_statuses=[
                DeviceStatus(
                    device_id=1,
                    device_name="Test GPU",
                    device_type="GPU",
                    speed=1000000,
                    utilization=85,
                    temperature=65,
                )
            ],
            time_start=datetime.now(UTC),
            estimated_stop=datetime.now(UTC) + timedelta(seconds=10),
        )

        await submit_task_status_service(
            task.id, status_update, db_session, f"Bearer {agent_token}"
        )

        # Verify SSE event was triggered
        mock_broadcast.assert_called_once_with(campaign.id, None)


@pytest.mark.asyncio
async def test_sse_trigger_graceful_import_failure(
    db_session: AsyncSession,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that SSE triggers handle import failures gracefully."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)

    # Mock the actual broadcast function to raise ImportError
    with patch(
        "app.api.v1.endpoints.web.live.broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.side_effect = ImportError("Broadcast not available")

        campaign_data = CampaignCreate(
            name="Test Campaign",
            description="Test Description",
            project_id=project.id,
            hash_list_id=hash_list.id,
        )

        # Should not raise an exception despite import error
        campaign = await create_campaign_service(campaign_data, db_session)
        assert campaign.id is not None

        # Verify the broadcast was attempted
        mock_broadcast.assert_called_once_with(campaign.id, campaign.project_id)


@pytest.mark.asyncio
async def test_sse_trigger_with_project_scoping(
    db_session: AsyncSession,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test that SSE triggers include project scoping information."""
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )

    with patch(
        "app.core.services.campaign_service._broadcast_campaign_update"
    ) as mock_broadcast:
        mock_broadcast.return_value = None

        update_data = CampaignUpdate(name="Updated Campaign Name")
        await update_campaign_service(campaign.id, update_data, db_session)

        # Verify SSE event was triggered with correct project scoping
        mock_broadcast.assert_called_once_with(campaign.id, project.id)
