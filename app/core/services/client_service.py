# mypy: disable-error-code="attr-defined"
import secrets
from collections.abc import Sequence
from datetime import UTC, datetime

from fastapi import Request
from packaging.version import InvalidVersion, Version
from sqlalchemy import Result, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import (
    InvalidAgentTokenError,
)
from app.core.logging import logger
from app.models.agent import Agent, AgentState
from app.models.cracker_binary import CrackerBinary
from app.models.operating_system import OSName
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
    token: str = authorization.removeprefix("Bearer ").strip()
    result: Result[tuple[Agent]] = await db.execute(
        select(Agent).filter(Agent.token == token)
    )
    agent: Agent | None = result.scalar_one_or_none()
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
    token: str = authorization.removeprefix("Bearer ").strip()
    result: Result[tuple[Agent]] = await db.execute(
        select(Agent).filter(Agent.token == token)
    )
    agent: Agent | None = result.scalar_one_or_none()
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
    token: str = authorization.removeprefix("Bearer ").strip()
    agent_result: Result[tuple[Agent]] = await db.execute(
        select(Agent).filter(Agent.token == token)
    )
    agent: Agent | None = agent_result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Invalid agent token")
    task_result: Result[tuple[Task]] = await db.execute(
        select(Task).filter(Task.id == task_id)
    )
    task: Task | None = task_result.scalar_one_or_none()
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
    token: str = authorization.removeprefix("Bearer ").strip()
    agent_result: Result[tuple[Agent]] = await db.execute(
        select(Agent).filter(Agent.token == token)
    )
    agent: Agent | None = agent_result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Invalid agent token")
    task_result: Result[tuple[Task]] = await db.execute(
        select(Task).filter(Task.id == task_id)
    )
    task: Task | None = task_result.scalar_one_or_none()
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
    try:
        if not authorization.startswith("Bearer csa_"):
            raise InvalidAgentTokenError("Invalid or missing agent token")
        token: str = authorization.removeprefix("Bearer ").strip()
        agent_result: Result[tuple[Agent]] = await db.execute(
            select(Agent)
            .options(selectinload(Agent.benchmarks))
            .filter(Agent.token == token)
        )
        agent: Agent | None = agent_result.scalar_one_or_none()
        if not agent:
            raise InvalidAgentTokenError("Invalid agent token")
        if not agent.benchmarks or len(agent.benchmarks) == 0:
            raise TaskNotFoundError(
                f"Agent {agent.id} has no benchmark data; skipping task assignment."
            )
        task_result: Result[tuple[Task]] = await db.execute(
            select(Task).filter(Task.status == TaskStatus.PENDING)
        )
        pending_tasks: Sequence[Task] = task_result.scalars().all()
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
    except Exception:
        logger.exception("Task assignment failed (v2 service)")
        raise


async def submit_cracked_hash_service_v2(
    task_id: int,
    data: HashcatResult,
    db: AsyncSession,
    authorization: str,
) -> str | None:
    if not authorization.startswith("Bearer csa_"):
        raise InvalidAgentTokenError("Invalid or missing agent token")
    token: str = authorization.removeprefix("Bearer ").strip()
    agent_result: Result[tuple[Agent]] = await db.execute(
        select(Agent).filter(Agent.token == token)
    )
    agent: Agent | None = agent_result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Invalid agent token")
    task_result: Result[tuple[Task]] = await db.execute(
        select(Task).filter(Task.id == task_id)
    )
    task: Task | None = task_result.scalar_one_or_none()
    if not task:
        raise TaskNotFoundError("Task not found")
    if task.agent_id != agent.id:
        raise AgentNotAssignedError("Agent not assigned to this task")
    if task.status != TaskStatus.RUNNING:
        raise TaskNotRunningError("Task is not running")
    # Clean SQLAlchemy change tracking pattern
    error_details = task.error_details or {}
    logger.debug(f"[submit_cracked_hash_service_v2] BEFORE mutation: {error_details}")
    cracked_hashes = error_details.get("cracked_hashes", [])
    if not isinstance(cracked_hashes, list):
        cracked_hashes = []
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
    error_details["cracked_hashes"] = cracked_hashes
    task.error_details = error_details
    logger.debug(
        f"[submit_cracked_hash_service_v2] AFTER mutation: {task.error_details}"
    )
    await db.commit()
    await db.refresh(task)
    return None


async def get_latest_cracker_binary_for_os(
    db: AsyncSession, os_name: OSName
) -> CrackerBinary | None:
    """Return the latest CrackerBinary for the given OS, using semantic version ordering."""
    result: Result[tuple[CrackerBinary]] = await db.execute(
        select(CrackerBinary).where(CrackerBinary.operating_system == os_name)
    )
    binaries: Sequence[CrackerBinary] = result.scalars().all()
    if not binaries:
        return None

    # Use packaging.version.Version to select the latest
    def safe_version(b: CrackerBinary) -> Version:
        try:
            return Version(b.version)
        except InvalidVersion:
            return Version("0.0.0")

    return max(binaries, key=safe_version)


__all__ = [
    "AgentNotAssignedError",
    "InvalidAgentTokenError",
    "TaskNotFoundError",
    "TaskNotRunningError",
    "get_latest_cracker_binary_for_os",
    "get_new_task_service_v2",
    "heartbeat_agent_service_v2",
    "register_agent_service_v2",
    "submit_cracked_hash_service_v2",
    "submit_task_result_service_v2",
    "update_agent_state_service_v2",
    "update_task_progress_service_v2",
]
