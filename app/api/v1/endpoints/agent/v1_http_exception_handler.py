from fastapi import HTTPException, Request, Response, status
from fastapi.exception_handlers import http_exception_handler
from fastapi.responses import JSONResponse


# --- V1 Error Envelope Handler ---
# To enable strict v1 error envelope compliance, register this handler on the main FastAPI app for all /api/v1/client/* and /api/v1/agent/* endpoints.
async def v1_http_exception_handler(request: Request, exc: Exception) -> Response:
    # Only handle HTTPException, otherwise re-raise
    if not isinstance(exc, HTTPException):
        raise exc

    # Handle v2 routes with v2 error format
    if request.url.path.startswith("/api/v2/client/"):
        from datetime import UTC, datetime

        # Map status codes to error types
        if exc.status_code == status.HTTP_401_UNAUTHORIZED:
            error_type = "authentication_failed"
        elif exc.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY:
            error_type = "validation_error"
        elif exc.status_code == status.HTTP_404_NOT_FOUND:
            error_type = "resource_not_found"
        elif exc.status_code == status.HTTP_429_TOO_MANY_REQUESTS:
            error_type = "rate_limit_exceeded"
        else:
            error_type = "http_error"

        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": error_type,
                "message": exc.detail,
                "details": None,
                "timestamp": datetime.now(UTC).isoformat(),
            },
        )

    if not request.url.path.startswith(
        "/api/v1/agent/"
    ) and not request.url.path.startswith("/api/v1/client/"):
        return await http_exception_handler(request, exc)

    if exc.status_code >= status.HTTP_400_BAD_REQUEST:
        detail = exc.detail
        if isinstance(detail, dict):
            # Return custom error object as-is (e.g., abandon returns {"state": [...]})
            return JSONResponse(status_code=exc.status_code, content=detail)
        # Otherwise, wrap in {"error": ...} for string or other types
        return JSONResponse(status_code=exc.status_code, content={"error": str(detail)})
    return JSONResponse(status_code=exc.status_code, content={"error": str(exc.detail)})
