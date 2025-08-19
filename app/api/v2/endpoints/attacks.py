import logging
from typing import Annotated

from fastapi import APIRouter, Depends, Path, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.decorators.error_handling import handle_agent_errors
from app.core.deps import get_current_agent_v2
from app.core.services.agent_v2_service import agent_v2_service
from app.db.session import get_db
from app.models.agent import Agent
from app.schemas.agent_v2 import AttackConfigurationResponseV2

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/client/agents/attacks",
    tags=["Attack Configuration"],
    responses={
        401: {"description": "Invalid or missing agent token"},
        403: {"description": "Agent not authorized for this attack"},
        404: {"description": "Attack not found"},
    },
)


@router.get(
    "/{attack_id}",
    status_code=status.HTTP_200_OK,
    summary="Get attack configuration",
    description="""
    Retrieve attack configuration for a specific attack ID.

    This endpoint allows agents to retrieve the configuration details for an attack
    they are assigned to work on. The configuration includes attack parameters,
    resource requirements, and execution instructions.

    **Authentication**: Required - Bearer token (`csa_<agent_id>_<token>`)

    **Authorization**: Agent must be authorized to access the specific attack

    **Requirements**:
    - Valid agent token in Authorization header
    - Attack must exist and be accessible
    - Agent must have permission to access the attack
    """,
)
@handle_agent_errors
async def get_attack_configuration(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v2)],
    attack_id: Annotated[
        int,
        Path(..., description="The ID of the attack to get configuration for", ge=1),
    ],
) -> AttackConfigurationResponseV2:
    """Get attack configuration for a specific attack ID."""
    return await agent_v2_service.get_attack_configuration_v2_service(
        db, current_agent, attack_id
    )
