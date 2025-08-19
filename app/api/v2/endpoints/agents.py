import logging

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.decorators.error_handling import handle_agent_errors
from app.core.deps import get_current_agent_v2, get_db
from app.core.services.agent_v2_service import agent_v2_service
from app.models.agent import Agent
from app.schemas.agent_v2 import (
    AgentHeartbeatRequestV2,
    AgentHeartbeatResponseV2,
    AgentInfoResponseV2,
    AgentRegisterRequestV2,
    AgentRegisterResponseV2,
    AgentUpdateRequestV2,
    AgentUpdateResponseV2,
)

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/client/agents",
    tags=["Agent Management"],
    responses={
        401: {"description": "Invalid or missing agent token"},
        403: {"description": "Agent not authorized for this operation"},
        404: {"description": "Agent not found"},
    },
)


@router.post(
    "/register",
    response_model=AgentRegisterResponseV2,
    status_code=status.HTTP_201_CREATED,
    summary="Register new agent",
    description="Register a new agent in the system and receive authentication token",
)
@handle_agent_errors
async def register_agent(
    registration_data: AgentRegisterRequestV2, db: AsyncSession = Depends(get_db)
) -> AgentRegisterResponseV2:
    """Register a new agent in the system."""
    return await agent_v2_service.register_agent_v2_service(db, registration_data)


@router.get(
    "/me",
    response_model=AgentInfoResponseV2,
    summary="Get agent information",
    description="Get information about the current authenticated agent",
)
@handle_agent_errors
async def get_current_agent_info(
    db: AsyncSession = Depends(get_db), current_agent: Agent = Depends(get_current_agent_v2)
) -> AgentInfoResponseV2:
    """Get information about the current authenticated agent."""
    return await agent_v2_service.get_agent_info_v2_service(db, current_agent)


@router.put(
    "/me",
    response_model=AgentUpdateResponseV2,
    summary="Update agent information",
    description="Update information about the current authenticated agent",
)
@handle_agent_errors
async def update_current_agent(
    agent_update: AgentUpdateRequestV2,
    db: AsyncSession = Depends(get_db),
    current_agent: Agent = Depends(get_current_agent_v2),
) -> AgentUpdateResponseV2:
    """Update information about the current authenticated agent."""
    return await agent_v2_service.update_agent_v2_service(db, current_agent, agent_update)


@router.post(
    "/heartbeat",
    status_code=status.HTTP_200_OK,
    summary="Send agent heartbeat",
    description="Send a heartbeat signal to indicate the agent is alive and active",
)
@handle_agent_errors
async def agent_heartbeat(
    heartbeat_data: AgentHeartbeatRequestV2 | None = None,
    db: AsyncSession = Depends(get_db),
    current_agent: Agent = Depends(get_current_agent_v2),
) -> AgentHeartbeatResponseV2:
    """Send a heartbeat signal to indicate the agent is alive and active."""
    return await agent_v2_service.process_heartbeat_v2_service(
        db, current_agent, heartbeat_data
    )
