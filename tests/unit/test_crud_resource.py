from datetime import UTC, datetime, timedelta, timezone

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.resource import resource


@pytest.mark.asyncio
async def test_generate_presigned_url_naive_datetime_raises_error(
    db_session: AsyncSession,
) -> None:
    """Test that naive datetime raises ValueError."""
    with pytest.raises(ValueError, match="expires_at must be timezone-aware"):
        await resource.generate_presigned_url(
            db=db_session,
            resource_id=1,
            expires_at=datetime.now(UTC).replace(tzinfo=None),
        )


@pytest.mark.asyncio
async def test_generate_presigned_url_past_expiry_raises_error(
    db_session: AsyncSession,
) -> None:
    """Test that past expiry datetime raises ValueError."""
    past_time = datetime.now(UTC) - timedelta(hours=1)
    with pytest.raises(ValueError, match="expires_at must be in the future"):
        await resource.generate_presigned_url(
            db=db_session, resource_id=1, expires_at=past_time
        )


@pytest.mark.asyncio
async def test_generate_presigned_url_current_time_raises_error(
    db_session: AsyncSession,
) -> None:
    """Test that current time raises ValueError."""
    current_time = datetime.now(UTC)
    with pytest.raises(ValueError, match="expires_at must be in the future"):
        await resource.generate_presigned_url(
            db=db_session, resource_id=1, expires_at=current_time
        )


@pytest.mark.asyncio
async def test_generate_presigned_url_resource_not_found_raises_error(
    db_session: AsyncSession,
) -> None:
    """Test that non-existent resource raises ValueError."""
    future_time = datetime.now(UTC) + timedelta(hours=1)
    with pytest.raises(ValueError, match="Resource 999 not found"):
        await resource.generate_presigned_url(
            db=db_session, resource_id=999, expires_at=future_time
        )


@pytest.mark.asyncio
async def test_generate_presigned_url_different_timezone_validation(
    db_session: AsyncSession,
) -> None:
    """Test that different timezone datetime is accepted for validation."""
    # Use a different timezone (UTC+5)
    future_time = datetime.now(timezone(timedelta(hours=5))) + timedelta(hours=1)

    # This should pass the timezone-aware validation but fail on resource not found
    with pytest.raises(ValueError, match="Resource 1 not found"):
        await resource.generate_presigned_url(
            db=db_session, resource_id=1, expires_at=future_time
        )


@pytest.mark.asyncio
async def test_agent_can_access_resource_returns_true(
    db_session: AsyncSession,
) -> None:
    """Test that agent_can_access_resource returns True (current implementation)."""
    result = resource.agent_can_access_resource(
        db=db_session, agent_id="test_agent", resource_id=1
    )
    assert result is True
