from fastapi import APIRouter

from app.api.v1.endpoints import (
    agents,
    attacks,
    campaigns,
    client_compat,
    resources,
    tasks,
    web_campaigns,
)

api_router = APIRouter()

# Include all endpoint routers
api_router.include_router(agents, prefix="/agents", tags=["Agents"])
api_router.include_router(attacks, prefix="/attacks", tags=["Attacks"])
api_router.include_router(resources, prefix="/resources", tags=["Resources"])
api_router.include_router(tasks, prefix="/tasks", tags=["Tasks"])
api_router.include_router(client_compat, prefix="/client", tags=["Client (Compat)"])
api_router.include_router(campaigns, prefix="/campaigns", tags=["Campaigns"])
api_router.include_router(web_campaigns, tags=["Web Campaigns"])

# Note: The client router is now only available in v2. v1 uses only the compatibility layer for legacy endpoints.
