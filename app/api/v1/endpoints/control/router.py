from fastapi import APIRouter

from app.api.v1.endpoints.control.campaigns import router as campaigns_router
from app.api.v1.endpoints.control.hash_guess import router as hash_guess_router

router = APIRouter(prefix="/control", tags=["Control"])

# Note: RFC9457 error handling is implemented via custom exception classes
# that inherit from fastapi_problem.error base classes. These are automatically
# handled by the fastapi-problem library when raised in endpoints.

router.include_router(campaigns_router)
router.include_router(hash_guess_router)
