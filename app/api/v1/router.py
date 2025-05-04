from fastapi import APIRouter

from app.api.v1.endpoints import (
    agents,
    attacks,
    campaigns,
    client_compat,
    resources,
    tasks,
)

api_router = APIRouter()

# Include all endpoint routers
api_router.include_router(agents.router, prefix="/agents", tags=["Agents"])
api_router.include_router(attacks.router, prefix="/attacks", tags=["Attacks"])
api_router.include_router(resources.router, prefix="/resources", tags=["Resources"])
api_router.include_router(tasks.router, prefix="/tasks", tags=["Tasks"])
api_router.include_router(
    client_compat.router, prefix="/client", tags=["Client (Compat)"]
)
api_router.include_router(campaigns.router, prefix="/campaigns", tags=["Campaigns"])

# Note: The client router is now only available in v2. v1 uses only the compatibility layer for legacy endpoints.
