from typing import Annotated

# Third-party imports
from fastapi import (
    APIRouter,
    Depends,
    Header,
    HTTPException,
    Path,
    Response,
    status,
)
from fastapi.responses import PlainTextResponse
from sqlalchemy.ext.asyncio import AsyncSession

# Local imports
from app.core.deps import get_db
from app.core.exceptions import InvalidAgentTokenError
from app.core.services.agent_service import (
    submit_task_result_service,
    update_task_progress_service,
)
from app.core.services.client_service import AgentNotAssignedError, TaskNotRunningError
from app.core.services.task_service import (
    TaskAlreadyAbandonedError,
    TaskAlreadyCompletedError,
    TaskAlreadyExhaustedError,
    TaskNotFoundError,
    abandon_task_service,
    accept_task_service,
    assign_task_service,
    exhaust_task_service,
    get_task_by_id_service,
    get_task_zaps_service,
)
from app.schemas.task import (
    HashcatResult,
    TaskOutV1,
    TaskProgressUpdate,
    TaskResultSubmit,
)

router = APIRouter(tags=["Tasks"], prefix="/client/tasks")


@router.post(
    "/{task_id}/progress",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Update task progress (v1 compatibility)",
    description="Agents send progress updates for a task. Compatibility layer for v1 API.",
)
async def update_task_progress_v1(
    task_id: Annotated[int, Path()],
    data: TaskProgressUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await update_task_progress_service(task_id, data, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except TaskNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except AgentNotAssignedError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except TaskNotRunningError as e:
        raise HTTPException(status_code=409, detail=str(e)) from e
    except TaskAlreadyExhaustedError as e:
        raise HTTPException(status_code=409, detail=str(e)) from e
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e)) from e


@router.post(
    "/{task_id}/result",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Submit task result (v1 compatibility)",
    description="Agents submit cracked hashes and metadata for a task. Compatibility layer for v1 API.",
)
async def submit_task_result_v1(
    task_id: Annotated[int, Path()],
    data: TaskResultSubmit,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await submit_task_result_service(task_id, data, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except TaskNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except AgentNotAssignedError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except TaskNotRunningError as e:
        raise HTTPException(status_code=409, detail=str(e)) from e
    except TaskAlreadyCompletedError as e:
        raise HTTPException(status_code=409, detail=str(e)) from e
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e)) from e


@router.get(
    "/new",
    status_code=status.HTTP_200_OK,
    summary="Request a new task from server (v1 compatibility)",
    description="Request a new task from the server, if available. Compatibility layer for v1 API.",
)
async def get_new_task_v1(
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> TaskOutV1:
    return await assign_task_service(db, authorization, "CipherSwarm-Agent/1.0.0")


@router.post(
    "/{task_id}/submit_status",
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
    task_id: Annotated[int, Path()],
    data: TaskProgressUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await update_task_progress_service(task_id, data, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except TaskNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except AgentNotAssignedError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e
    except TaskAlreadyExhaustedError as e:
        raise HTTPException(status_code=409, detail=str(e)) from e
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e)) from e


@router.get(
    "/{task_id}",
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
    task_id: Annotated[int, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> TaskOutV1:
    try:
        return await get_task_by_id_service(task_id, db, authorization)
    except TaskNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e


@router.post(
    "/{task_id}/accept_task",
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
    task_id: Annotated[int, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await accept_task_service(task_id, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except TaskNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except TaskAlreadyCompletedError as e:
        raise HTTPException(status_code=422, detail=str(e)) from e
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e


@router.post(
    "/{task_id}/exhausted",
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
    task_id: Annotated[int, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await exhaust_task_service(task_id, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except TaskNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except TaskAlreadyExhaustedError as e:
        raise HTTPException(status_code=422, detail=str(e)) from e
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e


@router.post(
    "/{task_id}/abandon",
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
    task_id: Annotated[int, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await abandon_task_service(task_id, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except TaskNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except TaskAlreadyAbandonedError as e:
        raise HTTPException(
            status_code=422, detail={"state": ['cannot transition via "abandon"']}
        ) from e
    except TaskAlreadyCompletedError as e:
        raise HTTPException(
            status_code=422, detail={"state": ['cannot transition via "abandon"']}
        ) from e
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e


@router.get(
    "/{task_id}/get_zaps",
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
    task_id: Annotated[int, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str | None, Header(alias="Authorization")] = None,
) -> Response:
    if not authorization:
        return Response(
            content='{"error": "Bad credentials"}',
            status_code=status.HTTP_401_UNAUTHORIZED,
            media_type="application/json",
        )
    try:
        zaps = await get_task_zaps_service(task_id, db, authorization)
        return PlainTextResponse("\n".join(zaps), status_code=status.HTTP_200_OK)
    except (InvalidAgentTokenError, ValueError):
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
    pass
