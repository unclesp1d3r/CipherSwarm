"""
Agent API v2 middleware for error handling and request processing.

This middleware intercepts exceptions on Agent API v2 routes (/api/v2/client/*)
and converts them to standardized error responses following the v2 API specification.
"""

from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from typing import override

from fastapi import HTTPException, Request, Response, status
from fastapi.responses import JSONResponse
from loguru import logger
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.exceptions import (
    AgentAlreadyExistsError,
    AgentNotFoundError,
    InvalidAgentStateError,
    InvalidAgentTokenError,
    ResourceNotFoundError,
)


class AgentV2Middleware(BaseHTTPMiddleware):
    """Middleware that applies Agent API v2 error handling only to v2 agent routes."""

    @override
    async def dispatch(
        self, request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        """Process request and handle Agent API v2 exceptions with standardized format."""
        # Only apply v2 error handling to Agent API v2 routes
        if not request.url.path.startswith("/api/v2/client/"):
            return await call_next(request)

        # Set timestamp for error responses
        request.state.timestamp = datetime.now(UTC).isoformat()

        try:
            return await call_next(request)
        except (
            InvalidAgentTokenError,
            AgentNotFoundError,
            AgentAlreadyExistsError,
            InvalidAgentStateError,
            ResourceNotFoundError,
            HTTPException,
        ) as exc:
            return self._create_error_response(request, exc)
        except Exception:
            # Let other exceptions bubble up to be handled by existing handlers
            raise

    def _create_error_response(self, request: Request, exc: Exception) -> JSONResponse:
        """Create standardized error response for Agent API v2."""
        timestamp = getattr(request.state, "timestamp", None)

        # Define error mappings
        error_mappings = {
            InvalidAgentTokenError: (
                401,
                "authentication_failed",
                "Authentication failed.",
            ),
            AgentNotFoundError: (404, "agent_not_found", "Agent not found."),
            AgentAlreadyExistsError: (
                409,
                "agent_already_exists",
                "Agent already exists.",
            ),
            InvalidAgentStateError: (
                422,
                "invalid_agent_state",
                "Invalid agent state.",
            ),
            ResourceNotFoundError: (404, "resource_not_found", "Resource not found."),
        }

        # Handle custom exceptions
        for exc_type, (status_code, error_type, message) in error_mappings.items():
            if isinstance(exc, exc_type):
                logger.error(f"{exc_type.__name__}: {exc}")
                return self._build_json_response(
                    status_code, error_type, message, timestamp
                )

        # Handle HTTPExceptions
        if isinstance(exc, HTTPException):
            logger.error(f"HTTPException: {exc}")
            error_type = self._get_http_error_type(exc.status_code)
            return self._build_json_response(
                exc.status_code, error_type, "An error occurred.", timestamp
            )

        # Fallback (should not reach here with current exception handling)
        logger.error(f"Unexpected error: {exc}")
        return self._build_json_response(
            500, "internal_error", "Internal server error.", timestamp
        )

    def _get_http_error_type(self, status_code: int) -> str:
        """Get error type for HTTP status codes."""
        error_type_mapping = {
            status.HTTP_401_UNAUTHORIZED: "authentication_failed",
            status.HTTP_422_UNPROCESSABLE_ENTITY: "validation_error",
            status.HTTP_404_NOT_FOUND: "resource_not_found",
            status.HTTP_429_TOO_MANY_REQUESTS: "rate_limit_exceeded",
        }
        return error_type_mapping.get(status_code, "http_error")

    def _build_json_response(
        self, status_code: int, error_type: str, message: str, timestamp: str | None
    ) -> JSONResponse:
        """Build standardized JSON error response."""
        return JSONResponse(
            status_code=status_code,
            content={
                "error": error_type,
                "message": message,
                "details": None,
                "timestamp": timestamp,
            },
        )
