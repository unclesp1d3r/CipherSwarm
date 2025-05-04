# mypy: disable-error-code="attr-defined"
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.exceptions import (
    AgentAlreadyExistsError,
    AgentNotFoundError,
    InvalidAgentStateError,
    InvalidAgentTokenError,
)
from app.core.services.agent_service import (
    heartbeat_agent_service,
    register_agent_service,
    submit_task_result_service,
    update_agent_state_service,
    update_task_progress_service,
)
from app.core.services.client_service import (
    AgentNotAssignedError,
    TaskNotFoundError,
    TaskNotRunningError,
)
from app.schemas.agent import (
    AgentHeartbeatRequest as AgentHeartbeatRequestSchema,
)
from app.schemas.agent import (
    AgentRegisterRequest,
    AgentRegisterResponse,
    AgentStateUpdateRequest,
)
from app.schemas.task import TaskProgressUpdate, TaskResultSubmit

router = APIRouter()


@router.post(
    "/agents/register",
    status_code=status.HTTP_201_CREATED,
    summary="Register a new agent",
    description="Register a new CipherSwarm agent and return an authentication token.",
)
async def register_agent(
    data: AgentRegisterRequest, db: Annotated[AsyncSession, Depends(get_db)]
) -> AgentRegisterResponse:
    """Register a new agent and return an authentication token."""
    try:
        return await register_agent_service(data, db)
    except AgentAlreadyExistsError as e:
        raise HTTPException(status_code=409, detail=str(e)) from e


@router.post(
    "/agents/heartbeat",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Agent heartbeat",
    description="Agent sends a heartbeat to update its status and last seen timestamp.",
)
async def agent_heartbeat(
    request: Request,
    data: AgentHeartbeatRequestSchema,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    """Agent heartbeat endpoint. Updates last_seen_at and state."""
    try:
        await heartbeat_agent_service(request, data, db, authorization, None)
    except InvalidAgentTokenError as e:
        if "User-Agent" in str(e):
            raise HTTPException(status_code=400, detail=str(e)) from e
        raise HTTPException(status_code=401, detail=str(e)) from e
    except AgentNotFoundError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except InvalidAgentStateError as e:
        raise HTTPException(status_code=422, detail=str(e)) from e


@router.post(
    "/agents/state",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Update agent state",
    description="Update the state of the agent. Requires valid Authorization and User-Agent headers.",
)
async def update_agent_state(
    data: AgentStateUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    """Update the state of the agent. Requires valid Authorization and User-Agent headers."""
    try:
        await update_agent_state_service(data, db, authorization, None)
    except InvalidAgentTokenError as e:
        if "User-Agent" in str(e):
            raise HTTPException(status_code=400, detail=str(e)) from e
        raise HTTPException(status_code=401, detail=str(e)) from e
    except AgentNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except InvalidAgentStateError as e:
        raise HTTPException(status_code=422, detail=str(e)) from e


@router.post(
    "/tasks/{task_id}/progress",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Update task progress",
    description="Agents send progress updates for a task. Requires valid Authorization and User-Agent headers.",
)
async def update_task_progress(
    task_id: int,
    data: TaskProgressUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await update_task_progress_service(task_id, data, db, authorization, None)
    except InvalidAgentTokenError as e:
        if "User-Agent" in str(e):
            raise HTTPException(status_code=400, detail=str(e)) from e
        raise HTTPException(status_code=401, detail=str(e)) from e
    except TaskNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except AgentNotAssignedError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e
    except TaskNotRunningError as e:
        raise HTTPException(status_code=409, detail=str(e)) from e


@router.post(
    "/tasks/{task_id}/result",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Submit task result",
    description="Agents submit cracked hashes and metadata for a task. Requires valid Authorization and User-Agent headers.",
)
async def submit_task_result(
    task_id: int,
    data: TaskResultSubmit,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await submit_task_result_service(task_id, data, db, authorization, None)
    except InvalidAgentTokenError as e:
        if "User-Agent" in str(e):
            raise HTTPException(status_code=400, detail=str(e)) from e
        raise HTTPException(status_code=401, detail=str(e)) from e
    except TaskNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except AgentNotAssignedError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e
    except TaskNotRunningError as e:
        raise HTTPException(status_code=409, detail=str(e)) from e
