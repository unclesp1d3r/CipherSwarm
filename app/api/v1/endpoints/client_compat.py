from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    Header,
    Path,
    Request,
    Response,
    status,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v2.endpoints.client import (
    agent_heartbeat as v2_agent_heartbeat,
)
from app.api.v2.endpoints.client import (
    get_new_task as v2_get_new_task,
)

# Import the v2 implementation
from app.api.v2.endpoints.client import (
    register_agent as v2_register_agent,
)
from app.api.v2.endpoints.client import (
    submit_cracked_hash as v2_submit_cracked_hash,
)
from app.api.v2.endpoints.client import (
    submit_task_result as v2_submit_task_result,
)
from app.api.v2.endpoints.client import (
    update_agent_state as v2_update_agent_state,
)
from app.api.v2.endpoints.client import (
    update_task_progress as v2_update_task_progress,
)
from app.core.deps import get_db
from app.schemas.agent import (
    AgentHeartbeatRequest as V2AgentHeartbeatRequest,
)
from app.schemas.agent import (
    AgentRegisterRequest,
    AgentRegisterResponse,
    AgentStateUpdateRequest,
)
from app.schemas.task import (
    HashcatResult,
    TaskProgressUpdate,
    TaskResultSubmit,
)

router = APIRouter()


@router.post(
    "/agents/register",
    status_code=status.HTTP_201_CREATED,
    summary="Register a new agent (v1 compatibility)",
    description="Register a new CipherSwarm agent and return an authentication token. Compatibility layer for v1 API.",
)
async def register_agent_v1(
    data: AgentRegisterRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AgentRegisterResponse:
    return await v2_register_agent(data, db)


@router.post(
    "/agents/heartbeat",
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
    await v2_agent_heartbeat(request, data, db, authorization)


@router.post(
    "/agents/state",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Update agent state (v1 compatibility)",
    description="Update the state of the agent. Compatibility layer for v1 API.",
)
async def update_agent_state_v1(
    data: AgentStateUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    await v2_update_agent_state(data, db, authorization)


@router.post(
    "/tasks/{id}/progress",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Update task progress (v1 compatibility)",
    description="Agents send progress updates for a task. Compatibility layer for v1 API.",
)
async def update_task_progress_v1(
    task_id: Annotated[int, Path(alias="id")],
    data: TaskProgressUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    await v2_update_task_progress(task_id, data, db, authorization)


@router.post(
    "/tasks/{id}/result",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Submit task result (v1 compatibility)",
    description="Agents submit cracked hashes and metadata for a task. Compatibility layer for v1 API.",
)
async def submit_task_result_v1(
    task_id: Annotated[int, Path(alias="id")],
    data: TaskResultSubmit,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    await v2_submit_task_result(task_id, data, db, authorization)


@router.get(
    "/tasks/new",
    status_code=status.HTTP_200_OK,
    summary="Request a new task from server (v1 compatibility)",
    description="Request a new task from the server, if available. Compatibility layer for v1 API.",
)
async def get_new_task_v1(
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> Response:
    return await v2_get_new_task(db, authorization)


@router.post(
    "/tasks/{id}/submit_crack",
    status_code=status.HTTP_200_OK,
    summary="Submit a cracked hash result for a task (v1 compatibility)",
    description="Submit a cracked hash result for a task. Compatibility layer for v1 API.",
)
async def submit_cracked_hash_v1(
    task_id: Annotated[int, Path(alias="id")],
    data: HashcatResult,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    await v2_submit_cracked_hash(task_id, data, db, authorization)
