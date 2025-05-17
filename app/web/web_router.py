from fastapi import APIRouter

from app.web.routes import agents, campaigns, dashboard

web_router = APIRouter()

# Include all web routes
web_router.include_router(agents.router)
web_router.include_router(dashboard.router)
web_router.include_router(campaigns.router)
# web_router.include_router(tasks.router)
# web_router.include_router(resources.router)

# Do NOT include API v1 web endpoints here; they are included via the main API router
