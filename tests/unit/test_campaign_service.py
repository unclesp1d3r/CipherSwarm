"""
Unit tests for campaign service.
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.campaign_service import (
    create_campaign_service,
    get_campaign_service,
    list_campaigns_service,
    update_campaign_service,
    delete_campaign_service,
    get_campaign_metrics_service,
    get_campaign_progress_service,
    start_campaign_service,
    stop_campaign_service,
    archive_campaign_service,
    relaunch_campaign_service,
    export_campaign_template_service,
    get_campaign_with_attack_summaries_service,
    raise_campaign_priority_service,
    reorder_attacks_service,
    add_attack_to_campaign_service,
)
from app.models.campaign import Campaign, CampaignState
from app.schemas.campaign import (
    CampaignCreate,
    CampaignUpdate,
)
from app.schemas.attack import AttackCreate, AttackMode
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.user_factory import UserFactory
from tests.utils.hash_type_utils import get_or_create_hash_type


@pytest.mark.asyncio
async def test_create_campaign_service_success(db_session: AsyncSession) -> None:
    """Test successful campaign creation."""
    # Set factory sessions
    ProjectFactory.__async_session__ = db_session
    HashListFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 0, "MD5")
    hash_list = await HashListFactory.create_async(
        project_id=project.id,
        hash_type_id=hash_type.id,
    )

    # Create campaign data
    campaign_data = CampaignCreate(
        name="Test Campaign",
        description="A test campaign",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )

    # Create campaign
    result = await create_campaign_service(campaign_data, db_session)

    assert result.name == "Test Campaign"
    assert result.description == "A test campaign"
    assert result.project_id == project.id
    assert result.hash_list_id == hash_list.id


@pytest.mark.asyncio
async def test_get_campaign_service_success(db_session: AsyncSession) -> None:
    """Test successful campaign retrieval."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)

    # Get campaign
    result = await get_campaign_service(campaign.id, db_session)

    assert result.id == campaign.id
    assert result.name == campaign.name
    assert result.project_id == project.id


@pytest.mark.asyncio
async def test_list_campaigns_service_success(db_session: AsyncSession) -> None:
    """Test successful campaign listing."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()

    # Create test campaigns
    await CampaignFactory.create_async(
        name="Campaign 1",
        project_id=project.id,
        state=CampaignState.DRAFT,
    )
    await CampaignFactory.create_async(
        name="Campaign 2",
        project_id=project.id,
        state=CampaignState.ACTIVE,
    )

    # List campaigns
    result, total = await list_campaigns_service(db_session, project_id=project.id)

    assert len(result) == 2
    assert total == 2
    campaign_names = {campaign.name for campaign in result}
    assert campaign_names == {"Campaign 1", "Campaign 2"}


@pytest.mark.asyncio
async def test_list_campaigns_service_with_state_filter(
    db_session: AsyncSession,
) -> None:
    """Test campaign listing with state filtering."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()

    # Create test campaigns with different states
    await CampaignFactory.create_async(
        name="Active Campaign",
        project_id=project.id,
        state=CampaignState.ACTIVE,
    )
    await CampaignFactory.create_async(
        name="Draft Campaign",
        project_id=project.id,
        state=CampaignState.DRAFT,
    )

    # List only active campaigns
    result, total = await list_campaigns_service(
        db_session, project_id=project.id, state=CampaignState.ACTIVE
    )

    assert len(result) == 1
    assert total == 1
    assert result[0].name == "Active Campaign"
    assert result[0].state == CampaignState.ACTIVE


@pytest.mark.asyncio
@patch("app.core.services.campaign_service._broadcast_campaign_update")
async def test_update_campaign_service_success(
    mock_broadcast: AsyncMock,
    db_session: AsyncSession,
) -> None:
    """Test successful campaign update."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(
        name="Original Campaign",
        project_id=project.id,
    )

    # Update campaign
    update_data = CampaignUpdate(
        name="Updated Campaign",
        description="Updated description",
    )
    result = await update_campaign_service(campaign.id, update_data, db_session)

    assert result.id == campaign.id
    assert result.name == "Updated Campaign"
    assert result.description == "Updated description"


@pytest.mark.asyncio
@patch("app.core.services.campaign_service._broadcast_campaign_update")
async def test_delete_campaign_service_success(
    mock_broadcast: AsyncMock,
    db_session: AsyncSession,
) -> None:
    """Test successful campaign deletion."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(
        project_id=project.id,
        state=CampaignState.DRAFT,  # Only draft campaigns can be deleted
    )

    campaign_id = campaign.id

    # Delete campaign
    await delete_campaign_service(campaign_id, db_session)

    # Verify campaign was deleted (should raise exception when trying to get it)
    with pytest.raises(
        Exception
    ):  # Could be various exceptions depending on implementation
        await get_campaign_service(campaign_id, db_session)


@pytest.mark.asyncio
@patch("app.core.services.campaign_service._broadcast_campaign_update")
async def test_start_campaign_service_success(
    mock_broadcast: AsyncMock,
    db_session: AsyncSession,
) -> None:
    """Test successful campaign start."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(
        project_id=project.id,
        state=CampaignState.DRAFT,
    )

    # Start campaign
    result = await start_campaign_service(campaign.id, db_session)

    assert result.id == campaign.id
    assert result.state == CampaignState.ACTIVE


@pytest.mark.asyncio
@patch("app.core.services.campaign_service._broadcast_campaign_update")
async def test_stop_campaign_service_success(
    mock_broadcast: AsyncMock,
    db_session: AsyncSession,
) -> None:
    """Test successful campaign stop."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(
        project_id=project.id,
        state=CampaignState.ACTIVE,
    )

    # Stop campaign
    result = await stop_campaign_service(campaign.id, db_session)

    assert result.id == campaign.id
    assert result.state == CampaignState.DRAFT


@pytest.mark.asyncio
@patch("app.core.services.campaign_service._broadcast_campaign_update")
async def test_archive_campaign_service_success(
    mock_broadcast: AsyncMock,
    db_session: AsyncSession,
) -> None:
    """Test successful campaign archival."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(
        project_id=project.id,
        state=CampaignState.COMPLETED,
    )

    # Archive campaign
    result = await archive_campaign_service(campaign.id, db_session)

    assert result.id == campaign.id
    assert result.state == CampaignState.ARCHIVED


@pytest.mark.asyncio
async def test_get_campaign_metrics_service_success(
    db_session: AsyncSession,
) -> None:
    """Test successful campaign metrics retrieval."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(
        project_id=project.id,
        state=CampaignState.ACTIVE,
    )

    # Get campaign metrics
    result = await get_campaign_metrics_service(campaign.id, db_session)

    assert result.campaign_id == campaign.id
    assert result.total_attacks >= 0
    assert result.completed_attacks >= 0
    assert result.active_tasks >= 0
    assert result.total_hashes >= 0
    assert result.cracked_hashes >= 0


@pytest.mark.asyncio
async def test_get_campaign_progress_service_success(
    db_session: AsyncSession,
) -> None:
    """Test successful campaign progress retrieval."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(
        project_id=project.id,
        state=CampaignState.ACTIVE,
    )

    # Get campaign progress
    result = await get_campaign_progress_service(campaign.id, db_session)

    assert result.campaign_id == campaign.id
    assert result.progress_percentage >= 0.0
    assert result.progress_percentage <= 100.0


@pytest.mark.asyncio
async def test_get_campaign_with_attack_summaries_service_success(
    db_session: AsyncSession,
) -> None:
    """Test successful campaign with attack summaries retrieval."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)

    # Get campaign with attack summaries
    result = await get_campaign_with_attack_summaries_service(campaign.id, db_session)

    assert result.campaign.id == campaign.id
    assert isinstance(result.attack_summaries, list)


@pytest.mark.asyncio
async def test_raise_campaign_priority_service_success(
    db_session: AsyncSession,
) -> None:
    """Test successful campaign priority raising."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session
    UserFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    user = await UserFactory.create_async()
    campaign = await CampaignFactory.create_async(
        project_id=project.id,
        priority=5,
    )

    # Raise campaign priority
    result = await raise_campaign_priority_service(campaign.id, user, db_session)

    assert result.id == campaign.id
    # Priority should be increased (lower number = higher priority)
    assert result.priority < 5


@pytest.mark.asyncio
async def test_reorder_attacks_service_success(db_session: AsyncSession) -> None:
    """Test successful attack reordering."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)

    # Test with empty attack list (should work without errors)
    result = await reorder_attacks_service(campaign.id, [], db_session)

    assert isinstance(result, list)
    assert len(result) == 0


@pytest.mark.asyncio
async def test_add_attack_to_campaign_service_success(
    db_session: AsyncSession,
) -> None:
    """Test successful attack addition to campaign."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)

    # Create attack data
    attack_data = AttackCreate(
        name="New Attack",
        attack_mode=AttackMode.DICTIONARY,
        campaign_id=campaign.id,
        priority_order=1,
        increment_mode=False,
        increment_minimum=None,
        increment_maximum=None,
        optimized_kernel=True,
        slow_candidate_generators=False,
        skip_count=0,
        limit_count=None,
        rule_left=None,
        rule_right=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        mask=None,
        mask_increment=False,
        wordlist_id=None,
        rule_list_id=None,
        mask_list_id=None,
    )

    # Add attack to campaign
    result = await add_attack_to_campaign_service(campaign.id, attack_data, db_session)

    assert result.name == "New Attack"
    assert result.attack_mode == AttackMode.DICTIONARY
    assert result.campaign_id == campaign.id


@pytest.mark.asyncio
async def test_export_campaign_template_service_success(
    db_session: AsyncSession,
) -> None:
    """Test successful campaign template export."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)

    # Export campaign template
    result = await export_campaign_template_service(campaign.id, db_session)

    assert result.name == campaign.name
    assert result.description == campaign.description
    assert isinstance(result.attacks, list)


@pytest.mark.asyncio
async def test_relaunch_campaign_service_success(db_session: AsyncSession) -> None:
    """Test successful campaign relaunch."""
    # Set factory sessions
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(
        project_id=project.id,
        state=CampaignState.COMPLETED,
    )

    # Relaunch campaign
    result = await relaunch_campaign_service(campaign.id, db_session)

    assert result.campaign.id == campaign.id
    assert isinstance(result.attack_summaries, list)
