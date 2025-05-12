from fastapi import APIRouter

from .agent import router as agent_router
from .attacks import router as attacks_router
from .crackers import router as crackers_router
from .general import router as general_router
from .tasks import router as tasks_router

router = APIRouter(prefix="/client", tags=["Client"])
router.include_router(agent_router)
router.include_router(attacks_router)
router.include_router(tasks_router)
router.include_router(crackers_router)
router.include_router(general_router)
