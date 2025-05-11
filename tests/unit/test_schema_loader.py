from uuid import uuid4

import pytest

from app.schemas import schema_loader
from app.schemas.shared import AttackTemplate, CampaignTemplate


def test_validate_campaign_template_valid():
    data = {
        "schema_version": "20250511",
        "name": "Test Campaign",
        "description": "A test campaign",
        "attacks": [],
        "hash_list_id": 123,
    }
    result = schema_loader.validate_campaign_template(data)
    assert isinstance(result, CampaignTemplate)
    assert result.name == "Test Campaign"


def test_validate_campaign_template_invalid():
    data = {
        "name": 123,
        "attacks": [],
        "schema_version": "20250511",
        "hash_list_id": 1,
    }  # name should be str
    with pytest.raises(Exception):
        schema_loader.validate_campaign_template(data)


def test_validate_attack_template_valid():
    data = {
        "mode": "dictionary",
        "wordlist_guid": str(uuid4()),
        "rule_file": None,
        "min_length": 6,
        "max_length": 12,
        "masks": None,
        "wordlist_inline": None,
    }
    result = schema_loader.validate_attack_template(data)
    assert isinstance(result, AttackTemplate)
    assert result.mode == "dictionary"


def test_validate_attack_template_invalid():
    data = {
        "mode": 123,
        "wordlist_guid": None,
        "rule_file": None,
        "min_length": 1,
        "max_length": 2,
        "masks": None,
        "wordlist_inline": None,
    }  # mode should be str
    with pytest.raises(Exception):
        schema_loader.validate_attack_template(data)  # type: ignore[arg-type]  # negative test


def test_load_campaign_template():
    template = CampaignTemplate(
        schema_version="20250511",
        name="Import Campaign",
        description="desc",
        attacks=[],
        hash_list_id=42,
    )
    campaign = schema_loader.load_campaign_template(template, project_id=7)
    assert campaign.name == "Import Campaign"
    assert campaign.project_id == 7
    assert campaign.hash_list_id == 42


def test_load_attack_template():
    template = AttackTemplate(
        mode="dictionary",
        wordlist_guid=uuid4(),
        rule_file=None,
        min_length=6,
        max_length=12,
        masks=None,
        wordlist_inline=None,
    )
    attack = schema_loader.load_attack_template(
        template,
        campaign_id=5,
        hash_list_url="http://example.com/hashlist",
        hash_list_checksum="abc123",
    )
    assert attack.campaign_id == 5
    assert attack.attack_mode.value == "dictionary"
    assert attack.hash_list_url == "http://example.com/hashlist"
    assert attack.hash_list_checksum == "abc123"
