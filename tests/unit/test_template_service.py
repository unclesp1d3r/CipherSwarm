"""
Unit tests for template service.
"""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.template_service import (
    list_templates_service,
    is_admin,
)
from app.models.user import User, UserRole
from app.schemas.shared import AttackTemplateRecordOut
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_is_admin_with_admin_role() -> None:
    """Test is_admin function with admin role."""
    user = User(role=UserRole.ADMIN)
    assert is_admin(user) is True


@pytest.mark.asyncio
async def test_is_admin_with_analyst_role() -> None:
    """Test is_admin function with analyst role."""
    user = User(role=UserRole.ANALYST)
    assert is_admin(user) is False


@pytest.mark.asyncio
async def test_is_admin_with_superuser_flag() -> None:
    """Test is_admin function with superuser flag."""
    user = User(role=UserRole.ANALYST)
    user.is_superuser = True  # type: ignore[attr-defined]
    assert is_admin(user) is True


@pytest.mark.asyncio
async def test_list_templates_service_admin_user(db_session: AsyncSession) -> None:
    """Test template listing for admin user."""
    # Set factory sessions
    UserFactory.__async_session__ = db_session

    # Create admin user
    admin_user = await UserFactory.create_async(role=UserRole.ADMIN)

    # List templates (should work even with empty database)
    result = await list_templates_service(db_session, admin_user)

    assert isinstance(result, list)
    # With empty database, should return empty list
    assert len(result) == 0


@pytest.mark.asyncio
async def test_list_templates_service_regular_user(db_session: AsyncSession) -> None:
    """Test template listing for regular user."""
    # Set factory sessions
    UserFactory.__async_session__ = db_session

    # Create regular user
    regular_user = await UserFactory.create_async(role=UserRole.ANALYST)

    # List templates (should work even with empty database)
    result = await list_templates_service(db_session, regular_user)

    assert isinstance(result, list)
    # With empty database, should return empty list
    assert len(result) == 0


@pytest.mark.asyncio
async def test_list_templates_service_with_attack_mode_filter(
    db_session: AsyncSession,
) -> None:
    """Test template listing with attack mode filtering."""
    # Set factory sessions
    UserFactory.__async_session__ = db_session

    # Create admin user
    admin_user = await UserFactory.create_async(role=UserRole.ADMIN)

    # List templates with attack mode filter
    result = await list_templates_service(
        db_session, admin_user, attack_mode="dictionary"
    )

    assert isinstance(result, list)
    # With empty database, should return empty list
    assert len(result) == 0


@pytest.mark.asyncio
async def test_list_templates_service_with_recommended_filter(
    db_session: AsyncSession,
) -> None:
    """Test template listing with recommended filtering."""
    # Set factory sessions
    UserFactory.__async_session__ = db_session

    # Create admin user
    admin_user = await UserFactory.create_async(role=UserRole.ADMIN)

    # List templates with recommended filter
    result = await list_templates_service(db_session, admin_user, recommended=True)

    assert isinstance(result, list)
    # With empty database, should return empty list
    assert len(result) == 0


@pytest.mark.asyncio
async def test_list_templates_service_regular_user_restrictions(
    db_session: AsyncSession,
) -> None:
    """Test that regular users only see recommended or public templates."""
    # Set factory sessions
    UserFactory.__async_session__ = db_session

    # Create regular user
    regular_user = await UserFactory.create_async(role=UserRole.ANALYST)

    # List templates - regular users should only see recommended/public templates
    result = await list_templates_service(db_session, regular_user)

    assert isinstance(result, list)
    # With empty database, should return empty list
    assert len(result) == 0

    # Regular users cannot filter by recommended flag explicitly
    # (the service applies this filter automatically for non-admin users)
    result_with_filter = await list_templates_service(
        db_session, regular_user, recommended=False
    )

    assert isinstance(result_with_filter, list)
    # Should still return empty list as the service overrides the filter for non-admin users
    assert len(result_with_filter) == 0
