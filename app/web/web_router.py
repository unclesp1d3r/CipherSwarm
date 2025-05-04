from fastapi import APIRouter

from app.web.routes import agents, dashboard  # , resources, tasks

web_router = APIRouter()

# Include all web routes
web_router.include_router(agents.router)
web_router.include_router(dashboard.router)
# web_router.include_router(tasks.router)
# web_router.include_router(resources.router)
