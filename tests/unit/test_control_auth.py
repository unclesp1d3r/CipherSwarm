"""Tests for Control API authentication functionality."""

from uuid import uuid4

from app.core.services.user_service import generate_api_key, generate_user_api_keys


def test_generate_api_key() -> None:
    """Test that generate_api_key creates a properly formatted key."""
    user_id = uuid4()
    api_key = generate_api_key(user_id)

    # Check format: cst_<user_id>_<random_string>
    assert api_key.startswith("cst_")
    parts = api_key.split("_")
    assert len(parts) == 3
    assert parts[0] == "cst"
    assert parts[1] == str(user_id)
    assert len(parts[2]) > 30  # Random part should be substantial


def test_generate_user_api_keys() -> None:
    """Test that generate_user_api_keys creates both full and readonly keys."""
    user_id = uuid4()
    api_key_full, api_key_readonly = generate_user_api_keys(user_id)

    # Both keys should be properly formatted
    assert api_key_full.startswith("cst_")
    assert api_key_readonly.startswith("cst_")

    # Both should contain the same user ID
    full_parts = api_key_full.split("_")
    readonly_parts = api_key_readonly.split("_")
    assert full_parts[1] == str(user_id)
    assert readonly_parts[1] == str(user_id)

    # Keys should be different
    assert api_key_full != api_key_readonly


def test_api_key_uniqueness() -> None:
    """Test that generated API keys are unique."""
    user_id = uuid4()
    key1 = generate_api_key(user_id)
    key2 = generate_api_key(user_id)

    # Even for the same user, keys should be unique
    assert key1 != key2
