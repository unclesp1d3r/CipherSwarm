from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_agent, get_current_agent_v1, get_db
from app.core.services.agent_service import (
    AgentForbiddenError,
    AgentNotFoundError,
    get_agent_service,
    send_heartbeat_service,
    shutdown_agent_service,
    submit_benchmark_service,
    submit_error_service,
    update_agent_service,
)
from app.models.agent import Agent
from app.schemas.agent import (
    AgentBenchmark,
    AgentErrorV1,
    AgentResponseV1,
    AgentUpdateV1,
)

router = APIRouter()


@router.get(
    "/{agent_id}",
    summary="Get agent by ID",
    description="Get agent by ID. Requires agent authentication.",
)
async def get_agent(
    agent_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v1)],
) -> AgentResponseV1:
    try:
        agent = await get_agent_service(agent_id, current_agent, db)
        return AgentResponseV1.model_validate(agent, from_attributes=True)
    except AgentForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e)) from e
    except AgentNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@router.put(
    "/{agent_id}",
    summary="Update agent",
    description="Update agent. Requires agent authentication.",
)
async def update_agent(
    agent_id: int,
    agent_update: AgentUpdateV1,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent)],
) -> AgentResponseV1:
    try:
        agent = await update_agent_service(
            agent_id, agent_update.model_dump(), current_agent, db
        )
        return AgentResponseV1.model_validate(agent, from_attributes=True)
    except AgentForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e)) from e
    except AgentNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@router.post(
    "/{agent_id}/heartbeat",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Send agent heartbeat",
    description="Send agent heartbeat. Requires agent authentication.",
)
async def send_heartbeat(
    agent_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent)],
) -> None:
    try:
        await send_heartbeat_service(agent_id, current_agent, db)
    except AgentForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e)) from e
    except AgentNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@router.post(
    "/{agent_id}/submit_benchmark",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Submit agent benchmark results",
    description="Submit agent benchmark results. Requires agent authentication.",
)
async def submit_benchmark(
    agent_id: int,
    benchmark: AgentBenchmark,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v1)],
) -> None:
    try:
        await submit_benchmark_service(agent_id, benchmark, current_agent, db)
    except AgentForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e)) from e
    except AgentNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@router.post(
    "/{agent_id}/submit_error",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Submit agent error",
    description="Submit agent error. Requires agent authentication.",
)
async def submit_error(
    agent_id: int,
    error: AgentErrorV1,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v1)],
) -> None:
    try:
        await submit_error_service(agent_id, current_agent, db, error.model_dump())
    except AgentForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e)) from e
    except AgentNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@router.post(
    "/{agent_id}/shutdown",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Shutdown agent",
    description="Shutdown agent. Requires agent authentication.",
)
async def shutdown_agent(
    agent_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v1)],
) -> None:
    try:
        await shutdown_agent_service(agent_id, current_agent, db)
    except AgentForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e)) from e
    except AgentNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
