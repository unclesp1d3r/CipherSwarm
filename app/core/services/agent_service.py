import secrets
from datetime import UTC, datetime

from fastapi import Request
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import (
    AgentNotFoundError,
    InvalidAgentStateError,
    InvalidAgentTokenError,
)
from app.core.services.client_service import (
    AgentNotAssignedError,
    TaskNotFoundError,
    TaskNotRunningError,
)
from app.models.agent import Agent, AgentState
from app.models.hashcat_benchmark import HashcatBenchmark
from app.models.task import Task, TaskStatus
from app.schemas.agent import (
    AgentBenchmark,
    AgentHeartbeatRequest,
    AgentRegisterRequest,
    AgentRegisterResponse,
    AgentStateUpdateRequest,
    AgentUpdate,
)
from app.schemas.task import TaskProgressUpdate, TaskResultSubmit

__all__ = [
    "AgentForbiddenError",
    "AgentNotFoundError",
    "get_agent_service",
    "send_heartbeat_service",
    "shutdown_agent_service",
    "submit_benchmark_service",
    "submit_error_service",
    "submit_task_result_service",
    "update_agent_service",
    "update_agent_state_service",
    "update_task_progress_service",
]


async def register_agent_service(
    data: AgentRegisterRequest, db: AsyncSession
) -> AgentRegisterResponse:
    """Register a new agent and return an authentication token."""
    # TODO: Check for existing agent by signature or hostname if required
    agent = Agent(
        host_name=data.hostname,
        client_signature=data.signature,
        agent_type=data.agent_type,
        state=AgentState.pending,
        token="temp",  # Will be replaced after flush  # noqa: S106
        operating_system_id=data.operating_system_id,
    )
    db.add(agent)
    await db.commit()
    await db.refresh(agent)

    # Generate token: csa_<agent_id>_<random>
    token = f"csa_{agent.id}_{secrets.token_urlsafe(16)}"
    agent.token = token
    await db.commit()
    await db.refresh(agent)

    return AgentRegisterResponse(agent_id=agent.id, token=token)


async def heartbeat_agent_service(
    request: Request,
    data: AgentHeartbeatRequest,
    db: AsyncSession,
    authorization: str,
) -> None:
    """Process agent heartbeat: update last_seen_at and state."""
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
        raise InvalidAgentStateError("Invalid agent state")
    agent.state = data.state
    await db.commit()


class AgentForbiddenError(Exception):
    pass


async def get_agent_service(
    agent_id: int, current_agent: Agent, db: AsyncSession
) -> Agent:
    if current_agent.id != agent_id:
        raise AgentForbiddenError("Not authorized to access this agent")
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError("Agent not found")
    return agent


async def update_agent_service(
    agent_id: int, agent_update: AgentUpdate, current_agent: Agent, db: AsyncSession
) -> Agent:
    if current_agent.id != agent_id:
        raise AgentForbiddenError("Not authorized to update this agent")
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError("Agent not found")
    for field, value in agent_update.dict(exclude_unset=True).items():
        setattr(agent, field, value)
    await db.commit()
    await db.refresh(agent)
    return agent


async def send_heartbeat_service(
    agent_id: int, current_agent: Agent, db: AsyncSession
) -> None:
    if current_agent.id != agent_id:
        raise AgentForbiddenError("Not authorized to send heartbeat for this agent")
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError("Agent not found")
    agent.last_seen_at = datetime.now(UTC)
    await db.commit()


async def submit_benchmark_service(
    agent_id: int, benchmark: AgentBenchmark, current_agent: Agent, db: AsyncSession
) -> None:
    if current_agent.id != agent_id:
        raise AgentForbiddenError("Not authorized to submit benchmarks for this agent")
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError("Agent not found")
    # Remove existing benchmarks for this agent (full replace)
    await db.execute(
        delete(HashcatBenchmark).where(HashcatBenchmark.agent_id == agent_id)
    )
    # Insert new benchmarks
    for b in benchmark.hashcat_benchmarks:
        db.add(
            HashcatBenchmark(
                agent_id=agent_id,
                hash_type_id=int(b.hash_type),
                runtime=b.runtime,
                hash_speed=b.hash_speed,
                device=str(b.device),
            )
        )
    await db.commit()


async def submit_error_service(
    agent_id: int, current_agent: Agent, db: AsyncSession
) -> None:
    if current_agent.id != agent_id:
        raise AgentForbiddenError("Not authorized to submit errors for this agent")
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError("Agent not found")
    agent.state = AgentState.error
    # TODO: Store error details
    await db.commit()


async def shutdown_agent_service(
    agent_id: int, current_agent: Agent, db: AsyncSession
) -> None:
    if current_agent.id != agent_id:
        raise AgentForbiddenError("Not authorized to shutdown this agent")
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError("Agent not found")
    agent.state = AgentState.disabled
    await db.commit()


async def update_agent_state_service(
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
        raise InvalidAgentStateError("Invalid agent state")
    agent.state = data.state
    await db.commit()


async def update_task_progress_service(
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
    task_result = await db.execute(select(Task).filter(Task.id == task_id))
    task = task_result.scalar_one_or_none()
    if not task:
        raise TaskNotFoundError("Task not found")
    if task.agent_id is None or task.agent_id != agent.id:
        raise AgentNotAssignedError("Agent not assigned to this task")
    if task.status != TaskStatus.RUNNING:
        raise TaskNotRunningError("Task is not running")
    task.progress = data.progress_percent
    if not task.error_details:
        task.error_details = {}
    task.error_details["keyspace_processed"] = data.keyspace_processed
    await db.commit()


async def submit_task_result_service(
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
    task_result = await db.execute(select(Task).filter(Task.id == task_id))
    task = task_result.scalar_one_or_none()
    if not task:
        raise TaskNotFoundError("Task not found")
    if task.agent_id is None or task.agent_id != agent.id:
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
