from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.attack_service import (
    AttackNotFoundError,
    InvalidAgentTokenError,
    InvalidUserAgentError,
    get_attack_config_service,
)
from app.schemas.attack import AttackOut

router = APIRouter()


@router.get(
    "/{attack_id}/config",
    status_code=status.HTTP_200_OK,
    summary="Fetch attack configuration",
    description="Fetch attack configuration by ID. Requires valid Authorization and User-Agent headers.",
)
async def get_attack_config(
    attack_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
    user_agent: Annotated[str, Header(..., alias="User-Agent")],
) -> AttackOut:
    try:
        attack = await get_attack_config_service(
            attack_id, db, authorization, user_agent
        )
        return AttackOut.model_validate(attack, from_attributes=True)
    except InvalidUserAgentError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except AttackNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
