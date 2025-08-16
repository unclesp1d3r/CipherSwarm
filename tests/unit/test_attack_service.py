"""
Unit tests for attack service.
"""

from unittest.mock import AsyncMock, patch

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.attack_service import (
    _safe_int,
    attack_to_template,
    bulk_delete_attacks_service,
    create_attack_service,
    delete_attack_service,
    duplicate_attack_service,
    estimate_attack_keyspace_and_complexity,
    get_attack_list_service,
    get_attack_performance_summary_service,
    get_attack_service,
    move_attack_service,
    update_attack_service,
)
from app.models.attack import Attack, AttackMode
from app.schemas.attack import (
    AttackCreate,
    AttackMoveDirection,
    AttackUpdate,
    EstimateAttackRequest,
)
from tests.factories.attack_factory import AttackFactory
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.project_factory import ProjectFactory


@pytest.mark.asyncio
async def test_create_attack_service_success(db_session: AsyncSession) -> None:
    """Test successful attack creation."""
    # Set factory sessions
    ProjectFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)

    # Create attack data
    attack_data = AttackCreate(
        name="Dictionary Attack",
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

    # Create attack
    result = await create_attack_service(attack_data, db_session)

    assert result.name == "Dictionary Attack"
    assert result.attack_mode == AttackMode.DICTIONARY
    assert result.campaign_id == campaign.id
    assert result.priority_order == 1


@pytest.mark.asyncio
async def test_get_attack_service_success(db_session: AsyncSession) -> None:
    """Test successful attack retrieval."""
    # Set factory sessions
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)
    attack = await AttackFactory.create_async(campaign_id=campaign.id)

    # Get attack
    result = await get_attack_service(attack.id, db_session)

    assert result.id == attack.id
    assert result.name == attack.name
    assert result.campaign_id == campaign.id


@pytest.mark.asyncio
async def test_get_attack_list_service_success(db_session: AsyncSession) -> None:
    """Test successful attack listing."""
    # Set factory sessions
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)

    # Create test attacks
    await AttackFactory.create_async(
        name="Attack 1",
        campaign_id=campaign.id,
        priority_order=1,
    )
    await AttackFactory.create_async(
        name="Attack 2",
        campaign_id=campaign.id,
        priority_order=2,
    )

    # List attacks
    result, total, pages = await get_attack_list_service(db_session, page=1, size=20)

    assert len(result) >= 2  # May have other attacks from other tests
    assert total >= 2
    assert pages >= 1


@pytest.mark.asyncio
@patch("app.core.services.attack_service._broadcast_campaign_update")
async def test_update_attack_service_success(
    mock_broadcast: AsyncMock,
    db_session: AsyncSession,
) -> None:
    """Test successful attack update."""
    # Set factory sessions
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)
    attack = await AttackFactory.create_async(
        name="Original Attack",
        campaign_id=campaign.id,
    )

    # Update attack
    update_data = AttackUpdate(
        name="Updated Attack",
        optimized_kernel=False,
    )
    result = await update_attack_service(attack.id, update_data, db_session)

    assert result.id == attack.id
    assert result.name == "Updated Attack"
    assert result.optimized_kernel is False


@pytest.mark.asyncio
@patch("app.core.services.attack_service._broadcast_campaign_update")
async def test_delete_attack_service_success(
    mock_broadcast: AsyncMock,
    db_session: AsyncSession,
) -> None:
    """Test successful attack deletion."""
    # Set factory sessions
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)
    attack = await AttackFactory.create_async(campaign_id=campaign.id)

    attack_id = attack.id

    # Delete attack
    result = await delete_attack_service(attack_id, db_session)

    assert result["success"] is True
    assert result["attack_id"] == attack_id


@pytest.mark.asyncio
async def test_estimate_attack_keyspace_and_complexity_dictionary() -> None:
    """Test attack keyspace estimation for dictionary attack."""
    # Create estimation request
    request_data = EstimateAttackRequest(
        attack_mode=AttackMode.DICTIONARY,
        wordlist_id=None,
        rule_list_id=None,
        mask_list_id=None,
        mask=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        increment_mode=False,
        increment_minimum=None,
        increment_maximum=None,
        # Add mock word count for estimation
        estimated_word_count=10000,
        estimated_rule_count=100,
    )

    # Estimate keyspace
    result = await estimate_attack_keyspace_and_complexity(request_data)

    assert result.estimated_keyspace > 0
    assert result.complexity_score >= 0
    assert result.estimated_runtime is not None


@pytest.mark.asyncio
async def test_estimate_attack_keyspace_and_complexity_mask() -> None:
    """Test attack keyspace estimation for mask attack."""
    # Create estimation request
    request_data = EstimateAttackRequest(
        attack_mode=AttackMode.MASK,
        wordlist_id=None,
        rule_list_id=None,
        mask_list_id=None,
        mask="?l?l?l?d?d",  # 3 lowercase + 2 digits
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        increment_mode=False,
        increment_minimum=None,
        increment_maximum=None,
    )

    # Estimate keyspace
    result = await estimate_attack_keyspace_and_complexity(request_data)

    # Expected: 26^3 * 10^2 = 1,757,600
    assert result.estimated_keyspace == 1757600
    assert result.complexity_score >= 0
    assert result.estimated_runtime is not None


@pytest.mark.asyncio
@patch("app.core.services.attack_service._broadcast_campaign_update")
async def test_move_attack_service_up(
    mock_broadcast: AsyncMock,
    db_session: AsyncSession,
) -> None:
    """Test moving attack up in priority order."""
    # Set factory sessions
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)

    # Create attacks with specific order
    attack1 = await AttackFactory.create_async(
        name="Attack 1",
        campaign_id=campaign.id,
        priority_order=1,
    )
    attack2 = await AttackFactory.create_async(
        name="Attack 2",
        campaign_id=campaign.id,
        priority_order=2,
    )

    # Move attack 2 up (should become priority 1)
    await move_attack_service(attack2.id, AttackMoveDirection.UP, db_session)

    # Verify order changed
    await db_session.refresh(attack1)
    await db_session.refresh(attack2)

    assert attack2.priority_order == 1
    assert attack1.priority_order == 2


@pytest.mark.asyncio
async def test_duplicate_attack_service_success(db_session: AsyncSession) -> None:
    """Test successful attack duplication."""
    # Set factory sessions
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)
    original_attack = await AttackFactory.create_async(
        name="Original Attack",
        campaign_id=campaign.id,
        priority_order=1,
    )

    # Duplicate attack
    result = await duplicate_attack_service(original_attack.id, db_session)

    assert result.name == "Original Attack (Copy)"
    assert result.campaign_id == campaign.id
    assert result.priority_order == 2  # Should be next in order
    assert result.id != original_attack.id


@pytest.mark.asyncio
async def test_bulk_delete_attacks_service_success(db_session: AsyncSession) -> None:
    """Test successful bulk attack deletion."""
    # Set factory sessions
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)

    # Create test attacks
    attack1 = await AttackFactory.create_async(campaign_id=campaign.id)
    attack2 = await AttackFactory.create_async(campaign_id=campaign.id)

    # Bulk delete attacks
    result = await bulk_delete_attacks_service([attack1.id, attack2.id], db_session)

    assert len(result["deleted"]) == 2
    assert attack1.id in result["deleted"]
    assert attack2.id in result["deleted"]
    assert len(result["failed"]) == 0


@pytest.mark.asyncio
async def test_get_attack_performance_summary_service_success(
    db_session: AsyncSession,
) -> None:
    """Test successful attack performance summary retrieval."""
    # Set factory sessions
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    campaign = await CampaignFactory.create_async(project_id=project.id)
    attack = await AttackFactory.create_async(campaign_id=campaign.id)

    # Get performance summary
    result = await get_attack_performance_summary_service(attack.id, db_session)

    assert result.attack_id == attack.id
    assert result.total_tasks >= 0
    assert result.completed_tasks >= 0
    assert result.active_tasks >= 0
    assert result.progress_percentage >= 0.0
    assert result.progress_percentage <= 100.0


def test_attack_to_template():
    """Test attack to template conversion."""
    # Create a mock attack
    attack = Attack(
        id=1,
        name="Test Attack",
        attack_mode=AttackMode.DICTIONARY,
        priority_order=1,
        optimized_kernel=True,
        slow_candidate_generators=False,
        skip_count=0,
        limit_count=None,
        increment_mode=False,
        increment_minimum=None,
        increment_maximum=None,
        rule_left=None,
        rule_right=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        mask=None,
        mask_increment=False,
    )

    # Convert to template
    template = attack_to_template(attack)

    assert template.name == "Test Attack"
    assert template.attack_mode == AttackMode.DICTIONARY
    assert template.optimized_kernel is True
    assert template.slow_candidate_generators is False


def test_safe_int():
    """Test _safe_int utility function."""
    assert _safe_int(42, 0) == 42
    assert _safe_int("42", 0) == 42
    assert _safe_int("invalid", 10) == 10
    assert _safe_int(None, 5) == 5
    assert _safe_int(3.14, 0) == 0  # Non-int, non-string
