from fastapi import APIRouter

from app.api.v1.endpoints.web.attacks import router as attacks_router
from app.api.v1.endpoints.web.auth import router as auth_router
from app.api.v1.endpoints.web.campaigns import router as campaigns_router
from app.api.v1.endpoints.web.hash_guess import router as hash_guess_router
from app.api.v1.endpoints.web.live import router as live_router
from app.api.v1.endpoints.web.modals import router as modals_router
from app.api.v1.endpoints.web.projects import router as projects_router
from app.api.v1.endpoints.web.resources import router as resources_router
from app.api.v1.endpoints.web.users import router as users_router

from . import templates

router = APIRouter(prefix="/web", tags=["Web"])

router.include_router(attacks_router)
router.include_router(campaigns_router)
router.include_router(hash_guess_router)
router.include_router(projects_router)
router.include_router(users_router)
router.include_router(resources_router)
router.include_router(live_router)
router.include_router(modals_router)
router.include_router(templates.router)
router.include_router(auth_router)
