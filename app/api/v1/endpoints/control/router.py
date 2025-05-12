from fastapi import APIRouter

from app.api.v1.endpoints.control.hash_guess import router as hash_guess_router

router = APIRouter(prefix="/control", tags=["Control"])

router.include_router(hash_guess_router)
