from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from app.core.services.hash_guess_service import HashGuessService

router = APIRouter()


class HashGuessRequest(BaseModel):
    hash_material: str = Field(..., description="Pasted hash lines or blob")


class HashGuessResponse(BaseModel):
    candidates: list[dict[str, object]] = Field(
        ..., description="Ranked hash type candidates"
    )


# /api/v1/control/hash_guess
@router.post(
    "/hash_guess",
    summary="Guess hash types from pasted material",
    tags=["Hash Guessing"],
)
async def guess_hash_types_control(data: HashGuessRequest) -> HashGuessResponse:
    """
    Accepts pasted hash material and returns ranked hash type candidates for the Control API (JSON response).
    """
    try:
        candidates = HashGuessService.guess_hash_types(data.hash_material)
        return HashGuessResponse(candidates=[c.to_dict() for c in candidates])
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
