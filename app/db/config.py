"""Database configuration module."""

from pydantic import Field, PostgresDsn, ValidationInfo, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class DatabaseSettings(BaseSettings):
    """Database configuration settings.

    This class manages all database-related configuration settings, using environment
    variables with the DB_ prefix. For example, DB_URL for the database URL.

    Attributes:
        url: Database connection URL in PostgreSQL format
        pool_size: Size of the connection pool
        max_overflow: Maximum number of connections that can be created beyond pool_size
        pool_timeout: Number of seconds to wait before giving up on getting a connection
        pool_recycle: Number of seconds after which a connection is recycled
        echo: Whether to log all SQL statements (development only)
    """

    model_config = SettingsConfigDict(env_prefix="DB_")

    url: PostgresDsn
    pool_size: int = Field(default=5, ge=1, le=20)
    max_overflow: int = Field(default=10, ge=0)
    pool_timeout: int = Field(default=30, ge=0)
    pool_recycle: int = Field(default=1800, ge=-1)
    echo: bool = Field(default=False)

    @field_validator("pool_size", "max_overflow", "pool_timeout", "pool_recycle")
    @classmethod
    def validate_pool_settings(cls, value: int, info: ValidationInfo) -> int:
        """Validate pool settings.

        Args:
            value: The value to validate
            info: Validation context information

        Returns:
            int: The validated value

        Notes:
            Pool settings are only validated for non-SQLite databases.
        """
        # Get the URL from the validation context
        data = info.data
        if "url" in data and str(data["url"]).startswith("sqlite"):
            return value  # Skip validation for SQLite

        field_name = info.field_name
        if field_name == "pool_size" and (value < 1 or value > 20):
            raise ValueError("pool_size must be between 1 and 20")
        if field_name == "max_overflow" and value < 0:
            raise ValueError("max_overflow must be greater than or equal to 0")
        if field_name == "pool_timeout" and value < 0:
            raise ValueError("pool_timeout must be greater than or equal to 0")
        if field_name == "pool_recycle" and value < -1:
            raise ValueError("pool_recycle must be greater than or equal to -1")

        return value
