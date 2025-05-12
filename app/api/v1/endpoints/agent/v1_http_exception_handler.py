from fastapi import HTTPException, Request, Response, status
from fastapi.responses import JSONResponse


# --- V1 Error Envelope Handler ---
# To enable strict v1 error envelope compliance, register this handler on the main FastAPI app:
#   app.add_exception_handler(HTTPException, v1_http_exception_handler)
async def v1_http_exception_handler(request: Request, exc: Exception) -> Response:  # noqa: ARG001
    # Only handle HTTPException, otherwise re-raise
    if not isinstance(exc, HTTPException):
        raise exc
    if exc.status_code >= status.HTTP_400_BAD_REQUEST:
        detail = exc.detail
        if isinstance(detail, dict):
            # Return custom error object as-is (e.g., abandon returns {"state": [...]})
            return JSONResponse(status_code=exc.status_code, content=detail)
        # Otherwise, wrap in {"error": ...} for string or other types
        return JSONResponse(status_code=exc.status_code, content={"error": str(detail)})
    return JSONResponse(status_code=exc.status_code, content={"error": str(exc.detail)})
