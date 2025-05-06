from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.logging import logger
from app.core.services.task_service import (
    InvalidAgentTokenError,
    NoPendingTasksError,
    assign_task_service,
)
from app.schemas.task import TaskOut

router = APIRouter()


@router.post(
    "/assign",
    status_code=status.HTTP_200_OK,
    summary="Assign a pending task to an agent",
    description="Assigns one pending task to the requesting agent. Requires valid Authorization and User-Agent headers.",
)
async def assign_task(
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
    user_agent: Annotated[str, Header(..., alias="User-Agent")],
) -> TaskOut:
    try:
        return await assign_task_service(db, authorization, user_agent)
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except NoPendingTasksError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except Exception as e:
        logger.exception("Task assignment failed (v1 endpoint)")
        raise HTTPException(status_code=500, detail="Internal server error") from e
