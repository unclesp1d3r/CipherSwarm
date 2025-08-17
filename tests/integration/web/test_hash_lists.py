"""
Integration tests for hash list web endpoints.
"""

from http import HTTPStatus

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from tests.factories.hash_item_factory import HashItemFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory
from tests.utils.hash_type_utils import get_or_create_hash_type


@pytest.mark.asyncio
async def test_create_hash_list_success(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
) -> None:
    """Test successful hash list creation."""

    # Get authenticated client and user
    authenticated_async_client, user = authenticated_user_client

    # Create test data
    project = await project_factory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    # Associate user with project
    from app.models.project import ProjectUserAssociation, ProjectUserRole

    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create hash list
    response = await authenticated_async_client.post(
        "/api/v1/web/hash_lists/",
        json={
            "name": "Test Hash List",
            "description": "A test hash list",
            "project_id": project.id,
            "hash_type_id": hash_type.id,
            "is_unavailable": False,
        },
    )

    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Test Hash List"
    assert data["description"] == "A test hash list"
    assert data["project_id"] == project.id
    assert data["hash_type_id"] == hash_type.id
    assert data["is_unavailable"] is False


@pytest.mark.asyncio
async def test_create_hash_list_validation_error(
    authenticated_async_client: AsyncClient,
) -> None:
    """Test hash list creation with validation errors."""
    response = await authenticated_async_client.post(
        "/api/v1/web/hash_lists/",
        json={
            "name": "",  # Invalid: empty name
            "project_id": -1,  # Invalid: negative ID
            "hash_type_id": -1,  # Invalid: negative ID
        },
    )

    assert response.status_code == HTTPStatus.UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_create_hash_list_unauthorized(
    async_client: AsyncClient,
    db_session: AsyncSession,
    project_factory: ProjectFactory,
) -> None:
    """Test hash list creation without authentication."""

    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")
    project = await project_factory.create_async()
    response = await async_client.post(
        "/api/v1/web/hash_lists/",
        json={
            "name": "Test Hash List",
            "project_id": project.id,
            "hash_type_id": hash_type.id,
        },
    )

    assert response.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_list_hash_lists_success(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test successful hash list listing."""

    # Create test data
    project = await project_factory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    await hash_list_factory.create_async(
        name="Hash List 1",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )
    await hash_list_factory.create_async(
        name="Hash List 2",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )

    response = await authenticated_async_client.get("/api/v1/web/hash_lists/")

    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert "items" in data
    assert "total" in data
    assert len(data["items"]) == 2


@pytest.mark.asyncio
async def test_list_hash_lists_with_pagination(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test hash list listing with pagination."""
    # Set factory sessions

    # Create test data
    project = await project_factory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    for i in range(5):
        await hash_list_factory.create_async(
            name=f"Hash List {i}",
            project_id=project.id,
            hash_type_id=hash_type.id,
        )

    response = await authenticated_async_client.get(
        "/api/v1/web/hash_lists/?page=2&size=2"
    )

    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert len(data["items"]) == 2
    assert data["total"] == 5


@pytest.mark.asyncio
async def test_list_hash_list_items_success(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    hash_item_factory: HashItemFactory,
) -> None:
    """Test successful hash list items listing."""

    # Get authenticated client and user
    authenticated_async_client, user = authenticated_user_client

    # Create test data
    project = await project_factory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    # Associate user with project
    from app.models.project import ProjectUserAssociation, ProjectUserRole

    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create hash list
    hash_list = await hash_list_factory.create_async(
        name="Test Hash List",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )

    # Create hash items
    hash_items = []
    for i in range(5):
        hash_item = await hash_item_factory.create_async(
            hash=f"hash{i}",
            plain_text=f"password{i}" if i < 2 else None,  # First 2 are cracked
            meta={"username": f"user{i}"},
        )
        hash_items.append(hash_item)

    # Associate hash items with hash list using the association table
    from app.models.hash_list import hash_list_items

    for hash_item in hash_items:
        stmt = hash_list_items.insert().values(
            hash_list_id=hash_list.id, hash_item_id=hash_item.id
        )
        await db_session.execute(stmt)
    await db_session.commit()

    # Test the endpoint
    response = await authenticated_async_client.get(
        f"/api/v1/web/hash_lists/{hash_list.id}/items"
    )

    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert "items" in data
    assert "total" in data
    assert len(data["items"]) == 5
    assert data["total"] == 5

    # Check item structure
    item = data["items"][0]
    assert "id" in item
    assert "hash" in item
    assert "salt" in item
    assert "meta" in item
    assert "plain_text" in item


@pytest.mark.asyncio
async def test_list_hash_list_items_with_pagination(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    hash_item_factory: HashItemFactory,
) -> None:
    """Test hash list items listing with pagination."""

    # Get authenticated client and user
    authenticated_async_client, user = authenticated_user_client

    # Create test data
    project = await project_factory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    # Associate user with project
    from app.models.project import ProjectUserAssociation, ProjectUserRole

    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create hash list
    hash_list = await hash_list_factory.create_async(
        name="Test Hash List",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )

    # Create hash items
    hash_items = []
    for i in range(10):
        hash_item = await hash_item_factory.create_async(
            id=None,  # Let the database auto-generate IDs
            hash=f"hash{i:02d}",
            plain_text=None,
        )
        hash_items.append(hash_item)

    # Associate hash items with hash list using the association table
    from app.models.hash_list import hash_list_items

    for hash_item in hash_items:
        stmt = hash_list_items.insert().values(
            hash_list_id=hash_list.id, hash_item_id=hash_item.id
        )
        await db_session.execute(stmt)
    await db_session.commit()

    # Test pagination
    response = await authenticated_async_client.get(
        f"/api/v1/web/hash_lists/{hash_list.id}/items?page=2&size=3"
    )

    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert len(data["items"]) == 3
    assert data["total"] == 10
    assert data["page"] == 2
    assert data["page_size"] == 3


@pytest.mark.asyncio
async def test_list_hash_list_items_with_search(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    hash_item_factory: HashItemFactory,
) -> None:
    """Test hash list items listing with search functionality."""

    # Get authenticated client and user
    authenticated_async_client, user = authenticated_user_client

    # Create test data
    project = await project_factory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    # Associate user with project
    from app.models.project import ProjectUserAssociation, ProjectUserRole

    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create hash list
    hash_list = await hash_list_factory.create_async(
        name="Test Hash List",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )

    # Create hash items with specific patterns
    hash_items = [
        await hash_item_factory.create_async(hash="abc123", plain_text="password1"),
        await hash_item_factory.create_async(hash="def456", plain_text="secret"),
        await hash_item_factory.create_async(hash="ghi789", plain_text=None),
    ]

    # Associate hash items with hash list using the association table
    from app.models.hash_list import hash_list_items

    for hash_item in hash_items:
        stmt = hash_list_items.insert().values(
            hash_list_id=hash_list.id, hash_item_id=hash_item.id
        )
        await db_session.execute(stmt)
    await db_session.commit()

    # Test search by hash value
    response = await authenticated_async_client.get(
        f"/api/v1/web/hash_lists/{hash_list.id}/items?search=abc"
    )

    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert len(data["items"]) == 1
    assert data["items"][0]["hash"] == "abc123"

    # Test search by plaintext
    response = await authenticated_async_client.get(
        f"/api/v1/web/hash_lists/{hash_list.id}/items?search=secret"
    )

    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert len(data["items"]) == 1
    assert data["items"][0]["plain_text"] == "secret"


@pytest.mark.asyncio
async def test_list_hash_list_items_with_status_filter(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    hash_item_factory: HashItemFactory,
) -> None:
    """Test hash list items listing with status filtering."""

    # Get authenticated client and user
    authenticated_async_client, user = authenticated_user_client

    # Create test data
    project = await project_factory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    # Associate user with project
    from app.models.project import ProjectUserAssociation, ProjectUserRole

    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create hash list
    hash_list = await hash_list_factory.create_async(
        name="Test Hash List",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )

    # Create hash items - some cracked, some not
    hash_items = [
        await hash_item_factory.create_async(hash="cracked1", plain_text="password1"),
        await hash_item_factory.create_async(hash="cracked2", plain_text="password2"),
        await hash_item_factory.create_async(hash="uncracked1", plain_text=None),
        await hash_item_factory.create_async(hash="uncracked2", plain_text=None),
    ]

    # Associate hash items with hash list using the association table
    from app.models.hash_list import hash_list_items

    for hash_item in hash_items:
        stmt = hash_list_items.insert().values(
            hash_list_id=hash_list.id, hash_item_id=hash_item.id
        )
        await db_session.execute(stmt)
    await db_session.commit()

    # Test filter for cracked hashes
    response = await authenticated_async_client.get(
        f"/api/v1/web/hash_lists/{hash_list.id}/items?status_filter=cracked"
    )

    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert len(data["items"]) == 2
    assert data["total"] == 2
    for item in data["items"]:
        assert item["plain_text"] is not None

    # Test filter for uncracked hashes
    response = await authenticated_async_client.get(
        f"/api/v1/web/hash_lists/{hash_list.id}/items?status_filter=uncracked"
    )

    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert len(data["items"]) == 2
    assert data["total"] == 2
    for item in data["items"]:
        assert item["plain_text"] is None


@pytest.mark.asyncio
async def test_list_hash_list_items_csv_export(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    hash_item_factory: HashItemFactory,
) -> None:
    """Test hash list items CSV export functionality."""

    # Get authenticated client and user
    authenticated_async_client, user = authenticated_user_client

    # Create test data
    project = await project_factory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    # Associate user with project
    from app.models.project import ProjectUserAssociation, ProjectUserRole

    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create hash list
    hash_list = await hash_list_factory.create_async(
        name="Test Hash List",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )

    # Create hash items
    hash_items = [
        await hash_item_factory.create_async(
            hash="abc123",
            salt="salt1",
            plain_text="password1",
            meta={"username": "user1"},
        ),
        await hash_item_factory.create_async(
            hash="def456",
            salt=None,
            plain_text=None,
            meta=None,
        ),
    ]

    # Associate hash items with hash list using the association table
    from app.models.hash_list import hash_list_items

    for hash_item in hash_items:
        stmt = hash_list_items.insert().values(
            hash_list_id=hash_list.id, hash_item_id=hash_item.id
        )
        await db_session.execute(stmt)
    await db_session.commit()

    # Test CSV export
    response = await authenticated_async_client.get(
        f"/api/v1/web/hash_lists/{hash_list.id}/items?export_format=csv"
    )

    assert response.status_code == HTTPStatus.OK
    assert "text/csv" in response.headers.get("content-type", "")
    assert "attachment" in response.headers.get("content-disposition", "")
    assert f"hash_list_{hash_list.id}_items.csv" in response.headers.get(
        "content-disposition", ""
    )

    # Check CSV content
    csv_content = response.text
    lines = csv_content.strip().split("\n")
    assert lines[0].strip() == "id,hash,salt,meta,plain_text"
    assert len(lines) == 3  # Header + 2 data rows

    # Check that CSV contains expected data
    assert "abc123" in csv_content
    assert "def456" in csv_content


@pytest.mark.asyncio
async def test_list_hash_list_items_tsv_export(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    hash_item_factory: HashItemFactory,
) -> None:
    """Test hash list items TSV export functionality."""

    # Get authenticated client and user
    authenticated_async_client, user = authenticated_user_client

    # Create test data
    project = await project_factory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    # Associate user with project
    from app.models.project import ProjectUserAssociation, ProjectUserRole

    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create hash list
    hash_list = await hash_list_factory.create_async(
        name="Test Hash List",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )

    # Create hash items
    hash_items = [
        await hash_item_factory.create_async(
            hash="abc123",
            salt="salt1",
            plain_text="password1",
            meta={"username": "user1"},
        ),
    ]

    # Associate hash items with hash list using the association table
    from app.models.hash_list import hash_list_items

    for hash_item in hash_items:
        stmt = hash_list_items.insert().values(
            hash_list_id=hash_list.id, hash_item_id=hash_item.id
        )
        await db_session.execute(stmt)
    await db_session.commit()

    # Test TSV export
    response = await authenticated_async_client.get(
        f"/api/v1/web/hash_lists/{hash_list.id}/items?export_format=tsv"
    )

    assert response.status_code == HTTPStatus.OK
    assert "text/tab-separated-values" in response.headers.get("content-type", "")
    assert "attachment" in response.headers.get("content-disposition", "")
    assert f"hash_list_{hash_list.id}_items.tsv" in response.headers.get(
        "content-disposition", ""
    )

    # Check TSV content
    tsv_content = response.text
    lines = tsv_content.strip().split("\n")
    assert lines[0].strip() == "id\thash\tsalt\tmeta\tplain_text"
    assert len(lines) == 2  # Header + 1 data row

    # Check that TSV contains expected data
    assert "abc123" in tsv_content


@pytest.mark.asyncio
async def test_list_hash_list_items_not_found(
    authenticated_async_client: AsyncClient,
) -> None:
    """Test hash list items listing with non-existent hash list."""
    response = await authenticated_async_client.get(
        "/api/v1/web/hash_lists/999999/items"
    )

    assert response.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_list_hash_list_items_unauthorized(
    async_client: AsyncClient,
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test hash list items listing without authentication."""

    # Create test data
    project = await project_factory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    hash_list = await hash_list_factory.create_async(
        name="Test Hash List",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )

    response = await async_client.get(f"/api/v1/web/hash_lists/{hash_list.id}/items")

    assert response.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_list_hash_list_items_forbidden_project_access(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """Test hash list items listing without project access."""

    # Get authenticated client and user
    authenticated_async_client, user = authenticated_user_client

    # Create test data (but don't associate user with project)
    project = await project_factory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    hash_list = await hash_list_factory.create_async(
        name="Test Hash List",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )

    response = await authenticated_async_client.get(
        f"/api/v1/web/hash_lists/{hash_list.id}/items"
    )

    assert response.status_code == HTTPStatus.FORBIDDEN
