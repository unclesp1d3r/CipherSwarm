from typing import Annotated

from fastapi import APIRouter, Form, HTTPException, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from app.core.services.hash_guess_service import HashGuessService

router = APIRouter()

"""
Rules to follow:
1. This endpoint MUST return a Pydantic response model via FastAPI.
2. DO NOT return TemplateResponse or render HTML fragments — this is a pure JSON API.
3. DO NOT include database logic — delegate to a service layer (e.g. campaign_service).
4. All request context (user, project, etc.) MUST come from DI dependencies — not request.query_params.
5. Use idiomatic FastAPI parameter handling — validate with Query(), Path(), Body(), Form(), etc.
6. Authorization checks are implemented — use user_can() instead of TODO comments.
7. Use Pydantic models for all input (query, body) and output (response).
8. Keep endpoints thin: only transform data, call service, and return results.
"""


class HashGuessRequest(BaseModel):
    hash_material: str = Field(..., description="Pasted hash lines or blob")


# /api/v1/web/hash_guess
@router.post(
    "/hash_guess",
    summary="Guess hash types from pasted material",
)
async def guess_hash_types_web(
    hash_material: Annotated[str, Form(...)],
) -> JSONResponse:
    """
    Accepts pasted hash material and returns ranked hash type candidates for the Web UI (HTMX-friendly JSON).
    """
    try:
        candidates = HashGuessService.guess_hash_types(hash_material)
        return JSONResponse({"candidates": [c.to_dict() for c in candidates]})
    except ImportError as err:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="name-that-hash is not installed",
        ) from err
    except ValueError as err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(err),
        ) from err
