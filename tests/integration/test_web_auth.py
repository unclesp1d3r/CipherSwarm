import pytest
from fastapi import status
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import hash_password
from app.models.user import User, UserRole


@pytest.mark.asyncio
async def test_login_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Create active user
    user = User(
        email="testuser@example.com",
        name="Test User",
        hashed_password=hash_password("testpass123"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    # Attempt login
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "testuser@example.com", "password": "testpass123"},
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_200_OK
    assert "Login successful" in resp.text
    assert "access_token" in resp.cookies


@pytest.mark.asyncio
async def test_login_invalid_password(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(
        email="badpass@example.com",
        name="Bad Pass",
        hashed_password=hash_password("rightpass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "badpass@example.com", "password": "wrongpass"},
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED
    assert "Invalid email or password" in resp.text
    assert "access_token" not in resp.cookies


@pytest.mark.asyncio
async def test_login_inactive_user(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(
        email="inactive@example.com",
        name="Inactive User",
        hashed_password=hash_password("inactivepass"),
        is_active=False,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "inactive@example.com", "password": "inactivepass"},
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_403_FORBIDDEN
    assert "Account is inactive" in resp.text
    assert "access_token" not in resp.cookies
