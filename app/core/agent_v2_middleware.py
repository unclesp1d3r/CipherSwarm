"""
Agent API v2 middleware for error handling and request processing.

This middleware intercepts exceptions on Agent API v2 routes (/api/v2/client/*)
and converts them to standardized error responses following the v2 API specification.
"""

from collections.abc import Awaitable, Callable
from datetime import UTC

from fastapi import HTTPException, Request, Response
from fastapi.responses import JSONResponse
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

    async def dispatch(
        self, request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        """Process request and handle Agent API v2 exceptions with standardized format."""
        # Only apply v2 error handling to Agent API v2 routes
        if not request.url.path.startswith("/api/v2/client/"):
            return await call_next(request)

        # Set timestamp for error responses
        from datetime import datetime

        request.state.timestamp = datetime.now(UTC).isoformat()

        try:
            return await call_next(request)

        except InvalidAgentTokenError as exc:
            return JSONResponse(
                status_code=401,
                content={
                    "error": "authentication_failed",
                    "message": str(exc),
                    "details": None,
                    "timestamp": (
                        request.state.timestamp
                        if hasattr(request.state, "timestamp")
                        else None
                    ),
                },
            )

        except AgentNotFoundError as exc:
            return JSONResponse(
                status_code=404,
                content={
                    "error": "agent_not_found",
                    "message": str(exc),
                    "details": None,
                    "timestamp": (
                        request.state.timestamp
                        if hasattr(request.state, "timestamp")
                        else None
                    ),
                },
            )

        except AgentAlreadyExistsError as exc:
            return JSONResponse(
                status_code=409,
                content={
                    "error": "agent_already_exists",
                    "message": str(exc),
                    "details": None,
                    "timestamp": (
                        request.state.timestamp
                        if hasattr(request.state, "timestamp")
                        else None
                    ),
                },
            )

        except InvalidAgentStateError as exc:
            return JSONResponse(
                status_code=422,
                content={
                    "error": "invalid_agent_state",
                    "message": str(exc),
                    "details": None,
                    "timestamp": (
                        request.state.timestamp
                        if hasattr(request.state, "timestamp")
                        else None
                    ),
                },
            )

        except ResourceNotFoundError as exc:
            return JSONResponse(
                status_code=404,
                content={
                    "error": "resource_not_found",
                    "message": str(exc),
                    "details": None,
                    "timestamp": (
                        request.state.timestamp
                        if hasattr(request.state, "timestamp")
                        else None
                    ),
                },
            )

        except HTTPException as exc:
            # Handle FastAPI HTTPExceptions with v2 format
            if exc.status_code == 401:
                error_type = "authentication_failed"
            elif exc.status_code == 422:
                error_type = "validation_error"
            elif exc.status_code == 404:
                error_type = "resource_not_found"
            elif exc.status_code == 429:
                error_type = "rate_limit_exceeded"
            else:
                error_type = "http_error"

            return JSONResponse(
                status_code=exc.status_code,
                content={
                    "error": error_type,
                    "message": exc.detail,
                    "details": None,
                    "timestamp": (
                        request.state.timestamp
                        if hasattr(request.state, "timestamp")
                        else None
                    ),
                },
            )

        except Exception:
            # Let other exceptions bubble up to be handled by existing handlers
            raise
