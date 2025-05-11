from uuid import UUID

import pytest

from app.schemas import schema_loader
from app.schemas.shared import AttackTemplate, CampaignTemplate

TEST_PROJECT_ID = 7
TEST_HASH_LIST_ID = 42
TEST_CAMPAIGN_ID = 5


def test_validate_campaign_template_valid() -> None:
    data = {
        "schema_version": "20250511",
        "name": "Test Campaign",
        "description": "A test campaign",
        "attacks": [],
        "hash_list_id": TEST_HASH_LIST_ID,
    }
    result = schema_loader.validate_campaign_template(data)
    assert isinstance(result, CampaignTemplate)
    assert result.name == "Test Campaign"


def test_validate_campaign_template_invalid() -> None:
    data = {
        "name": 123,
        "attacks": [],
        "schema_version": "20250511",
        "hash_list_id": TEST_HASH_LIST_ID,
    }  # name should be str
    with pytest.raises(ValueError):
        schema_loader.validate_campaign_template(data)


def test_validate_attack_template_valid() -> None:
    data = {
        "mode": "dictionary",
        "wordlist_guid": str(UUID("f3b85a92-45c8-4e7d-a1cd-6042d0e2deef")),
        "rule_file": None,
        "min_length": 6,
        "max_length": 16,
        "masks": None,
        "wordlist_inline": None,
    }
    schema_loader.validate_attack_template(data)  # type: ignore[arg-type]


def test_validate_attack_template_invalid() -> None:
    data = {
        "mode": 123,
        "wordlist_guid": None,
        "rule_file": None,
        "min_length": 1,
        "max_length": 2,
        "masks": None,
        "wordlist_inline": None,
    }  # mode should be str
    with pytest.raises(ValueError):
        schema_loader.validate_attack_template(data)  # type: ignore[arg-type]  # negative test


def test_load_campaign_template() -> None:
    template = CampaignTemplate(
        schema_version="20250511",
        name="Import Campaign",
        description="desc",
        attacks=[],
        hash_list_id=TEST_HASH_LIST_ID,
    )
    campaign = schema_loader.load_campaign_template(
        template, project_id=TEST_PROJECT_ID
    )
    assert campaign.name == "Import Campaign"
    assert campaign.project_id == TEST_PROJECT_ID
    assert campaign.hash_list_id == TEST_HASH_LIST_ID


def test_load_attack_template() -> None:
    template = AttackTemplate(
        mode="dictionary",
        wordlist_guid=UUID("f3b85a92-45c8-4e7d-a1cd-6042d0e2deef"),
        rule_file=None,
        min_length=6,
        max_length=16,
        masks=None,
        wordlist_inline=None,
    )
    attack = schema_loader.load_attack_template(
        template,
        campaign_id=TEST_CAMPAIGN_ID,
        hash_list_url="http://example.com/hashlist",
        hash_list_checksum="abc123",
    )
    assert attack.campaign_id == TEST_CAMPAIGN_ID
    assert attack.attack_mode.value == "dictionary"
    assert attack.hash_list_url == "http://example.com/hashlist"
