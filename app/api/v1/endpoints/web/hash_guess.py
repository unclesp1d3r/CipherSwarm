from typing import Annotated

from fastapi import APIRouter, HTTPException, status
from fastapi.params import Body
from pydantic import BaseModel

from app.core.services.hash_guess_service import HashGuessService
from app.schemas.shared import HashGuessCandidate

router = APIRouter()


class HashGuessRequest(BaseModel):
    """Request body for the hash guess endpoint."""

    hash_material: Annotated[
        str,
        Body(
            description="Pasted hash lines or blob",
            media_type="text/plain",
            example="5f4dcc3b5aa765d61d8327deb882cf99",
            min_length=1,
        ),
    ]


class HashGuessResults(BaseModel):
    candidates: list[HashGuessCandidate]


# /api/v1/web/hash_guess
@router.post(
    "/hash_guess",
    summary="Guess hash types from provided hash material",
)
async def guess_hash_types_web(
    data: HashGuessRequest,
) -> HashGuessResults:
    """
    Accepts hash material and returns ranked hash type candidates for the Web UI.
    """
    try:
        return HashGuessResults(
            candidates=HashGuessService.guess_hash_types(data.hash_material)
        )

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
