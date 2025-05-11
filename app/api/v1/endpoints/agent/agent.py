from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
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
    AdvancedAgentConfiguration,
    AgentBenchmark,
    AgentErrorV1,
    AgentRegisterRequest,
    AgentRegisterResponse,
    AgentResponseV1,
    AgentStateUpdateRequest,
    AgentUpdateV1,
)
from app.schemas.agent import (
    AgentHeartbeatRequest as V2AgentHeartbeatRequest,
)
from app.schemas.error import ErrorObject

router = APIRouter()


# Register Agent
@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    summary="Register a new agent (v1 compatibility)",
    description="Register a new CipherSwarm agent and return an authentication token. Compatibility layer for v1 API.",
)
async def register_agent_v1(
    data: AgentRegisterRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AgentRegisterResponse:
    from app.core.services.agent_service import register_agent_service

    return await register_agent_service(data, db)


# Agent Heartbeat
@router.post(
    "/heartbeat",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Agent heartbeat (v1 compatibility)",
    description="Agent sends a heartbeat to update its status and last seen timestamp. Compatibility layer for v1 API.",
)
async def agent_heartbeat_v1(
    request: Request,
    data: V2AgentHeartbeatRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    from app.core.services.agent_service import heartbeat_agent_service

    await heartbeat_agent_service(request, data, db, authorization)


# Update Agent State
@router.post(
    "/state",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Update agent state (v1 compatibility)",
    description="Update the state of the agent. Compatibility layer for v1 API.",
)
async def update_agent_state_v1(
    data: AgentStateUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    from app.core.services.agent_service import update_agent_state_service

    await update_agent_state_service(data, db, authorization)


# Agent Configuration
class AgentConfigurationResponse(BaseModel):
    config: AdvancedAgentConfiguration
    api_version: int


@router.get(
    "/configuration",
    summary="Get Agent Configuration (v1 agent API)",
    description="Returns the configuration for the agent. This is used to get the configuration for the agent that has been set by the administrator on the server. The configuration is stored in the database and can be updated by the administrator on the server and is global, but specific to the individual agent. Client should cache the configuration and only request a new configuration if the agent is restarted or if the configuration has changed.",
    tags=["Client"],
    responses={
        status.HTTP_200_OK: {
            "description": "successful",
            "content": {"application/json": {}},
        },
        status.HTTP_401_UNAUTHORIZED: {"description": "unauthorized"},
        status.HTTP_404_NOT_FOUND: {"description": "Agent not found"},
    },
)
async def get_agent_configuration_v1(
    current_agent: Annotated[Agent, Depends(get_current_agent_v1)],
) -> AgentConfigurationResponse:
    if not current_agent:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Bad credentials"
        )
    config_dict = current_agent.advanced_configuration or {}
    try:
        config = AdvancedAgentConfiguration.model_validate(config_dict)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Invalid configuration: {e}",
        ) from e
    return AgentConfigurationResponse(config=config, api_version=1)


# Authenticate Agent
class AgentAuthenticateResponse(BaseModel):
    authenticated: bool = Field(..., description="Whether the agent is authenticated")
    agent_id: int = Field(..., description="The ID of the authenticated agent")


@router.get(
    "/authenticate",
    response_model=AgentAuthenticateResponse,
    summary="Authenticate Client (v1 agent API)",
    description="Authenticates the client. This is used to verify that the client is able to connect to the server.",
    tags=["Client"],
    responses={
        status.HTTP_200_OK: {
            "description": "successful",
            "content": {
                "application/json": {
                    "example": {"authenticated": True, "agent_id": 2624}
                }
            },
        },
        status.HTTP_401_UNAUTHORIZED: {
            "description": "unauthorized",
            "model": ErrorObject,
            "content": {"application/json": {"example": {"error": "Bad credentials"}}},
        },
    },
)
async def authenticate_agent_v1(
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> JSONResponse:
    from app.core.deps import get_current_agent_v1

    try:
        current_agent = await get_current_agent_v1(authorization, db)
    except HTTPException as exc:
        if exc.status_code == status.HTTP_401_UNAUTHORIZED:
            return JSONResponse(
                status_code=status.HTTP_401_UNAUTHORIZED,
                content={"error": "Bad credentials"},
            )
        raise
    resp = AgentAuthenticateResponse(authenticated=True, agent_id=current_agent.id)
    return JSONResponse(status_code=200, content=resp.model_dump(mode="json"))


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
