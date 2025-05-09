from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    Header,
    HTTPException,
    Path,
    Query,
    Request,
    Response,
    status,
)
from fastapi.responses import JSONResponse, PlainTextResponse
from packaging.version import InvalidVersion, Version
from pydantic import BaseModel, Field
from sqlalchemy import select
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
from app.core.deps import get_current_agent_v1, get_db
from app.core.services.agent_service import (
    AgentNotAssignedError,
    TaskNotRunningError,
    update_task_progress_service,
)
from app.core.services.attack_service import (
    AttackNotFoundError,
    InvalidAgentTokenError,
    get_attack_config_service,
)
from app.core.services.client_service import get_latest_cracker_binary_for_os
from app.core.services.task_service import (
    TaskAlreadyAbandonedError,
    TaskAlreadyCompletedError,
    TaskAlreadyExhaustedError,
    TaskNotFoundError,
    abandon_task_service,
    accept_task_service,
    exhaust_task_service,
    get_task_by_id_service,
    get_task_zaps_service,
)
from app.models.agent import Agent
from app.models.cracker_binary import CrackerBinary
from app.models.hash_list import HashList
from app.models.operating_system import OSName
from app.schemas.agent import (
    AdvancedAgentConfiguration,
    AgentRegisterRequest,
    AgentRegisterResponse,
    AgentStateUpdateRequest,
)
from app.schemas.agent import (
    AgentHeartbeatRequest as V2AgentHeartbeatRequest,
)
from app.schemas.attack import AttackOutV1
from app.schemas.task import (
    HashcatResult,
    TaskOutV1,
    TaskProgressUpdate,
    TaskResultSubmit,
)

router = APIRouter()


class AgentConfigurationResponse(BaseModel):
    config: AdvancedAgentConfiguration
    api_version: int


class AgentAuthenticateResponse(BaseModel):
    authenticated: bool = Field(..., description="Whether the agent is authenticated")
    agent_id: int = Field(..., description="The ID of the authenticated agent")


class ErrorObject(BaseModel):
    error: str = Field(..., description="Error message")


class CrackerUpdateResponse(BaseModel):
    available: bool = Field(
        ..., description="A new version of the cracker binary is available"
    )
    latest_version: str | None = Field(
        None, description="The latest version of the cracker binary"
    )
    download_url: str | None = Field(
        None, description="The download URL of the new version"
    )
    exec_name: str | None = Field(None, description="The name of the executable")
    message: str | None = Field(None, description="A message about the update")


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


@router.get(
    "/attacks/{id}",
    summary="Get attack by ID (v1 agent API)",
    description="Returns an attack by id. This is used to get the details of an attack.",
    tags=["Attacks"],
)
async def get_attack_v1(
    attack_id: Annotated[int, Path(alias="id")],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> AttackOutV1:
    try:
        attack = await get_attack_config_service(attack_id, db, authorization)
        return AttackOutV1.model_validate(attack, from_attributes=True)
    except InvalidAgentTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        ) from e
    except AttackNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@router.get(
    "/attacks/{id}/hash_list",
    summary="Get the hash list for an attack (v1 agent API)",
    description="Returns the hash list for an attack as a text file. Each line is a hash value. Requires agent authentication.",
    tags=["Attacks"],
    response_class=PlainTextResponse,
    responses={
        status.HTTP_200_OK: {"content": {"text/plain": {}}},
        status.HTTP_404_NOT_FOUND: {"description": "Record not found"},
        status.HTTP_401_UNAUTHORIZED: {"description": "Unauthorized"},
        status.HTTP_403_FORBIDDEN: {"description": "Forbidden"},
    },
)
async def get_attack_hash_list_v1(
    attack_id: Annotated[int, Path(alias="id")],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> PlainTextResponse:
    try:
        attack = await get_attack_config_service(attack_id, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        ) from e
    except AttackNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e)) from e

    # Fetch the hash list
    hash_list_id = getattr(attack, "hash_list_id", None)
    if not hash_list_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
        )
    result = await db.execute(select(HashList).where(HashList.id == hash_list_id))
    hash_list = result.scalar_one_or_none()
    if not hash_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
        )
    # Get all hashes (one per line)
    hashes = [item.hash for item in hash_list.items]
    content = "\n".join(hashes)
    return PlainTextResponse(content, status_code=status.HTTP_200_OK)


@router.get(
    "/tasks/{id}",
    summary="Request the task information (v1 agent API)",
    description="Request the task information from the server. Requires agent authentication and assignment.",
    tags=["Tasks"],
    responses={
        status.HTTP_200_OK: {"content": {"application/json": {}}},
        status.HTTP_404_NOT_FOUND: {"description": "Task not found"},
        status.HTTP_401_UNAUTHORIZED: {"description": "Unauthorized"},
        status.HTTP_403_FORBIDDEN: {"description": "Forbidden"},
    },
)
async def get_task_v1(
    task_id: Annotated[int, Path(alias="id")],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> TaskOutV1:
    try:
        task = await get_task_by_id_service(task_id, db, authorization)
        return TaskOutV1.model_validate(task, from_attributes=True)
    except InvalidAgentTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        ) from e
    except TaskNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e)) from e


@router.post(
    "/tasks/{id}/submit_status",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Submit a status update for a task (v1 agent API)",
    description="Submit a status update for a task. This includes the status of the current guess and the devices.",
    tags=["Tasks"],
    responses={
        status.HTTP_204_NO_CONTENT: {"description": "status received successfully"},
        status.HTTP_202_ACCEPTED: {
            "description": "status received successfully, but stale"
        },
        status.HTTP_410_GONE: {
            "description": "status received successfully, but task paused"
        },
        status.HTTP_422_UNPROCESSABLE_ENTITY: {"description": "malformed status data"},
        status.HTTP_404_NOT_FOUND: {"description": "Task not found"},
        status.HTTP_401_UNAUTHORIZED: {"description": "Unauthorized"},
    },
)
async def submit_task_status_v1(
    task_id: Annotated[int, Path(alias="id")],
    data: TaskProgressUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await update_task_progress_service(task_id, data, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        ) from e
    except TaskNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e)) from e
    except AgentNotAssignedError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e)) from e
    except TaskNotRunningError as e:
        # Map to 410 Gone if task is paused, 202 if stale, else 410 by default
        # TODO: Implement logic to distinguish paused vs stale if/when supported
        raise HTTPException(status_code=status.HTTP_410_GONE, detail=str(e)) from e
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e)
        ) from e


@router.post(
    "/tasks/{id}/accept_task",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Accept Task (v1 agent API)",
    description="Accept an offered task from the server. Sets the task status to running and assigns it to the agent.",
    tags=["Tasks"],
    responses={
        status.HTTP_204_NO_CONTENT: {"description": "task accepted successfully"},
        status.HTTP_422_UNPROCESSABLE_ENTITY: {"description": "task already completed"},
        status.HTTP_404_NOT_FOUND: {"description": "task not found for agent"},
        status.HTTP_401_UNAUTHORIZED: {"description": "Unauthorized"},
        status.HTTP_403_FORBIDDEN: {"description": "Forbidden"},
    },
)
async def accept_task_v1(
    task_id: Annotated[int, Path(alias="id")],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await accept_task_service(task_id, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        ) from e
    except TaskNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    except TaskAlreadyCompletedError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e)
        ) from e
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e)) from e


@router.post(
    "/tasks/{id}/exhausted",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Notify of Exhausted Task (v1 agent API)",
    description="Notify the server that the task is exhausted. This will mark the task as completed.",
    tags=["Tasks"],
    responses={
        status.HTTP_204_NO_CONTENT: {"description": "successful"},
        status.HTTP_404_NOT_FOUND: {"description": "Task not found"},
        status.HTTP_401_UNAUTHORIZED: {"description": "Unauthorized"},
        status.HTTP_422_UNPROCESSABLE_ENTITY: {
            "description": "Task already completed or exhausted"
        },
        status.HTTP_403_FORBIDDEN: {"description": "Forbidden"},
    },
)
async def exhaust_task_v1(
    task_id: Annotated[int, Path(alias="id")],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await exhaust_task_service(task_id, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        ) from e
    except TaskNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    except TaskAlreadyExhaustedError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e)
        ) from e
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e)) from e


@router.post(
    "/tasks/{id}/abandon",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Abandon Task (v1 agent API)",
    description="Abandon a task. This will mark the task as abandoned. Usually used when the client is unable to complete the task.",
    tags=["Tasks"],
    responses={
        status.HTTP_204_NO_CONTENT: {"description": "successful"},
        status.HTTP_422_UNPROCESSABLE_ENTITY: {
            "description": "already completed",
            "content": {"application/json": {}},
        },
        status.HTTP_404_NOT_FOUND: {
            "description": "Task not found",
            "content": {"application/json": {}},
        },
        status.HTTP_401_UNAUTHORIZED: {
            "description": "Unauthorized",
            "content": {"application/json": {}},
        },
    },
)
async def abandon_task_v1(
    task_id: Annotated[int, Path(alias="id")],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await abandon_task_service(task_id, db, authorization)
    except TaskNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    except TaskAlreadyAbandonedError as e:
        # 422 for already abandoned
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"state": ['cannot transition via "abandon"']},
        ) from e
    except TaskAlreadyCompletedError as e:
        # 422 for already completed
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"state": ['cannot transition via "abandon"']},
        ) from e
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e)) from e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Bad credentials"
        ) from e


@router.get(
    "/tasks/{id}/get_zaps",
    summary="Get Completed Hashes (v1 agent API)",
    description="Gets the completed hashes for a task. This is a text file that should be added to the monitored directory to remove the hashes from the list during runtime.",
    tags=["Tasks"],
    response_class=PlainTextResponse,
    responses={
        status.HTTP_200_OK: {"content": {"text/plain": {}}},
        status.HTTP_422_UNPROCESSABLE_ENTITY: {"description": "already completed"},
        status.HTTP_404_NOT_FOUND: {"description": "Task not found"},
        status.HTTP_401_UNAUTHORIZED: {"description": "Unauthorized"},
        status.HTTP_403_FORBIDDEN: {"description": "Forbidden"},
    },
)
async def get_task_zaps_v1(
    task_id: Annotated[int, Path(alias="id")],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str | None, Header(alias="Authorization")] = None,
) -> Response:
    if not authorization or not authorization.startswith("Bearer "):
        return Response(
            content='{"error": "Bad credentials"}',
            status_code=status.HTTP_401_UNAUTHORIZED,
            media_type="application/json",
        )
    try:
        cracked_hashes: list[str] = await get_task_zaps_service(
            task_id, db, authorization
        )
        content = "\n".join(cracked_hashes)
        return Response(content, status_code=200, media_type="text/plain")
    except InvalidAgentTokenError:
        return Response(
            content='{"error": "Bad credentials"}',
            status_code=status.HTTP_401_UNAUTHORIZED,
            media_type="application/json",
        )
    except TaskNotFoundError:
        return Response(
            content='{"error": "Task not found"}',
            status_code=status.HTTP_404_NOT_FOUND,
            media_type="application/json",
        )
    except AgentNotAssignedError:
        return Response(
            content='{"error": "Forbidden"}',
            status_code=status.HTTP_403_FORBIDDEN,
            media_type="application/json",
        )
    except TaskAlreadyCompletedError:
        return Response(
            content='{"error": "Task already completed"}',
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            media_type="application/json",
        )


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
    """Return the configuration for the authenticated agent."""
    if not current_agent:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Bad credentials"
        )
    # Use the agent's advanced_configuration, or defaults if missing
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
) -> Response:
    """Authenticate the agent using the v1 token mechanism. Returns AgentAuthenticateResponse or JSON error envelope."""
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
    "/crackers/check_for_cracker_update",
    response_model=CrackerUpdateResponse,
    summary="Check for cracker update (v1 agent API)",
    description="Checks for an update to the cracker and returns update info if available.",
    tags=["Crackers"],
    responses={
        status.HTTP_200_OK: {"description": "successful"},
        status.HTTP_400_BAD_REQUEST: {
            "description": "bad request",
            "model": ErrorObject,
        },
        status.HTTP_401_UNAUTHORIZED: {
            "description": "unauthorized",
            "model": ErrorObject,
        },
    },
)
async def check_for_cracker_update_v1(
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
    version: Annotated[str, Query(description="Current cracker version (semver)")],
    operating_system: Annotated[
        str, Query(description="Operating system (windows, linux, darwin)")
    ],
) -> Response:
    # Authenticate agent
    try:
        await get_current_agent_v1(authorization, db)
    except HTTPException as exc:
        if exc.status_code == status.HTTP_401_UNAUTHORIZED:
            return JSONResponse(
                status_code=status.HTTP_401_UNAUTHORIZED,
                content={"error": "Bad credentials"},
            )
        raise
    # Validate OS
    try:
        os_enum = OSName(operating_system)
    except ValueError:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"error": "Invalid operating_system"},
        )
    # Fetch latest cracker binary from DB
    latest: CrackerBinary | None = await get_latest_cracker_binary_for_os(db, os_enum)
    if not latest:
        return JSONResponse(
            status_code=200,
            content=CrackerUpdateResponse(
                available=False,
                latest_version=None,
                download_url=None,
                exec_name=None,
                message="No updated crackers found for the specified operating system",
            ).model_dump(mode="json"),
        )
    latest_version: str = latest.version
    download_url: str = latest.download_url
    exec_name: str = latest.exec_name
    try:
        current_version = Version(version)
        latest_version_obj = Version(latest_version)
    except InvalidVersion:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"error": "Invalid version format"},
        )
    if current_version < latest_version_obj:
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=CrackerUpdateResponse(
                available=True,
                latest_version=latest_version,
                download_url=download_url,
                exec_name=exec_name,
                message=f"Update available: {latest_version}",
            ).model_dump(mode="json"),
        )
    return JSONResponse(
        status_code=status.HTTP_200_OK,
        content=CrackerUpdateResponse(
            available=False,
            latest_version=latest_version,
            download_url=None,
            exec_name=exec_name,
            message="You are up to date.",
        ).model_dump(mode="json"),
    )
