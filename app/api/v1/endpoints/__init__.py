from .agents import router as agents
from .attacks import router as attacks
from .campaigns import router as campaigns
from .client_compat import router as client_compat
from .resources import router as resources
from .tasks import router as tasks
from .web_campaigns import web_campaigns

__all__ = [
    "agents",
    "attacks",
    "campaigns",
    "client_compat",
    "resources",
    "tasks",
    "web_campaigns",
]
