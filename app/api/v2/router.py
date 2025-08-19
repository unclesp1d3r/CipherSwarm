from fastapi import APIRouter

from app.api.v2.endpoints.agents import router as agents_router
from app.api.v2.endpoints.attacks import router as attacks_router
from app.api.v2.endpoints.resources import router as resources_router
from app.api.v2.endpoints.tasks import router as tasks_router

api_router = APIRouter(
    tags=["Agent API v2"],
    responses={
        401: {
            "description": "Authentication failed",
            "content": {
                "application/json": {
                    "example": {
                        "error": "authentication_failed",
                        "message": "Invalid agent token",
                        "details": None,
                        "timestamp": "2024-01-01T00:00:00Z",
                    }
                }
            },
        },
        422: {
            "description": "Validation error",
            "content": {
                "application/json": {
                    "example": {
                        "error": "validation_error",
                        "message": "Invalid request data",
                        "details": None,
                        "timestamp": "2024-01-01T00:00:00Z",
                    }
                }
            },
        },
        429: {
            "description": "Rate limit exceeded",
            "content": {
                "application/json": {
                    "example": {
                        "error": "rate_limit_exceeded",
                        "message": "Too many requests",
                        "details": {"retry_after": 15},
                        "timestamp": "2024-01-01T00:00:00Z",
                    }
                }
            },
        },
        500: {
            "description": "Internal server error",
            "content": {
                "application/json": {
                    "example": {
                        "error": "internal_server_error",
                        "message": "An unexpected error occurred",
                        "details": None,
                        "timestamp": "2024-01-01T00:00:00Z",
                    }
                }
            },
        },
    },
)

# Include all v2 endpoint routers
api_router.include_router(agents_router)
api_router.include_router(tasks_router)
api_router.include_router(resources_router)
api_router.include_router(attacks_router)
