# mypy: disable-error-code="attr-defined"
import secrets
from datetime import UTC, datetime

from fastapi import Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import (
    InvalidAgentTokenError,
)
from app.models.agent import Agent, AgentState
from app.models.task import Task, TaskStatus
from app.schemas.agent import (
    AgentHeartbeatRequest,
    AgentRegisterRequest,
    AgentRegisterResponse,
    AgentStateUpdateRequest,
)
from app.schemas.task import (
    HashcatResult,
    TaskOut,
    TaskProgressUpdate,
    TaskResultSubmit,
)


class TaskNotFoundError(Exception):
    pass


class AgentNotAssignedError(Exception):
    pass


class TaskNotRunningError(Exception):
    pass


async def register_agent_service_v2(
    data: AgentRegisterRequest, db: AsyncSession
) -> AgentRegisterResponse:
    agent = Agent(
        host_name=data.hostname,
        client_signature=data.signature,
        agent_type=data.agent_type,
        state=AgentState.pending,
        token="temp",  # noqa: S106
        operating_system_id=data.operating_system_id,
    )
    db.add(agent)
    await db.commit()
    await db.refresh(agent)
    token = f"csa_{agent.id}_{secrets.token_urlsafe(16)}"
    agent.token = token
    await db.commit()
    await db.refresh(agent)
    return AgentRegisterResponse(agent_id=agent.id, token=token)


async def heartbeat_agent_service_v2(
    request: Request,
    data: AgentHeartbeatRequest,
    db: AsyncSession,
    authorization: str,
) -> None:
    if not authorization.startswith("Bearer csa_"):
        raise InvalidAgentTokenError("Invalid or missing agent token")
    token = authorization.removeprefix("Bearer ").strip()
    result = await db.execute(select(Agent).filter(Agent.token == token))
    agent = result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Invalid agent token")
    agent.last_seen_at = datetime.now(UTC)
    agent.last_ipaddress = request.client.host if request.client else None
    if data.state not in AgentState:
        raise ValueError("Invalid agent state")
    agent.state = data.state
    await db.commit()


async def update_agent_state_service_v2(
    data: AgentStateUpdateRequest,
    db: AsyncSession,
    authorization: str,
) -> None:
    if not authorization.startswith("Bearer csa_"):
        raise InvalidAgentTokenError("Invalid or missing agent token")
    token = authorization.removeprefix("Bearer ").strip()
    result = await db.execute(select(Agent).filter(Agent.token == token))
    agent = result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Invalid agent token")
    if data.state not in AgentState:
        raise ValueError("Invalid agent state")
    agent.state = data.state
    await db.commit()


async def update_task_progress_service_v2(
    task_id: int,
    data: TaskProgressUpdate,
    db: AsyncSession,
    authorization: str,
) -> None:
    if not authorization.startswith("Bearer csa_"):
        raise InvalidAgentTokenError("Invalid or missing agent token")
    token = authorization.removeprefix("Bearer ").strip()
    result = await db.execute(select(Agent).filter(Agent.token == token))
    agent = result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Invalid agent token")
    result = await db.execute(select(Task).filter(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise TaskNotFoundError("Task not found")
    if task.agent_id != agent.id:
        raise AgentNotAssignedError("Agent not assigned to this task")
    if task.status != TaskStatus.RUNNING:
        raise TaskNotRunningError("Task is not running")
    task.progress = data.progress_percent
    if not task.error_details:
        task.error_details = {}
    task.error_details["keyspace_processed"] = data.keyspace_processed
    await db.commit()


async def submit_task_result_service_v2(
    task_id: int,
    data: TaskResultSubmit,
    db: AsyncSession,
    authorization: str,
) -> None:
    if not authorization.startswith("Bearer csa_"):
        raise InvalidAgentTokenError("Invalid or missing agent token")
    token = authorization.removeprefix("Bearer ").strip()
    result = await db.execute(select(Agent).filter(Agent.token == token))
    agent = result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Invalid agent token")
    result = await db.execute(select(Task).filter(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise TaskNotFoundError("Task not found")
    if task.agent_id != agent.id:
        raise AgentNotAssignedError("Agent not assigned to this task")
    if task.status != TaskStatus.RUNNING:
        raise TaskNotRunningError("Task is not running")
    if not task.error_details:
        task.error_details = {}
    task.error_details["result"] = {
        "cracked_hashes": data.cracked_hashes,
        "metadata": data.metadata,
    }
    if data.error:
        task.status = TaskStatus.FAILED
        task.error_message = data.error
    else:
        task.status = TaskStatus.COMPLETED
    await db.commit()


async def get_new_task_service_v2(
    db: AsyncSession,
    authorization: str,
) -> TaskOut:
    if not authorization.startswith("Bearer csa_"):
        raise InvalidAgentTokenError("Invalid or missing agent token")
    token = authorization.removeprefix("Bearer ").strip()
    result = await db.execute(select(Agent).filter(Agent.token == token))
    agent = result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Invalid agent token")
    if not agent.benchmarks or len(agent.benchmarks) == 0:
        raise TaskNotFoundError(
            f"Agent {agent.id} has no benchmark data; skipping task assignment."
        )
    result = await db.execute(select(Task).filter(Task.status == TaskStatus.PENDING))
    pending_tasks = result.scalars().all()
    for task in pending_tasks:
        if not hasattr(task, "attack") or task.attack is None:
            await db.refresh(task, attribute_names=["attack"])
        if task.keyspace_total <= 0:
            continue
        if agent.can_handle_hash_type(task.attack.hash_type_id):
            task.agent_id = agent.id
            task.status = TaskStatus.RUNNING
            await db.commit()
            await db.refresh(task)
            return TaskOut.model_validate(task, from_attributes=True)
    raise TaskNotFoundError("No compatible pending tasks available")


async def submit_cracked_hash_service_v2(
    task_id: int,
    data: HashcatResult,
    db: AsyncSession,
    authorization: str,
) -> str | None:
    if not authorization.startswith("Bearer csa_"):
        raise InvalidAgentTokenError("Invalid or missing agent token")
    token = authorization.removeprefix("Bearer ").strip()
    result = await db.execute(select(Agent).filter(Agent.token == token))
    agent = result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Invalid agent token")
    result = await db.execute(select(Task).filter(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise TaskNotFoundError("Task not found")
    if task.agent_id != agent.id:
        raise AgentNotAssignedError("Agent not assigned to this task")
    if task.status != TaskStatus.RUNNING:
        raise TaskNotRunningError("Task is not running")
    if not task.error_details:
        task.error_details = {}
    cracked_hashes = task.error_details.get("cracked_hashes", [])
    # Check for duplicate
    for entry in cracked_hashes:
        if entry["hash"] == data.hash:
            return "already_submitted"
    cracked_hash = {
        "timestamp": data.timestamp.isoformat()
        if hasattr(data.timestamp, "isoformat")
        else str(data.timestamp),
        "hash": data.hash,
        "plain_text": data.plain_text,
    }
    cracked_hashes.append(cracked_hash)
    task.error_details["cracked_hashes"] = cracked_hashes
    await db.commit()
    return None


__all__ = [
    "AgentNotAssignedError",
    "InvalidAgentTokenError",
    "TaskNotFoundError",
    "TaskNotRunningError",
    "get_new_task_service_v2",
    "heartbeat_agent_service_v2",
    "register_agent_service_v2",
    "submit_cracked_hash_service_v2",
    "submit_task_result_service_v2",
    "update_agent_state_service_v2",
    "update_task_progress_service_v2",
]
