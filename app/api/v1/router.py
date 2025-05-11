from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import JSONResponse, Response
from starlette.status import HTTP_400_BAD_REQUEST

from app.api.routes import auth
from app.api.v1.endpoints import (
    client_compat,
    control_hash_guess_router,
    resources,
    tasks,
    web_hash_guess_router,
)
from app.api.v1.endpoints.agent.agent import router as agent_router
from app.api.v1.endpoints.users import users_router

api_router = APIRouter()

# Include all endpoint routers
api_router.include_router(agent_router, prefix="/agents", tags=["Agents"])
api_router.include_router(resources, prefix="/resources", tags=["Resources"])
api_router.include_router(tasks, prefix="/tasks", tags=["Tasks"])
api_router.include_router(client_compat, prefix="/client", tags=["Client (Compat)"])
api_router.include_router(users_router, prefix="/web")
api_router.include_router(auth.router)
api_router.include_router(web_hash_guess_router, prefix="/web", tags=["Hash Guessing"])
api_router.include_router(
    control_hash_guess_router, prefix="/control", tags=["Hash Guessing"]
)


# --- V1 Error Envelope Handler ---
# To enable strict v1 error envelope compliance, register this handler on the main FastAPI app:
#   app.add_exception_handler(HTTPException, v1_http_exception_handler)
async def v1_http_exception_handler(request: Request, exc: Exception) -> Response:  # noqa: ARG001
    # Only handle HTTPException, otherwise re-raise
    if not isinstance(exc, HTTPException):
        raise exc
    if exc.status_code >= HTTP_400_BAD_REQUEST:
        detail = exc.detail
        if isinstance(detail, dict):
            # Return custom error object as-is (e.g., abandon returns {"state": [...]})
            return JSONResponse(status_code=exc.status_code, content=detail)
        # Otherwise, wrap in {"error": ...} for string or other types
        return JSONResponse(status_code=exc.status_code, content={"error": str(detail)})
    return JSONResponse(status_code=exc.status_code, content={"error": str(exc.detail)})
