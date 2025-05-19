from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Path, status
from fastapi.responses import PlainTextResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.attack_service import (
    AttackNotFoundError,
    InvalidAgentTokenError,
    get_attack_config_service,
)
from app.models.hash_list import HashList
from app.schemas.attack import AttackOutV1

router = APIRouter(prefix="/client/attacks", tags=["Attacks"])


@router.get(
    "/{id}",
    summary="Get attack by ID (v1 agent API)",
    description="Returns an attack by id. This is used to get the details of an attack.",
    tags=["Attacks"],
)
async def get_attack_v1(
    id: Annotated[int, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> AttackOutV1:
    try:
        attack = await get_attack_config_service(id, db, authorization)
        return AttackOutV1.model_validate(attack, from_attributes=True)
    except InvalidAgentTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        ) from e
    except AttackNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@router.get(
    "/{id}/hash_list",
    summary="Get the hash list for an attack (v1 agent API)",
    description="Returns the hash list for an attack as a text file. Each line is a hash value. Requires agent authentication.",
    tags=["Attacks"],
    response_class=PlainTextResponse,
    responses={
        status.HTTP_200_OK: {"content": {"text/plain": {}}},
        status.HTTP_404_NOT_FOUND: {"description": "Record not found"},
        status.HTTP_401_UNAUTHORIZED: {"description": "Unauthorized"},
        status.HTTP_403_FORBIDDEN: {"description": "Forbidden"},
    },
)
async def get_attack_hash_list_v1(
    id: Annotated[int, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> PlainTextResponse:
    try:
        attack = await get_attack_config_service(id, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        ) from e
    except AttackNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    except PermissionError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e

    # Fetch the hash list
    hash_list_id = getattr(attack, "hash_list_id", None)
    if not hash_list_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
        )
    result = await db.execute(select(HashList).where(HashList.id == hash_list_id))
    hash_list = result.scalar_one_or_none()
    if not hash_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
        )
    # Get all hashes (one per line)
    hashes = [item.hash for item in hash_list.items]
    content = "\n".join(hashes)
    return PlainTextResponse(content, status_code=status.HTTP_200_OK)
