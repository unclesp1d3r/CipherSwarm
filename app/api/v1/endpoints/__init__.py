from .campaigns import router as campaigns
from .client_compat import router as client_compat
from .resources import router as resources
from .tasks import router as tasks

__all__ = [
    "campaigns",
    "client_compat",
    "resources",
    "tasks",
]
