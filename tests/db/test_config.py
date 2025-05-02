"""Tests for database configuration."""

import os

import pytest
from pydantic import ValidationError

from app.db.config import DatabaseSettings


@pytest.fixture(autouse=True)
def clean_env():
    """Clean environment variables before each test."""
    old_environ = dict(os.environ)
    os.environ.clear()
    yield
    os.environ.clear()
    os.environ.update(old_environ)


def test_database_settings_required_url():
    """Test that database URL is required."""
    with pytest.raises(ValidationError):
        DatabaseSettings()


def test_database_settings_valid_url():
    """Test that valid database URL is accepted."""
    os.environ["DB_URL"] = "postgresql+asyncpg://user:pass@localhost:5432/dbname"
    settings = DatabaseSettings()
    assert str(settings.url) == "postgresql+asyncpg://user:pass@localhost:5432/dbname"


def test_database_settings_pool_size_validation():
    """Test pool size validation."""
    os.environ["DB_URL"] = "postgresql+asyncpg://user:pass@localhost:5432/dbname"

    os.environ["DB_POOL_SIZE"] = "0"  # Invalid: less than minimum (1)
    with pytest.raises(ValidationError):
        DatabaseSettings()

    os.environ["DB_POOL_SIZE"] = "21"  # Invalid: more than maximum (20)
    with pytest.raises(ValidationError):
        DatabaseSettings()

    os.environ["DB_POOL_SIZE"] = "5"  # Valid
    settings = DatabaseSettings()
    assert settings.pool_size == 5


def test_database_settings_defaults():
    """Test default values for optional settings."""
    os.environ["DB_URL"] = "postgresql+asyncpg://user:pass@localhost:5432/dbname"
    settings = DatabaseSettings()
    assert settings.pool_size == 5
    assert settings.max_overflow == 10
    assert settings.pool_timeout == 30
    assert settings.pool_recycle == 1800
    assert settings.echo is False
