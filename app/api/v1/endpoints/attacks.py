from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.attack_service import (
    AttackNotFoundError,
    InvalidAgentTokenError,
    get_attack_config_service,
)
from app.schemas.attack import AttackOut

router = APIRouter()


@router.get(
    "/{attack_id}/config",
    summary="Fetch attack configuration by ID",
    description="Fetch attack configuration by ID. Requires valid Authorization.",
)
async def get_attack_config(
    attack_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str | None, Header(alias="Authorization")] = None,
) -> AttackOut:
    if not isinstance(authorization, str) or not authorization:
        raise HTTPException(
            status_code=401, detail="Missing or invalid Authorization header"
        )
    try:
        attack = await get_attack_config_service(attack_id, db, authorization)
        return AttackOut.model_validate(attack, from_attributes=True)
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except AttackNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e
