from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_agent_v1
from app.db.session import get_db
from app.models.agent import Agent
from app.schemas.agent import AdvancedAgentConfiguration
from app.schemas.error import ErrorObject


class AgentConfigurationResponse(BaseModel):
    config: AdvancedAgentConfiguration
    api_version: int


class AgentAuthenticateResponse(BaseModel):
    authenticated: bool = Field(..., description="Whether the agent is authenticated")
    agent_id: int = Field(..., description="The ID of the authenticated agent")


router = APIRouter()


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
