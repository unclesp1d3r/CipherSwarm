"""
RFC9457 middleware for Control API routes only.

This middleware intercepts exceptions on Control API routes (/api/v1/control/*)
and converts them to RFC9457-compliant problem details responses.
"""

from collections.abc import Awaitable, Callable

from fastapi import Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.control_exceptions import (
    AgentNotFoundError,
    AttackNotFoundError,
    CampaignNotFoundError,
    HashItemNotFoundError,
    HashListNotFoundError,
    InsufficientPermissionsError,
    InvalidAttackConfigError,
    InvalidHashFormatError,
    InvalidResourceFormatError,
    ProjectAccessDeniedError,
    ProjectNotFoundError,
    ReadOnlyKeyError,
    ResourceNotFoundError,
    TaskNotFoundError,
    UserNotFoundError,
)


class ControlRFC9457Middleware(BaseHTTPMiddleware):
    """Middleware that applies RFC9457 error handling only to Control API routes."""

    async def dispatch(
        self, request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        """Process request and handle Control API exceptions with RFC9457 format."""
        # Only apply RFC9457 handling to Control API routes
        if not request.url.path.startswith("/api/v1/control/"):
            return await call_next(request)

        try:
            return await call_next(request)

        except (
            CampaignNotFoundError,
            AttackNotFoundError,
            AgentNotFoundError,
            HashListNotFoundError,
            HashItemNotFoundError,
            ResourceNotFoundError,
            UserNotFoundError,
            ProjectNotFoundError,
            TaskNotFoundError,
            InvalidAttackConfigError,
            InvalidHashFormatError,
            InvalidResourceFormatError,
            InsufficientPermissionsError,
            ProjectAccessDeniedError,
            ReadOnlyKeyError,
        ) as exc:
            # Convert custom exceptions to RFC9457 format
            return JSONResponse(
                status_code=exc.status_code,
                content={
                    "type": exc.type,
                    "title": exc.title,
                    "status": exc.status_code,
                    "detail": exc.detail,
                    "instance": str(request.url.path),
                },
                headers={"Content-Type": "application/problem+json"},
            )
        except Exception:
            # Let other exceptions bubble up to be handled by existing handlers
            raise
