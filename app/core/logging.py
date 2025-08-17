import re
import sys
from typing import Any

from loguru import logger

from app.core.config import settings

__all__ = ["logger"]

LOG_FORMAT = (
    "{time:YYYY-MM-DD HH:mm:ss} | {level} | {module}:{function}:{line} - {message}"
)

# Sensitive fields that should be redacted from logs
SENSITIVE_FIELDS = {
    "authorization",
    "authorization_header",
    "bearer_token",
    "token",
    "password",
    "secret",
    "api_key",
    "access_token",
    "refresh_token",
    "client_secret",
    "private_key",
    "session_token",
    "auth_token",
    "jwt_token",
    "oauth_token",
    "x_api_key",
    "x_auth_token",
    "x_session_token",
}

# Patterns for token-like values that should be redacted
TOKEN_PATTERNS = [
    r"Bearer\s+[a-zA-Z0-9._-]+",  # Bearer tokens
    r"csa_[a-zA-Z0-9._-]+",  # CipherSwarm agent tokens
    r"cst_[a-zA-Z0-9._-]+",  # CipherSwarm TUI tokens
    r"[a-zA-Z0-9]{32,}",  # Long alphanumeric strings (likely tokens)
]


def redact_sensitive_data(record: dict[str, Any]) -> dict[str, Any]:
    """
    Redact sensitive data from log records.

    This function processes the 'extra' field of log records to remove or redact
    sensitive information like authorization headers, tokens, and other credentials.
    """
    if "extra" not in record:
        return record

    extra = record["extra"].copy()

    # Redact sensitive field names
    for field_name in list(extra.keys()):
        field_lower = field_name.lower()
        if any(sensitive in field_lower for sensitive in SENSITIVE_FIELDS):
            extra[field_name] = "[REDACTED]"

    # Redact sensitive values in dictionaries
    def redact_dict_values(data: object) -> object:
        if isinstance(data, dict):
            redacted = {}
            for key, value in data.items():
                key_lower = str(key).lower()
                if any(sensitive in key_lower for sensitive in SENSITIVE_FIELDS):
                    redacted[key] = "[REDACTED]"
                elif isinstance(value, (dict, list)):
                    redacted[key] = redact_dict_values(value)
                elif isinstance(value, str):
                    # Check for token patterns in string values
                    redacted_value = value
                    for pattern in TOKEN_PATTERNS:
                        redacted_value = re.sub(pattern, "[REDACTED]", redacted_value)
                    redacted[key] = redacted_value
                else:
                    redacted[key] = value
            return redacted
        if isinstance(data, list):
            return [redact_dict_values(item) for item in data]
        return data

    # Process all extra fields
    for key, value in extra.items():
        extra[key] = redact_dict_values(value)

    record["extra"] = extra
    return record


logger.remove()
logger.add(
    sys.stderr,
    level=settings.log_level,
    format=LOG_FORMAT,
    enqueue=True,
    backtrace=True,
    diagnose=True,
    filter=lambda record: redact_sensitive_data(record),
)

if settings.log_to_file:
    logger.add(
        settings.log_file_path,
        level=settings.log_level,
        format=LOG_FORMAT,
        rotation=settings.log_rotation,
        retention=settings.log_retention,
        enqueue=True,
        backtrace=True,
        diagnose=True,
        filter=lambda record: redact_sensitive_data(record),
    )
