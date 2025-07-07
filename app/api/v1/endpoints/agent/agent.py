from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_agent_v1
from app.core.exceptions import AgentNotFoundError, InvalidAgentTokenError
from app.core.services.agent_service import (
    AgentForbiddenError,
    get_agent_service,
    send_heartbeat_service,
    shutdown_agent_service,
    submit_benchmark_service,
    submit_error_service,
    update_agent_service,
)
from app.db.session import get_db
from app.models.agent import Agent
from app.schemas.agent import (
    AdvancedAgentConfiguration,
    AgentBenchmark,
    AgentErrorV1,
    AgentResponseV1,
    AgentUpdateV1,
)
from app.schemas.error import ErrorObject

router = APIRouter()

# --- Removed endpoints with [LEGACY/COMPAT] in their description ---


# Agent Configuration
class AgentConfigurationResponse(BaseModel):
    config: AdvancedAgentConfiguration
    api_version: int


@router.get(
    "/client/configuration",
    summary="Get Agent Configuration",
    description="Returns the configuration for the agent. This is used to get the configuration for the agent that has been set by the administrator on the server. The configuration is stored in the database and can be updated by the administrator on the server and is global, but specific to the individual agent. Client should cache the configuration and only request a new configuration if the agent is restarted or if the configuration has changed.",
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
    "/client/authenticate",
    response_model=AgentAuthenticateResponse,
    summary="Authenticate Client",
    description="Authenticates the client. This is used to verify that the client is able to connect to the server.",
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
    "/client/agents/{id}",
    summary="Get agent by ID",
    description="Get agent by ID. Requires agent authentication.",
)
async def get_agent(
    id: int,  # noqa: A002
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v1)],
) -> AgentResponseV1:
    try:
        agent = await get_agent_service(id, current_agent, db)
        return AgentResponseV1.model_validate(agent, from_attributes=True)
    except AgentForbiddenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        ) from e
    except AgentNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@router.put(
    "/client/agents/{id}",
    summary="Update agent",
    description="Update agent. Requires agent authentication.",
)
async def update_agent(
    id: int,  # noqa: A002
    agent_update: AgentUpdateV1,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v1)],
) -> AgentResponseV1:
    try:
        agent = await update_agent_service(
            id, agent_update.model_dump(), current_agent, db
        )
        return AgentResponseV1.model_validate(agent, from_attributes=True)
    except AgentForbiddenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        ) from e
    except AgentNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


# --- Contract/Legacy Compatibility: Register endpoints at both /client/agents/{id}/... and /agents/{id}/... ---
@router.post(
    "/client/agents/{id}/submit_benchmark",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Submit agent benchmark results",
    description="Submit agent benchmark results. Requires agent authentication.",
)
@router.post(
    "/agents/{id}/submit_benchmark",
    status_code=status.HTTP_204_NO_CONTENT,
    include_in_schema=False,  # Hide duplicate from OpenAPI docs
)
async def submit_benchmark(
    id: int,  # noqa: A002
    benchmark: AgentBenchmark,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v1)],
) -> None:
    try:
        await submit_benchmark_service(id, benchmark, current_agent, db)
    except InvalidAgentTokenError as e:
        if current_agent is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
            ) from e
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authorized"
        ) from e
    except AgentForbiddenError as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden"
        ) from e
    except AgentNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
        ) from e


@router.post(
    "/client/agents/{id}/submit_error",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Submit agent error",
    description="Submit agent error. Requires agent authentication.",
)
@router.post(
    "/agents/{id}/submit_error",
    status_code=status.HTTP_204_NO_CONTENT,
    include_in_schema=False,
)
async def submit_error(
    id: int,  # noqa: A002
    error: AgentErrorV1,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v1)],
) -> None:
    try:
        await submit_error_service(id, current_agent, db, error)
    except InvalidAgentTokenError as e:
        if current_agent is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
            ) from e
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authorized"
        ) from e
    except AgentForbiddenError as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden"
        ) from e
    except AgentNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
        ) from e


@router.post(
    "/client/agents/{id}/shutdown",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Shutdown agent",
    description="Shutdown agent. Requires agent authentication.",
)
@router.post(
    "/agents/{id}/shutdown",
    status_code=status.HTTP_204_NO_CONTENT,
    include_in_schema=False,
)
async def shutdown_agent(
    id: int,  # noqa: A002
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v1)],
) -> None:
    try:
        await shutdown_agent_service(id, current_agent, db)
    except InvalidAgentTokenError as e:
        if current_agent is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
            ) from e
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authorized"
        ) from e
    except AgentForbiddenError as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden"
        ) from e
    except AgentNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
        ) from e


@router.post(
    "/client/agents/{id}/heartbeat",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Agent heartbeat (contract)",
    description="Agent sends a heartbeat to update its status and last seen timestamp. Contract-compliant endpoint.",
)
async def agent_heartbeat_contract(
    id: int,  # noqa: A002
    db: Annotated[AsyncSession, Depends(get_db)],
    current_agent: Annotated[Agent, Depends(get_current_agent_v1)],
) -> None:
    try:
        await send_heartbeat_service(id, current_agent, db)
    except AgentForbiddenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        ) from e
    except AgentNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
        ) from e
