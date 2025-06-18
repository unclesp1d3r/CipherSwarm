from http import HTTPStatus

import pytest
from fastapi import status
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import (
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)
from app.models.project import Project, ProjectUserAssociation
from app.models.user import User, UserRole
from tests.factories.user_factory import UserFactory


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
    async_client.cookies.set("access_token", create_access_token(user.id))
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "testuser@example.com", "password": "testpass123"},
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert data["message"] == "Login successful."
    assert data["level"] == "success"
    assert "access_token" in resp.cookies
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"


@pytest.mark.asyncio
async def test_login_invalid_password(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(
        email="badpass@example.com",
        name="Bad Pass",
        hashed_password=hash_password("goodpass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    async_client.cookies.set("access_token", create_access_token(user.id))
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "badpass@example.com", "password": "wrongpass"},
        follow_redirects=True,
    )
    assert resp.status_code == 400
    data = resp.json()
    assert data["message"] == "Invalid email or password."
    assert data["level"] == "error"
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
    async_client.cookies.set("access_token", create_access_token(user.id))
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "inactive@example.com", "password": "inactivepass"},
        follow_redirects=True,
    )
    assert resp.status_code == 403
    data = resp.json()
    assert data["message"] == "Account is inactive."
    assert data["level"] == "error"
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
    async_client.cookies.set("access_token", create_access_token(user.id))
    resp = await async_client.post("/api/v1/web/auth/refresh")
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert data["message"] == "Session refreshed."
    assert data["level"] == "success"
    assert "access_token" in resp.cookies
    new_token = resp.cookies["access_token"]
    assert decode_access_token(new_token) == user.id


@pytest.mark.asyncio
async def test_refresh_token_missing(async_client: AsyncClient) -> None:
    resp = await async_client.post("/api/v1/web/auth/refresh")
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED
    data = resp.json()
    assert data["detail"] == "No token found."


@pytest.mark.asyncio
async def test_refresh_token_invalid(async_client: AsyncClient) -> None:
    async_client.cookies.set("access_token", "not.a.valid.token")
    resp = await async_client.post("/api/v1/web/auth/refresh")
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED
    data = resp.json()
    assert data["detail"] == "Invalid or expired token."


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
    async_client.cookies.set("access_token", create_access_token(user.id))
    resp = await async_client.post("/api/v1/web/auth/refresh")
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED
    data = resp.json()
    assert data["detail"] == "User not found or inactive."


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
    async_client.cookies.set("access_token", create_access_token(user.id))
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "profileuser@example.com", "password": "profilepass"},
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_200_OK
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    # Request profile
    resp = await async_client.get("/api/v1/web/auth/me")
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert data["email"] == "profileuser@example.com"
    assert data["name"] == "Profile User"
    assert data["is_active"] is True
    assert data["is_superuser"] is True
    assert data["role"] == "admin"


@pytest.mark.asyncio
async def test_get_me_unauthenticated(async_client: AsyncClient) -> None:
    resp = await async_client.get("/api/v1/web/auth/me")
    assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)
    # Should not leak user info
    if resp.status_code == status.HTTP_401_UNAUTHORIZED:
        assert resp.json()["detail"] == "Not authenticated"


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
    async_client.cookies.set("access_token", create_access_token(user.id))
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "patchme@example.com", "password": "patchpass"},
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_200_OK
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    # Patch name and email
    resp = await async_client.patch(
        "/api/v1/web/auth/me",
        json={"name": "Patched Name", "email": "patched@example.com"},
    )
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert data["name"] == "Patched Name"
    assert data["email"] == "patched@example.com"


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
    async_client.cookies.set("access_token", create_access_token(user1.id))
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "dup1@example.com", "password": "pass1"},
        follow_redirects=True,
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    resp = await async_client.patch(
        "/api/v1/web/auth/me",
        json={"email": "dup2@example.com"},
    )
    assert resp.status_code == status.HTTP_409_CONFLICT
    data = resp.json()
    assert data["detail"] == "Email already in use."


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
    async_client.cookies.set("access_token", create_access_token(user1.id))
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "dupname1@example.com", "password": "pass1"},
        follow_redirects=True,
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    resp = await async_client.patch(
        "/api/v1/web/auth/me",
        json={"name": "DupName2"},
    )
    assert resp.status_code == status.HTTP_409_CONFLICT
    data = resp.json()
    assert data["detail"] == "Name already in use."


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
    async_client.cookies.set("access_token", create_access_token(user.id))
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "invalidpatch@example.com", "password": "patchpass"},
        follow_redirects=True,
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    # No fields
    resp = await async_client.patch(
        "/api/v1/web/auth/me",
        json={},
    )
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
    data = resp.json()
    assert data["detail"] == "No fields to update."


@pytest.mark.asyncio
async def test_patch_me_unauthenticated(async_client: AsyncClient) -> None:
    resp = await async_client.patch(
        "/api/v1/web/auth/me",
        json={"name": "Should Not Work"},
    )
    assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)


@pytest.mark.asyncio
async def test_get_context_authenticated(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Create user and two projects
    user = User(
        email="contextuser@example.com",
        name="Context User",
        hashed_password=hash_password("contextpass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    project1 = Project(name="Project One")
    project2 = Project(name="Project Two")
    db_session.add_all([project1, project2])
    await db_session.commit()
    await db_session.refresh(project1)
    await db_session.refresh(project2)
    assoc1 = ProjectUserAssociation(user_id=user.id, project_id=project1.id)
    assoc2 = ProjectUserAssociation(user_id=user.id, project_id=project2.id)
    db_session.add_all([assoc1, assoc2])
    await db_session.commit()
    async_client.cookies.set("access_token", create_access_token(user.id))
    async_client.cookies.set("active_project_id", str(project1.id))
    resp = await async_client.get("/api/v1/web/auth/context")
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert data["user"]["email"] == "contextuser@example.com"
    assert data["user"]["name"] == "Context User"
    assert data["active_project"]["name"] == "Project One"
    assert len(data["available_projects"]) == 2
    project_names = {p["name"] for p in data["available_projects"]}
    assert "Project One" in project_names
    assert "Project Two" in project_names


@pytest.mark.asyncio
async def test_set_context_switches_project(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(
        email="switchuser@example.com",
        name="Switch User",
        hashed_password=hash_password("switchpass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    project1 = Project(name="Alpha Project")
    project2 = Project(name="Beta Project")
    db_session.add_all([project1, project2])
    await db_session.commit()
    await db_session.refresh(project1)
    await db_session.refresh(project2)
    assoc1 = ProjectUserAssociation(user_id=user.id, project_id=project1.id)
    assoc2 = ProjectUserAssociation(user_id=user.id, project_id=project2.id)
    db_session.add_all([assoc1, assoc2])
    await db_session.commit()
    async_client.cookies.set("access_token", create_access_token(user.id))
    async_client.cookies.set("active_project_id", str(project1.id))
    # Switch to Beta Project
    resp = await async_client.post(
        "/api/v1/web/auth/context",
        json={"project_id": project2.id},
    )
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert data["active_project"]["name"] == "Beta Project"
    project_names = {p["name"] for p in data["available_projects"]}
    assert "Alpha Project" in project_names
    assert "Beta Project" in project_names
    # Check cookie is set
    assert resp.cookies.get("active_project_id") == str(project2.id)


@pytest.mark.asyncio
async def test_set_context_forbidden(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(
        email="forbiduser@example.com",
        name="Forbid User",
        hashed_password=hash_password("forbidpass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    project1 = Project(name="Allowed Project")
    project2 = Project(name="Forbidden Project")
    db_session.add_all([project1, project2])
    await db_session.commit()
    await db_session.refresh(project1)
    await db_session.refresh(project2)
    assoc1 = ProjectUserAssociation(user_id=user.id, project_id=project1.id)
    db_session.add(assoc1)
    await db_session.commit()
    token = create_access_token(user.id)
    async_client.cookies.set("access_token", token)
    async_client.cookies.set("active_project_id", str(project1.id))
    # Try to switch to forbidden project
    resp = await async_client.post(
        "/api/v1/web/auth/context",
        json={"project_id": project2.id},
    )
    assert resp.status_code == status.HTTP_403_FORBIDDEN
    data = resp.json()
    assert data["detail"] == "User does not have access to this project."


@pytest.mark.asyncio
async def test_context_requires_auth(async_client: AsyncClient) -> None:
    resp = await async_client.get("/api/v1/web/auth/context")
    assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)
    resp2 = await async_client.post("/api/v1/web/auth/context", json={"project_id": 1})
    assert resp2.status_code in (
        status.HTTP_401_UNAUTHORIZED,
        status.HTTP_403_FORBIDDEN,
    )


@pytest.mark.asyncio
async def test_change_password_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(
        email="changepass@example.com",
        name="Change Pass",
        hashed_password=hash_password("oldpassword1!A"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    # Login to get token
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "changepass@example.com", "password": "oldpassword1!A"},
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_200_OK
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    # Change password
    resp = await async_client.post(
        "/api/v1/web/auth/change_password",
        data={
            "old_password": "oldpassword1!A",
            "new_password": "Newpassword2!B",
            "new_password_confirm": "Newpassword2!B",
        },
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert data["message"] == "Password changed successfully."
    # Password should be updated in DB
    await db_session.refresh(user)
    assert verify_password("Newpassword2!B", user.hashed_password)


@pytest.mark.asyncio
async def test_change_password_wrong_old(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(
        email="wrongold@example.com",
        name="Wrong Old",
        hashed_password=hash_password("oldpassword1!A"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "wrongold@example.com", "password": "oldpassword1!A"},
        follow_redirects=True,
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    resp = await async_client.post(
        "/api/v1/web/auth/change_password",
        data={
            "old_password": "incorrect!pass",
            "new_password": "Newpassword2!B",
            "new_password_confirm": "Newpassword2!B",
        },
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED
    data = resp.json()
    assert data["detail"] == "Current password is incorrect."


@pytest.mark.asyncio
async def test_change_password_mismatch(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(
        email="mismatch@example.com",
        name="Mismatch",
        hashed_password=hash_password("oldpassword1!A"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "mismatch@example.com", "password": "oldpassword1!A"},
        follow_redirects=True,
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    resp = await async_client.post(
        "/api/v1/web/auth/change_password",
        data={
            "old_password": "oldpassword1!A",
            "new_password": "Newpassword2!B",
            "new_password_confirm": "WrongConfirm3!C",
        },
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    data = resp.json()
    assert data["detail"] == "New passwords do not match."


@pytest.mark.asyncio
async def test_change_password_weak(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(
        email="weakpass@example.com",
        name="Weak Pass",
        hashed_password=hash_password("oldpassword1!A"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "weakpass@example.com", "password": "oldpassword1!A"},
        follow_redirects=True,
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    resp = await async_client.post(
        "/api/v1/web/auth/change_password",
        data={
            "old_password": "oldpassword1!A",
            "new_password": "short",
            "new_password_confirm": "short",
        },
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
    data = resp.json()
    # PASSWORD_MIN_LENGTH is 10, defined in auth.py
    assert "Password must be at least 10 characters" in data["detail"]


@pytest.mark.asyncio
async def test_change_password_unauthenticated(async_client: AsyncClient) -> None:
    resp = await async_client.post(
        "/api/v1/web/auth/change_password",
        data={
            "old_password": "irrelevant",
            "new_password": "Newpassword2!B",
            "new_password_confirm": "Newpassword2!B",
        },
        follow_redirects=True,
    )
    assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)
    data = resp.json()
    assert (
        data["detail"] == "Login"
        or data["detail"] == "Not authorized"
        or data["detail"] == "Not authenticated"
    )


@pytest.mark.asyncio
async def test_create_user_admin_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = User(
        email="admin@example.com",
        name="Admin",
        hashed_password=hash_password("adminpass"),
        is_active=True,
        is_superuser=True,
        role=UserRole.ADMIN,
    )
    db_session.add(admin)
    await db_session.commit()
    # Login as admin
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "admin@example.com", "password": "adminpass"},
        follow_redirects=True,
    )
    assert resp.status_code == status.HTTP_200_OK
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    # Create user
    resp = await async_client.post(
        "/api/v1/web/users",
        json={
            "email": "newuser@example.com",
            "name": "New User",
            "password": "newpass123",
        },
    )
    assert resp.status_code == status.HTTP_201_CREATED
    data = resp.json()
    assert data["name"] == "New User"
    assert data["email"] == "newuser@example.com"
    assert data["is_active"] is True


@pytest.mark.asyncio
async def test_create_user_duplicate_email(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = User(
        email="admin2@example.com",
        name="Admin2",
        hashed_password=hash_password("adminpass2"),
        is_active=True,
        is_superuser=True,
        role=UserRole.ADMIN,
    )
    user = User(
        email="dupe@example.com",
        name="Dupe",
        hashed_password=hash_password("dupepass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add_all([admin, user])
    await db_session.commit()
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "admin2@example.com", "password": "adminpass2"},
        follow_redirects=True,
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    resp = await async_client.post(
        "/api/v1/web/users",
        json={"email": "dupe@example.com", "name": "Another", "password": "pass"},
    )
    assert resp.status_code == status.HTTP_409_CONFLICT
    data = resp.json()
    assert data["detail"] == "A user with that email or name already exists."


@pytest.mark.asyncio
async def test_create_user_non_admin_forbidden(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(
        email="user@example.com",
        name="User",
        hashed_password=hash_password("userpass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user)
    await db_session.commit()
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "user@example.com", "password": "userpass"},
        follow_redirects=True,
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    resp = await async_client.post(
        "/api/v1/web/users",
        json={
            "email": "forbidden@example.com",
            "name": "Forbidden",
            "password": "pass",
        },
    )
    assert resp.status_code == status.HTTP_403_FORBIDDEN
    data = resp.json()
    assert data["detail"] == "Not authorized"


@pytest.mark.asyncio
async def test_create_user_invalid_input(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = User(
        email="admin3@example.com",
        name="Admin3",
        hashed_password=hash_password("adminpass3"),
        is_active=True,
        is_superuser=True,
        role=UserRole.ADMIN,
    )
    db_session.add(admin)
    await db_session.commit()
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "admin3@example.com", "password": "adminpass3"},
        follow_redirects=True,
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    # Missing email
    resp = await async_client.post(
        "/api/v1/web/users",
        json={"name": "No Email", "password": "pass"},
    )
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
    # Invalid email
    resp = await async_client.post(
        "/api/v1/web/users",
        json={"email": "notanemail", "name": "Bad Email", "password": "pass"},
    )
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_admin_can_patch_user(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(role=UserRole.ADMIN, is_superuser=True)
    user = await UserFactory.create_async(role=UserRole.ANALYST)
    # Login as admin
    resp = await async_client.post(
        "/api/v1/web/auth/login", data={"email": admin.email, "password": "password"}
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    resp = await async_client.patch(
        f"/api/v1/web/users/{user.id}",
        json={"name": "New Name", "email": "newemail@example.com", "role": "operator"},
        headers={"HX-Request": "true"},
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["name"] == "New Name"
    assert data["email"] == "newemail@example.com"
    assert data["role"] == "operator"


@pytest.mark.asyncio
async def test_non_admin_cannot_patch_user(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user1 = await UserFactory.create_async(role=UserRole.ANALYST)
    user2 = await UserFactory.create_async(role=UserRole.ANALYST)
    resp = await async_client.post(
        "/api/v1/web/auth/login", data={"email": user1.email, "password": "password"}
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    resp = await async_client.patch(
        f"/api/v1/web/users/{user2.id}",
        json={"name": "Hacker"},
        headers={"HX-Request": "true"},
    )
    assert resp.status_code == HTTPStatus.FORBIDDEN
    data = resp.json()
    assert data["detail"] == "Not authorized"


@pytest.mark.asyncio
async def test_patch_user_duplicate_email(
    db_session: AsyncSession, async_client: AsyncClient
) -> None:
    admin = await UserFactory.create_async(role=UserRole.ADMIN, is_superuser=True)
    await UserFactory.create_async(email="a@b.com")
    user2 = await UserFactory.create_async(email="c@d.com")
    resp = await async_client.post(
        "/api/v1/web/auth/login", data={"email": admin.email, "password": "password"}
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    resp = await async_client.patch(
        f"/api/v1/web/users/{user2.id}",
        json={"email": "a@b.com"},
        headers={"HX-Request": "true"},
    )
    assert resp.status_code == HTTPStatus.CONFLICT
    data = resp.json()
    assert data["detail"] == "Email already in use."


@pytest.mark.asyncio
async def test_patch_user_invalid_role(
    db_session: AsyncSession, async_client: AsyncClient
) -> None:
    admin = await UserFactory.create_async(role=UserRole.ADMIN, is_superuser=True)
    user = await UserFactory.create_async()
    resp = await async_client.post(
        "/api/v1/web/auth/login", data={"email": admin.email, "password": "password"}
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    resp = await async_client.patch(
        f"/api/v1/web/users/{user.id}",
        json={"role": "notarole"},
        headers={"HX-Request": "true"},
    )
    assert resp.status_code == HTTPStatus.CONFLICT
    data = resp.json()
    assert data["detail"] == "Invalid role: notarole"


@pytest.mark.asyncio
async def test_patch_user_not_found(
    db_session: AsyncSession, async_client: AsyncClient
) -> None:
    admin = await UserFactory.create_async(role=UserRole.ADMIN, is_superuser=True)
    resp = await async_client.post(
        "/api/v1/web/auth/login", data={"email": admin.email, "password": "password"}
    )
    token = resp.cookies.get("access_token")
    assert token is not None, "Login did not return access_token cookie"
    async_client.cookies.set("access_token", token)
    import uuid

    bad_id = str(uuid.uuid4())
    resp = await async_client.patch(
        f"/api/v1/web/users/{bad_id}",
        json={"name": "Ghost"},
        headers={"HX-Request": "true"},
    )
    assert resp.status_code == HTTPStatus.NOT_FOUND
    data = resp.json()
    assert data["detail"] == "User not found"


@pytest.mark.asyncio
async def test_admin_can_delete_user(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Create admin and target user
    admin = User(
        email="admin_delete@example.com",
        name="AdminDelete",
        hashed_password=hash_password("adminpass"),
        is_active=True,
        is_superuser=True,
        role=UserRole.ADMIN,
    )
    user = User(
        email="delete_me@example.com",
        name="Delete Me",
        hashed_password=hash_password("deletepass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add_all([admin, user])
    await db_session.commit()
    # Login as admin
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "admin_delete@example.com", "password": "adminpass"},
        follow_redirects=True,
    )
    assert resp.status_code == HTTPStatus.OK
    token = resp.cookies.get("access_token")
    assert token
    async_client.cookies.set("access_token", token)
    # Deactivate user
    resp = await async_client.delete(f"/api/v1/web/users/{user.id}")
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["name"] == "Delete Me"
    assert data["is_active"] is False
    # Fetch user list and check inactive - This part might need adjustment
    # if list_users is also changed or if this check is HTML specific.
    # For now, primary check is the direct response from delete.


@pytest.mark.asyncio
async def test_non_admin_cannot_delete_user(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Create non-admin and target user
    user1 = User(
        email="user1@example.com",
        name="User1",
        hashed_password=hash_password("user1pass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    user2 = User(
        email="user2@example.com",
        name="User2",
        hashed_password=hash_password("user2pass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add_all([user1, user2])
    await db_session.commit()
    # Login as user1
    resp = await async_client.post(
        "/api/v1/web/auth/login",
        data={"email": "user1@example.com", "password": "user1pass"},
        follow_redirects=True,
    )
    assert resp.status_code == HTTPStatus.OK
    token = resp.cookies.get("access_token")
    assert token
    async_client.cookies.set("access_token", token)
    # Attempt to deactivate user2
    resp = await async_client.delete(f"/api/v1/web/users/{user2.id}")
    assert resp.status_code == HTTPStatus.FORBIDDEN
    data = resp.json()
    assert data["detail"] == "Not authorized"
