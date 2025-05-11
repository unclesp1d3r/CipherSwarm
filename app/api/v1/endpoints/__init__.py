from .campaigns import router as campaigns
from .client_compat import router as client_compat
from .control import hash_guess_router as control_hash_guess_router
from .resources import router as resources
from .tasks import router as tasks
from .web import hash_guess_router as web_hash_guess_router

__all__ = [
    "campaigns",
    "client_compat",
    "control_hash_guess_router",
    "resources",
    "tasks",
    "web_hash_guess_router",
]
