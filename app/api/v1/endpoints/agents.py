from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_agent, get_db
from app.models.agent import Agent, AgentState
from app.schemas.agent import (
    AgentBenchmark,
    AgentError,
    AgentResponse,
    AgentUpdate,
)

router = APIRouter()


@router.get("/{id}", response_model=AgentResponse)
async def get_agent(
    id: int,
    db: AsyncSession = Depends(get_db),
    current_agent: Agent = Depends(get_current_agent),
) -> AgentResponse:
    """Get agent by ID."""
    if current_agent.id != id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this agent",
        )

    result = await db.execute(select(Agent).filter(Agent.id == id))
    agent = result.scalar_one_or_none()

    if not agent:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Agent not found",
        )

    return agent


@router.put("/{id}", response_model=AgentResponse)
async def update_agent(
    id: int,
    agent_update: AgentUpdate,
    db: AsyncSession = Depends(get_db),
    current_agent: Agent = Depends(get_current_agent),
) -> AgentResponse:
    """Update agent."""
    if current_agent.id != id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update this agent",
        )

    result = await db.execute(select(Agent).filter(Agent.id == id))
    agent = result.scalar_one_or_none()

    if not agent:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Agent not found",
        )

    # Update agent fields
    for field, value in agent_update.dict(exclude_unset=True).items():
        setattr(agent, field, value)

    await db.commit()
    await db.refresh(agent)

    return agent


@router.post("/{id}/heartbeat", status_code=status.HTTP_204_NO_CONTENT)
async def send_heartbeat(
    id: int,
    db: AsyncSession = Depends(get_db),
    current_agent: Agent = Depends(get_current_agent),
) -> None:
    """Send agent heartbeat."""
    if current_agent.id != id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to send heartbeat for this agent",
        )

    result = await db.execute(select(Agent).filter(Agent.id == id))
    agent = result.scalar_one_or_none()

    if not agent:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Agent not found",
        )

    agent.last_seen_at = datetime.utcnow()
    await db.commit()


@router.post("/{id}/submit_benchmark", status_code=status.HTTP_204_NO_CONTENT)
async def submit_benchmark(
    id: int,
    benchmark: AgentBenchmark,
    db: AsyncSession = Depends(get_db),
    current_agent: Agent = Depends(get_current_agent),
) -> None:
    """Submit agent benchmark results."""
    if current_agent.id != id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to submit benchmarks for this agent",
        )

    result = await db.execute(select(Agent).filter(Agent.id == id))
    agent = result.scalar_one_or_none()

    if not agent:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Agent not found",
        )

    # Process benchmark results
    # TODO: Implement benchmark processing


@router.post("/{id}/submit_error", status_code=status.HTTP_204_NO_CONTENT)
async def submit_error(
    id: int,
    error: AgentError,
    db: AsyncSession = Depends(get_db),
    current_agent: Agent = Depends(get_current_agent),
) -> None:
    """Submit agent error."""
    if current_agent.id != id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to submit errors for this agent",
        )

    result = await db.execute(select(Agent).filter(Agent.id == id))
    agent = result.scalar_one_or_none()

    if not agent:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Agent not found",
        )

    agent.state = AgentState.ERROR
    # TODO: Store error details
    await db.commit()


@router.post("/{id}/shutdown", status_code=status.HTTP_204_NO_CONTENT)
async def shutdown_agent(
    id: int,
    db: AsyncSession = Depends(get_db),
    current_agent: Agent = Depends(get_current_agent),
) -> None:
    """Shutdown agent."""
    if current_agent.id != id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to shutdown this agent",
        )

    result = await db.execute(select(Agent).filter(Agent.id == id))
    agent = result.scalar_one_or_none()

    if not agent:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Agent not found",
        )

    agent.state = AgentState.STOPPED
    await db.commit()
