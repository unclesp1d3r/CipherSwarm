from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Request, Response, status
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.attack_service import (
    AttackNotFoundError,
    InvalidAgentTokenError,
    get_attack_config_service,
)
from app.core.services.client_service import (
    AgentNotAssignedError,
    TaskNotFoundError,
    TaskNotRunningError,
    get_new_task_service_v2,
    heartbeat_agent_service_v2,
    register_agent_service_v2,
    submit_cracked_hash_service_v2,
    submit_task_result_service_v2,
    update_agent_state_service_v2,
    update_task_progress_service_v2,
)
from app.schemas.agent import (
    AgentHeartbeatRequest,
    AgentRegisterRequest,
    AgentRegisterResponse,
    AgentStateUpdateRequest,
)
from app.schemas.attack import AttackOut
from app.schemas.task import (
    HashcatResult,
    TaskProgressUpdate,
    TaskResultSubmit,
)
from app.core.logging import logger

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
    try:
        return await register_agent_service_v2(data, db)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.post(
    "/agents/heartbeat",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Agent heartbeat",
    description="Agent sends a heartbeat to update its status and last seen timestamp.",
)
async def agent_heartbeat(
    request: Request,
    data: AgentHeartbeatRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await heartbeat_agent_service_v2(request, data, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.post(
    "/agents/state",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Update agent state",
    description="Update the state of the agent. Requires valid Authorization.",
)
async def update_agent_state(
    data: AgentStateUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await update_agent_state_service_v2(data, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.post(
    "/tasks/{task_id}/progress",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Update task progress",
    description="Agents send progress updates for a task. Requires valid Authorization.",
)
async def update_task_progress(
    task_id: int,
    data: TaskProgressUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await update_task_progress_service_v2(task_id, data, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except (TaskNotFoundError, AgentNotAssignedError) as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except TaskNotRunningError as e:
        raise HTTPException(status_code=409, detail=str(e)) from e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.post(
    "/tasks/{task_id}/result",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Submit task result",
    description="Agents submit cracked hashes and metadata for a task. Requires valid Authorization.",
)
async def submit_task_result(
    task_id: int,
    data: TaskResultSubmit,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> None:
    try:
        await submit_task_result_service_v2(task_id, data, db, authorization)
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except (TaskNotFoundError, AgentNotAssignedError) as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except TaskNotRunningError as e:
        raise HTTPException(status_code=409, detail=str(e)) from e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.get(
    "/tasks/new",
    status_code=status.HTTP_200_OK,
    summary="Request a new task from server",
    description="Request a new task from the server, if available. Requires valid Authorization.",
)
async def get_new_task(
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> Response:
    try:
        task = await get_new_task_service_v2(db, authorization)
        return JSONResponse(
            status_code=200, content=jsonable_encoder(task.model_dump())
        )
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except TaskNotFoundError:
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except Exception as e:
        logger.exception("Task assignment failed (v2 endpoint)")
        raise HTTPException(status_code=500, detail=str(e)) from e
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/tasks/{task_id}/submit_crack",
    status_code=status.HTTP_200_OK,
    summary="Submit a cracked hash result for a task",
    description="Submit a cracked hash result for a task. Requires valid Authorization.",
)
async def submit_cracked_hash(
    task_id: int,
    data: HashcatResult,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> Response:
    try:
        result = await submit_cracked_hash_service_v2(task_id, data, db, authorization)
        if result == "already_submitted":
            return Response(status_code=status.HTTP_204_NO_CONTENT)
        return JSONResponse(
            status_code=200, content={"message": "Cracked hash submitted"}
        )
    except (InvalidAgentTokenError, TaskNotFoundError, AgentNotAssignedError) as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except TaskNotRunningError as e:
        raise HTTPException(status_code=409, detail=str(e)) from e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/attacks/{attack_id}/config",
    status_code=status.HTTP_200_OK,
    summary="Fetch attack configuration",
    description="Fetch attack configuration by ID. Requires valid Authorization.",
    tags=["Attacks"],
)
async def get_attack_config_v2(
    attack_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
) -> AttackOut:
    try:
        attack = await get_attack_config_service(attack_id, db, authorization)
        return AttackOut.model_validate(attack, from_attributes=True)
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except AttackNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e
