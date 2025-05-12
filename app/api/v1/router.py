from fastapi import APIRouter

from app.api.routes.auth import router as auth_router
from app.api.v1.endpoints.agent.router import router as agent_router
from app.api.v1.endpoints.control.router import router as control_router
from app.api.v1.endpoints.web.router import router as web_router

api_router = APIRouter()

# Include all endpoint routers
api_router.include_router(auth_router)
api_router.include_router(agent_router)
api_router.include_router(web_router)
api_router.include_router(control_router)
