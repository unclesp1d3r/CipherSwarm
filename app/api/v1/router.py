from fastapi import APIRouter

from app.api.v1.endpoints import agents, attacks, client, tasks

api_router = APIRouter()

# Include all endpoint routers
api_router.include_router(agents.router, prefix="/agents", tags=["Agents"])
api_router.include_router(attacks.router, prefix="/attacks", tags=["Attacks"])
api_router.include_router(tasks.router, prefix="/tasks", tags=["Tasks"])
api_router.include_router(client.router, prefix="/client", tags=["Client"])
