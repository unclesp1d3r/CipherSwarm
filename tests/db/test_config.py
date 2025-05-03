"""Tests for database configuration."""

import os
from collections.abc import Generator

import pytest
from pydantic import ValidationError

from app.db.config import DatabaseSettings

# Constants for default config values
DEFAULT_POOL_SIZE = 5
DEFAULT_MAX_OVERFLOW = 10
DEFAULT_POOL_TIMEOUT = 30
DEFAULT_POOL_RECYCLE = 1800


@pytest.fixture(autouse=True)
def clean_env() -> Generator[None]:
    """Clean environment variables before each test."""
    old_environ = dict(os.environ)
    os.environ.clear()
    yield
    os.environ.clear()
    os.environ.update(old_environ)


def test_database_settings_required_url() -> None:
    """Test that database URL is required."""
    with pytest.raises(ValidationError):
        DatabaseSettings()


def test_database_settings_valid_url() -> None:
    """Test that valid database URL is accepted."""
    os.environ["DB_URL"] = "postgresql+asyncpg://user:pass@localhost:5432/dbname"
    settings = DatabaseSettings()
    assert str(settings.url) == "postgresql+asyncpg://user:pass@localhost:5432/dbname"


def test_database_settings_pool_size_validation() -> None:
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
    assert settings.pool_size == DEFAULT_POOL_SIZE


def test_database_settings_defaults() -> None:
    """Test default values for optional settings."""
    os.environ["DB_URL"] = "postgresql+asyncpg://user:pass@localhost:5432/dbname"
    settings = DatabaseSettings()
    assert settings.pool_size == DEFAULT_POOL_SIZE
    assert settings.max_overflow == DEFAULT_MAX_OVERFLOW
    assert settings.pool_timeout == DEFAULT_POOL_TIMEOUT
    assert settings.pool_recycle == DEFAULT_POOL_RECYCLE
    assert settings.echo is False
