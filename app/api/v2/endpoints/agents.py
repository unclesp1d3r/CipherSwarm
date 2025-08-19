import logging
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.decorators.error_handling import handle_agent_errors
from app.core.deps import get_current_agent_v2
from app.core.services.agent_v2_service import agent_v2_service
from app.db.session import get_db
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
    status_code=status.HTTP_201_CREATED,
    summary="Register new agent",
    description="Register a new agent in the system and receive authentication token",
)
@handle_agent_errors
async def register_agent(
    registration_data: AgentRegisterRequestV2,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AgentRegisterResponseV2:
    """Register a new agent in the system."""
    return await agent_v2_service.register_agent_v2_service(db, registration_data)


@router.get(
    "/me",
    summary="Get agent information",
    description="Get information about the current authenticated agent",
)
@handle_agent_errors
async def get_current_agent_info(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v2)],
) -> AgentInfoResponseV2:
    """Get information about the current authenticated agent."""
    return await agent_v2_service.get_agent_info_v2_service(db, current_agent)


@router.put(
    "/me",
    summary="Update agent information",
    description="Update information about the current authenticated agent",
)
@handle_agent_errors
async def update_current_agent(
    agent_update: AgentUpdateRequestV2,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v2)],
) -> AgentUpdateResponseV2:
    """Update information about the current authenticated agent."""
    return await agent_v2_service.update_agent_v2_service(
        db, current_agent, agent_update
    )


@router.post(
    "/heartbeat",
    status_code=status.HTTP_200_OK,
    summary="Send agent heartbeat",
    description="Send a heartbeat signal to indicate the agent is alive and active",
)
@handle_agent_errors
async def agent_heartbeat(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v2)],
    heartbeat_data: AgentHeartbeatRequestV2 | None = None,
) -> AgentHeartbeatResponseV2:
    """Send a heartbeat signal to indicate the agent is alive and active."""
    return await agent_v2_service.process_heartbeat_v2_service(
        db, current_agent, heartbeat_data
    )
