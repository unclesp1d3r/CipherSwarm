"""Core configuration module."""

from pydantic import AnyHttpUrl, Field, PostgresDsn
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings.

    Attributes:
        PROJECT_NAME: Name of the project
        VERSION: Project version
        API_V1_STR: API version 1 prefix
        BACKEND_CORS_ORIGINS: List of origins that can access the API
        SECRET_KEY: Secret key for JWT tokens
        POSTGRES_SERVER: PostgreSQL server hostname
        POSTGRES_USER: PostgreSQL username
        POSTGRES_PASSWORD: PostgreSQL password
        POSTGRES_DB: PostgreSQL database name
        sqlalchemy_database_uri: SQLAlchemy database URI
        FIRST_SUPERUSER: First superuser email
        FIRST_SUPERUSER_PASSWORD: First superuser password
        REDIS_HOST: Redis server hostname
        REDIS_PORT: Redis server port
        CELERY_BROKER_URL: Celery broker URL
        CELERY_RESULT_BACKEND: Celery result backend URL
        HASHCAT_BINARY_PATH: Path to hashcat binary
        DEFAULT_WORKLOAD_PROFILE: Default hashcat workload profile
        ENABLE_ADDITIONAL_HASH_TYPES: Enable additional hash types
        ACCESS_TOKEN_EXPIRE_MINUTES: JWT access token expiration time in minutes
    """

    PROJECT_NAME: str = "CipherSwarm"
    VERSION: str = "0.1.0"
    API_V1_STR: str = "/api/v1"
    BACKEND_CORS_ORIGINS: list[AnyHttpUrl] = Field(
        default_factory=list,
        description="List of origins that can access the API",
    )

    # Security
    SECRET_KEY: str = Field(
        default="k5moVLqLGy82D4FE54VvkkqAyxe6XF6k",
        description="Secret key for JWT tokens",
    )
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(
        default=60,
        description="JWT access token expiration time in minutes",
    )

    # Database
    POSTGRES_SERVER: str = Field(
        default="localhost",
        description="PostgreSQL server hostname",
    )
    POSTGRES_USER: str = Field(
        default="cipherswarm",
        description="PostgreSQL username",
    )
    POSTGRES_PASSWORD: str = Field(
        default="cipherswarm",
        description="PostgreSQL password",
    )
    POSTGRES_DB: str = Field(
        default="cipherswarm",
        description="PostgreSQL database name",
    )

    # Users
    FIRST_SUPERUSER: str = Field(
        default="admin@cipherswarm.org",
        description="First superuser email",
    )
    FIRST_SUPERUSER_PASSWORD: str = Field(
        default="cipherswarm",
        description="First superuser password",
    )

    # Redis
    REDIS_HOST: str = Field(
        default="localhost",
        description="Redis server hostname",
    )
    REDIS_PORT: int = Field(
        default=6379,
        description="Redis server port",
    )

    # Celery
    CELERY_BROKER_URL: str = Field(
        default="redis://localhost:6379/0",
        description="Celery broker URL",
    )
    CELERY_RESULT_BACKEND: str = Field(
        default="redis://localhost:6379/0",
        description="Celery result backend URL",
    )

    # Hashcat Settings
    HASHCAT_BINARY_PATH: str = Field(
        default="hashcat",
        description="Path to hashcat binary",
    )
    DEFAULT_WORKLOAD_PROFILE: int = Field(
        default=3,
        description="Default hashcat workload profile",
    )
    ENABLE_ADDITIONAL_HASH_TYPES: bool = Field(
        default=False,
        description="Enable additional hash types",
    )

    # Logging
    log_level: str = Field(default="INFO", description="Log level for loguru")
    log_to_file: bool = Field(default=False, description="Enable file logging")
    log_file_path: str = Field(default="logs/app.log", description="Path to log file")
    log_retention: str = Field(
        default="10 days", description="Log file retention policy"
    )
    log_rotation: str = Field(default="10 MB", description="Log file rotation policy")

    @property
    def sqlalchemy_database_uri(self) -> PostgresDsn:
        """Get the SQLAlchemy database URI.

        Returns:
            PostgresDsn: Database URI
        """
        return PostgresDsn.build(
            scheme="postgresql+asyncpg",
            username=self.POSTGRES_USER,
            password=self.POSTGRES_PASSWORD,
            host=self.POSTGRES_SERVER,
            path=self.POSTGRES_DB,
        )

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )


settings = Settings()
