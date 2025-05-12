from typing import Annotated

from fastapi import APIRouter, Form, HTTPException, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from app.core.services.hash_guess_service import HashGuessService

router = APIRouter()


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
