from fastapi import APIRouter

from app.api.v2.endpoints import client

api_router = APIRouter()
api_router.include_router(client.router, prefix="/client", tags=["Client"])
