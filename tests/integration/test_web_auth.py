import pytest
from fastapi import status
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import create_access_token, decode_access_token, hash_password
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


@pytest.mark.asyncio
async def test_refresh_token_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Create active user
    user = User(
        email="refreshuser@example.com",
        name="Refresh User",
        hashed_password=hash_password("refreshpass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    token = create_access_token(user.id)
    cookies = {"access_token": token}
    resp = await async_client.post("/api/v1/web/auth/refresh", cookies=cookies)
    assert resp.status_code == status.HTTP_200_OK
    assert "Session refreshed" in resp.text
    assert "access_token" in resp.cookies
    # The new token should decode to the same user id
    new_token = resp.cookies["access_token"]
    assert decode_access_token(new_token) == user.id


@pytest.mark.asyncio
async def test_refresh_token_missing(async_client: AsyncClient) -> None:
    resp = await async_client.post("/api/v1/web/auth/refresh")
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED
    assert "No token found" in resp.text


@pytest.mark.asyncio
async def test_refresh_token_invalid(async_client: AsyncClient) -> None:
    cookies = {"access_token": "not.a.valid.token"}
    resp = await async_client.post("/api/v1/web/auth/refresh", cookies=cookies)
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED
    assert "Invalid or expired token" in resp.text


@pytest.mark.asyncio
async def test_refresh_token_inactive_user(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Create inactive user
    user = User(
        email="inactive_refresh@example.com",
        name="Inactive Refresh",
        hashed_password=hash_password("inactivepass"),
        is_active=False,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    token = create_access_token(user.id)
    cookies = {"access_token": token}
    resp = await async_client.post("/api/v1/web/auth/refresh", cookies=cookies)
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED
    assert "User not found or inactive" in resp.text


@pytest.mark.asyncio
async def test_get_me_authenticated(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(
        email="profileuser@example.com",
        name="Profile User",
        hashed_password=hash_password("profilepass"),
        is_active=True,
        is_superuser=True,
        role=UserRole.ADMIN,
    )
    db_session.add(user)
    await db_session.commit()
    # Login to get token
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "profileuser@example.com", "password": "profilepass"},
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_200_OK
    token = resp.cookies.get("access_token")
    assert token is not None
    if token is not None:
        async_client.cookies.set("access_token", token)
    # Request profile
    resp = await async_client.get("/api/v1/web/auth/me")
    assert resp.status_code == status.HTTP_200_OK
    assert resp.headers["content-type"].startswith("text/html")
    assert "Profile Details" in resp.text
    assert "Profile User" in resp.text
    assert "profileuser@example.com" in resp.text
    assert "Yes" in resp.text  # is_active, is_superuser, is_verified (may be False)


@pytest.mark.asyncio
async def test_get_me_unauthenticated(async_client: AsyncClient) -> None:
    resp = await async_client.get("/api/v1/web/auth/me")
    assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)
    # Should not leak user info
    assert "Profile Details" not in resp.text


@pytest.mark.asyncio
async def test_patch_me_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(
        email="patchme@example.com",
        name="Patch Me",
        hashed_password=hash_password("patchpass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "patchme@example.com", "password": "patchpass"},
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_200_OK
    token = resp.cookies.get("access_token")
    assert token is not None
    if token is not None:
        async_client.cookies.set("access_token", token)
    # Patch name and email
    resp = await async_client.patch(
        "/api/v1/web/auth/me",
        json={"name": "Patched Name", "email": "patched@example.com"},
    )
    assert resp.status_code == status.HTTP_200_OK
    assert "Patched Name" in resp.text
    assert "patched@example.com" in resp.text


@pytest.mark.asyncio
async def test_patch_me_duplicate_email(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user1 = User(
        email="dup1@example.com",
        name="Dup1",
        hashed_password=hash_password("pass1"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    user2 = User(
        email="dup2@example.com",
        name="Dup2",
        hashed_password=hash_password("pass2"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add_all([user1, user2])
    await db_session.commit()
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "dup1@example.com", "password": "pass1"},
        follow_redirects=True,
    )
    token = resp.cookies.get("access_token")
    if token is not None:
        async_client.cookies.set("access_token", token)
    resp = await async_client.patch(
        "/api/v1/web/auth/me",
        json={"email": "dup2@example.com"},
    )
    assert resp.status_code == status.HTTP_409_CONFLICT
    assert "Email already in use" in resp.text


@pytest.mark.asyncio
async def test_patch_me_duplicate_name(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user1 = User(
        email="dupname1@example.com",
        name="DupName1",
        hashed_password=hash_password("pass1"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    user2 = User(
        email="dupname2@example.com",
        name="DupName2",
        hashed_password=hash_password("pass2"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add_all([user1, user2])
    await db_session.commit()
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "dupname1@example.com", "password": "pass1"},
        follow_redirects=True,
    )
    token = resp.cookies.get("access_token")
    if token is not None:
        async_client.cookies.set("access_token", token)
    resp = await async_client.patch(
        "/api/v1/web/auth/me",
        json={"name": "DupName2"},
    )
    assert resp.status_code == status.HTTP_409_CONFLICT
    assert "Name already in use" in resp.text


@pytest.mark.asyncio
async def test_patch_me_invalid_input(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(
        email="invalidpatch@example.com",
        name="Invalid Patch",
        hashed_password=hash_password("patchpass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "invalidpatch@example.com", "password": "patchpass"},
        follow_redirects=True,
    )
    token = resp.cookies.get("access_token")
    if token is not None:
        async_client.cookies.set("access_token", token)
    # No fields
    resp = await async_client.patch(
        "/api/v1/web/auth/me",
        json={},
    )
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
    assert "No fields to update" in resp.text


@pytest.mark.asyncio
async def test_patch_me_unauthenticated(async_client: AsyncClient) -> None:
    resp = await async_client.patch(
        "/api/v1/web/auth/me",
        json={"name": "Should Not Work"},
    )
    assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)
