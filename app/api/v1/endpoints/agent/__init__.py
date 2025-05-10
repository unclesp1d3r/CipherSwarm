from .agent import router as agent_router
from .attacks import router as attacks_router
from .crackers import router as crackers_router
from .general import router as general_router
from .tasks import router as tasks_router

__all__ = [
    "agent_router",
    "attacks_router",
    "crackers_router",
    "general_router",
    "tasks_router",
]
