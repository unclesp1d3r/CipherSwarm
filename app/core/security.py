import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

from jose import jwt
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(
    schemes=["bcrypt"], deprecated="auto"
)  # TODO: Move to Argon2.

ALGORITHM = "HS256"
TOKEN_PARTS_COUNT = 3  # Number of parts in agent token: prefix_agent_id_hash


def create_access_token(
    subject: str | Any,  # noqa: ANN401
    expires_delta: timedelta | None = None,
) -> str:
    """Create a JWT access token."""
    now = datetime.now(UTC)
    expire = (
        now + expires_delta
        if expires_delta
        else now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )

    to_encode = {
        "exp": expire,
        "iat": now,  # issued at timestamp
        "jti": str(uuid.uuid4()),  # unique JWT ID for token uniqueness
        "sub": str(subject),
    }
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against a hash."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a password."""
    return pwd_context.hash(password)


class SecureTokenGenerator:
    """Cryptographically secure token generator for agent authentication."""

    @staticmethod
    def generate_agent_token(agent_id: int) -> str:
        """
        Generate a cryptographically secure agent token.

        Args:
            agent_id: The agent ID to include in the token

        Returns:
            A secure token in format: csa_{agent_id}_{hash}

        Raises:
            ValueError: If agent_id is invalid
        """
        if agent_id <= 0:
            raise ValueError("Agent ID must be a positive integer")

        # Generate cryptographically secure random bytes
        random_bytes = secrets.token_bytes(32)

        # Create a hash that includes both agent_id and random data
        # This ensures uniqueness and prevents token guessing
        token_data = f"{agent_id}:{random_bytes.hex()}"
        token_hash = hashlib.sha256(token_data.encode()).hexdigest()

        # Return token in format: csa_{agent_id}_{hash}
        return f"{settings.AGENT_V2_TOKEN_PREFIX}{agent_id}_{token_hash[: settings.AGENT_V2_TOKEN_LENGTH]}"

    @staticmethod
    def generate_temp_token() -> str:
        """
        Generate a temporary token for initial agent registration.

        Returns:
            A temporary token in format: csa_temp_{hash}
        """
        random_bytes = secrets.token_bytes(32)
        token_hash = hashlib.sha256(random_bytes).hexdigest()

        return f"{settings.AGENT_V2_TEMP_TOKEN_PREFIX}{token_hash[: settings.AGENT_V2_TOKEN_LENGTH]}"

    @staticmethod
    def validate_token_format(token: str) -> bool:
        """
        Validate token format for security.

        Args:
            token: The token to validate

        Returns:
            True if token format is valid, False otherwise
        """
        if not token:
            return False

        # Check if it's a regular agent token
        if token.startswith(settings.AGENT_V2_TOKEN_PREFIX):
            return SecureTokenGenerator._validate_agent_token(token)

        # Check if it's a temporary token
        if token.startswith(settings.AGENT_V2_TEMP_TOKEN_PREFIX):
            return SecureTokenGenerator._validate_temp_token(token)

        return False

    @staticmethod
    def _validate_agent_token(token: str) -> bool:
        """Validate regular agent token format."""
        parts = token.split("_")
        if len(parts) != TOKEN_PARTS_COUNT:
            return False

        try:
            agent_id = int(parts[1])
            if agent_id <= 0:
                return False

            # Check hash length and format
            hash_part = parts[2]
            return len(hash_part) == settings.AGENT_V2_TOKEN_LENGTH and all(
                c in "0123456789abcdef" for c in hash_part.lower()
            )
        except ValueError:
            return False

    @staticmethod
    def _validate_temp_token(token: str) -> bool:
        """Validate temporary token format."""
        hash_part = token[len(settings.AGENT_V2_TEMP_TOKEN_PREFIX) :]
        return len(hash_part) == settings.AGENT_V2_TOKEN_LENGTH and all(
            c in "0123456789abcdef" for c in hash_part.lower()
        )

    @staticmethod
    def extract_agent_id_from_token(token: str) -> int | None:
        """
        Extract agent ID from a valid token.

        Args:
            token: The token to extract agent ID from

        Returns:
            Agent ID if token is valid and contains an agent ID, None otherwise
        """
        if not SecureTokenGenerator.validate_token_format(token):
            return None

        if token.startswith(settings.AGENT_V2_TOKEN_PREFIX):
            parts = token.split("_")
            try:
                return int(parts[1])
            except (ValueError, IndexError):
                return None

        return None
