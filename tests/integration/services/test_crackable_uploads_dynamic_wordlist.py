import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.tasks.crackable_uploads_tasks import (
    create_dynamic_wordlist_attack,
    extract_usernames_and_passwords_for_wordlist,
)
from app.models.attack import AttackMode
from app.models.raw_hash import RawHash
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory


@pytest.mark.asyncio
async def test_extract_usernames_and_passwords_for_wordlist() -> None:
    """Test extracting usernames and passwords for wordlist generation."""
    raw_hashes = [
        RawHash(
            id=1,
            hash="$6$salt$hash",
            hash_type_id=1800,
            username="testuser",
            meta=None,
            line_number=1,
            upload_task_id=1,
        ),
        RawHash(
            id=2,
            hash="$6$salt$anotherhash",
            hash_type_id=1800,
            username="admin",
            meta=None,
            line_number=2,
            upload_task_id=1,
        ),
        RawHash(
            id=3,
            hash="*",  # Invalid hash - should be skipped
            hash_type_id=1800,
            username="guest",
            meta=None,
            line_number=3,
            upload_task_id=1,
        ),
    ]

    wordlist = await extract_usernames_and_passwords_for_wordlist(raw_hashes)

    # Should include usernames and variations
    assert "testuser" in wordlist
    assert "admin" in wordlist

    # Should include common variations
    assert any(w.startswith("testuser") for w in wordlist)
    assert any(w.startswith("admin") for w in wordlist)

    # Should not include guest (has invalid hash)
    assert "guest" not in wordlist


@pytest.mark.asyncio
async def test_create_dynamic_wordlist_attack_with_usernames(
    db_session: AsyncSession,
) -> None:
    """Test creating a dynamic wordlist attack when usernames are available."""
    project = await ProjectFactory.create_async()
    hash_list = await HashListFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )

    raw_hashes = [
        RawHash(
            id=1,
            hash="$6$salt$hash",
            hash_type_id=1800,
            username="testuser",
            meta=None,
            line_number=1,
            upload_task_id=1,
        ),
    ]

    attack = await create_dynamic_wordlist_attack(campaign, raw_hashes, db_session)

    assert attack is not None
    assert attack.name == "Dynamic Dictionary (From Upload)"
    assert attack.attack_mode == AttackMode.DICTIONARY
    assert attack.campaign_id == campaign.id
    assert attack.word_list_id is not None


@pytest.mark.asyncio
async def test_create_dynamic_wordlist_attack_no_usernames(
    db_session: AsyncSession,
) -> None:
    """Test that no attack is created when no usernames are available."""
    project = await ProjectFactory.create_async()
    hash_list = await HashListFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )

    raw_hashes = [
        RawHash(
            id=1,
            hash="$6$salt$hash",
            hash_type_id=1800,
            username=None,  # No username
            meta=None,
            line_number=1,
            upload_task_id=1,
        ),
    ]

    attack = await create_dynamic_wordlist_attack(campaign, raw_hashes, db_session)

    assert attack is None
