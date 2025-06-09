"""
Tests for project access utilities in the Control API.
"""

from unittest.mock import AsyncMock, Mock, patch

import pytest
from fastapi import HTTPException

from app.core.control_access import (
    check_project_access,
    filter_query_by_project_access,
    get_user_accessible_projects,
    require_project_access,
)
from app.models.user import User


@pytest.mark.asyncio
async def test_superuser_access_all_projects() -> None:
    """Test that superusers have access to all projects."""
    # Mock user with superuser privileges and project associations
    user = Mock(spec=User)
    user.is_superuser = True
    user.id = 1
    user.project_associations = [
        Mock(project_id=1),
        Mock(project_id=2),
        Mock(project_id=3),
    ]

    # Get accessible projects (should use pre-loaded associations)
    result = get_user_accessible_projects(user)

    # Should return all associated project IDs
    assert result == [1, 2, 3]


@pytest.mark.asyncio
async def test_admin_user_access_all_projects() -> None:
    """Test that admin users have access to all projects."""
    # Mock user with admin role and project associations
    user = Mock(spec=User)
    user.is_superuser = False
    user.role = "admin"
    user.id = 1
    user.project_associations = [
        Mock(project_id=1),
        Mock(project_id=2),
        Mock(project_id=3),
    ]

    # Get accessible projects (should use pre-loaded associations)
    result = get_user_accessible_projects(user)

    # Should return all associated project IDs
    assert result == [1, 2, 3]


@pytest.mark.asyncio
async def test_regular_user_assigned_projects_only() -> None:
    """Test that regular users only have access to assigned projects."""
    # Mock regular user with specific project associations
    user = Mock(spec=User)
    user.is_superuser = False
    user.role = "user"
    user.id = 1
    user.project_associations = [
        Mock(project_id=2),
        Mock(project_id=3),
    ]

    # Get accessible projects (should use pre-loaded associations)
    result = get_user_accessible_projects(user)

    # Should only return assigned project IDs
    assert result == [2, 3]


@pytest.mark.asyncio
async def test_user_no_project_access() -> None:
    """Test user with no project assignments."""
    # Mock user with no project access
    user = Mock(spec=User)
    user.is_superuser = False
    user.role = "user"
    user.id = 1
    user.project_associations = []

    # Get accessible projects (should use pre-loaded associations)
    result = get_user_accessible_projects(user)

    # Should return empty list
    assert result == []


@pytest.mark.asyncio
async def test_check_project_access() -> None:
    """Test check_project_access function."""
    user = Mock(spec=User)
    user.id = 1
    db = AsyncMock()

    with patch(
        "app.core.control_access.user_can_access_project_by_id", return_value=True
    ):
        result = await check_project_access(user, 123, db)
        assert result is True


@pytest.mark.asyncio
async def test_require_project_access_success() -> None:
    """Test require_project_access succeeds when user has access."""
    user = Mock(spec=User)
    user.id = 1
    db = AsyncMock()

    with patch(
        "app.core.control_access.user_can_access_project_by_id", return_value=True
    ):
        # Should not raise an exception
        await require_project_access(user, 123, db)


@pytest.mark.asyncio
async def test_require_project_access_denied() -> None:
    """Test require_project_access raises HTTPException when user lacks access."""
    user = Mock(spec=User)
    user.id = 1
    db = AsyncMock()

    with patch(
        "app.core.control_access.user_can_access_project_by_id", return_value=False
    ):
        with pytest.raises(HTTPException) as exc_info:
            await require_project_access(user, 123, db)

        assert exc_info.value.status_code == 403
        assert "does not have access to project 123" in str(exc_info.value.detail)


@pytest.mark.asyncio
async def test_require_project_access_no_projects() -> None:
    """Test require_project_access raises HTTPException when user has no project access."""
    user = Mock(spec=User)
    user.id = 1
    user.project_associations = []

    with pytest.raises(HTTPException) as exc_info:
        await require_project_access(user)

    assert exc_info.value.status_code == 403
    assert "no project access" in str(exc_info.value.detail)


@pytest.mark.asyncio
async def test_filter_query_by_project_access() -> None:
    """Test filter_query_by_project_access function."""
    # Mock user with project associations
    user = Mock(spec=User)
    user.project_associations = [
        Mock(project_id=1),
        Mock(project_id=2),
    ]

    # Mock query and column
    query = Mock()
    project_id_column = Mock()

    # Mock the where method to return a new query
    filtered_query = Mock()
    query.where.return_value = filtered_query

    result = filter_query_by_project_access(query, user, project_id_column)

    # Should call where with the column in the accessible projects
    query.where.assert_called_once()
    assert result == filtered_query
