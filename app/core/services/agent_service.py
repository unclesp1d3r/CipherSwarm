import secrets
from datetime import UTC, datetime
from typing import Any

import httpx
from fastapi import Request
from loguru import logger
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.authz import user_can
from app.core.exceptions import (
    AgentNotFoundError,
    InvalidAgentStateError,
    InvalidAgentTokenError,
)
from app.core.services.client_service import (
    AgentNotAssignedError,
    TaskNotRunningError,
)
from app.core.services.task_service import TaskNotFoundError
from app.models.agent import Agent, AgentState
from app.models.hash_type import HashType
from app.models.hashcat_benchmark import HashcatBenchmark
from app.models.task import Task, TaskStatus
from app.models.user import User
from app.schemas.agent import (
    AgentBenchmark,
    AgentHeartbeatRequest,
    AgentRegisterRequest,
    AgentRegisterResponse,
    AgentStateUpdateRequest,
)
from app.schemas.task import TaskProgressUpdate, TaskResultSubmit

__all__ = [
    "AgentForbiddenError",
    "AgentNotAssignedError",
    "AgentNotFoundError",
    "TaskNotRunningError",
    "can_handle_hash_type",
    "get_agent_benchmark_summary_service",
    "get_agent_service",
    "list_agents_service",
    "send_heartbeat_service",
    "shutdown_agent_service",
    "submit_benchmark_service",
    "submit_error_service",
    "submit_task_result_service",
    "test_presigned_url_service",
    "toggle_agent_enabled_service",
    "trigger_agent_benchmark_service",
    "update_agent_service",
    "update_agent_state_service",
    "update_task_progress_service",
]


async def register_agent_service(
    data: AgentRegisterRequest, db: AsyncSession
) -> AgentRegisterResponse:
    """Register a new agent and return an authentication token."""
    logger.debug("Entering register_agent_service with args: ...")
    # TODO: Check for existing agent by signature or hostname if required
    agent = Agent(
        host_name=data.hostname,
        client_signature=data.signature,
        agent_type=data.agent_type,
        state=AgentState.pending,
        token="temp",  # Will be replaced after flush  # noqa: S106
        operating_system=data.operating_system,
    )
    db.add(agent)
    await db.commit()
    await db.refresh(agent)

    # Generate token: csa_<agent_id>_<random>
    token = f"csa_{agent.id}_{secrets.token_urlsafe(16)}"
    agent.token = token
    await db.commit()
    await db.refresh(agent)

    logger.debug("Exiting register_agent_service with result: ...")
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
    # TODO: we need to think about what a missed heartbeat means.
    # one missed heartbeat should be noted, but two missed heartbeats should result in a state change.
    # we also need to think about how to handle the case where a client does not send a heartbeat for an extended period of time.
    # They could be offline, they could be dead, they could be compromised, they could be busy, they could be downloading a large file, etc.
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
    agent_id: int, agent_update: dict[str, Any], current_agent: Agent, db: AsyncSession
) -> Agent:
    if current_agent.id != agent_id:
        raise AgentForbiddenError("Not authorized to update this agent")
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError("Agent not found")
    for field, value in agent_update.items():
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

    # TODO: Once we have benchmark aggregation, we don't need to delete existing benchmarks for this agent,
    # we just add new ones with an updated timestamp and then benchmark aggregation will take care of the rest.
    # Until then, we need to delete the existing benchmarks for this agent.
    # TODO: we should probably delete the old benchmarks after a certain period of time to keep the database clean.
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
    agent_id: int, current_agent: Agent, db: AsyncSession, error: dict[str, Any]
) -> None:
    if current_agent.id != agent_id:
        raise AgentForbiddenError("Not authorized to submit errors for this agent")
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError("Agent not found")
    # An error does not necessarily mean the agent is in an error state.
    # It could just be a temporary error.
    # We should probably add a new error state to the agent.
    # We need to give errors a severity level and use that to determine if the agent should be put into an error state.
    # TODO: we should probably add a new error state to the agent.
    agent.state = AgentState.error
    # TODO: They should not go in the advanced_configuration dict, but into an errors table.
    if agent.advanced_configuration is None:
        agent.advanced_configuration = {}
    agent.advanced_configuration["last_error"] = error
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
    # TODO: We should probably add a new shutdown state to the agent.
    # TODO: We need to free up any tasks currently assigned to this agent.
    # TODO: We should also require a new set of benchmarks to be submitted after the agent is shutdown.
    agent.state = AgentState.stopped
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
    # This isn't an error, it's just a progress update.
    task.error_details["keyspace_processed"] = data.keyspace_processed
    await db.commit()


async def submit_task_result_service(  # noqa: C901
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
    error_details = task.error_details or {}
    logger.debug(f"[submit_task_result_service] BEFORE mutation: {error_details}")
    # v1 contract: cracked_hashes DO NOT need to be nested under error_details['result']['cracked_hashes']. cracked_hashes are derived from hash_list items.
    # STOP putting cracked_hashes in the error_details['result'] dict.
    result_dict = error_details.get("result")
    if not isinstance(result_dict, dict):
        result_dict = {}
    cracked_hashes = result_dict.get("cracked_hashes", [])
    if not isinstance(cracked_hashes, list):
        cracked_hashes = []
    # Append new hashes if not already present
    for entry in data.cracked_hashes:
        if not any(e.get("hash") == entry.get("hash") for e in cracked_hashes):
            cracked_hashes.append(entry)
    result_dict["cracked_hashes"] = cracked_hashes
    result_dict["metadata"] = data.metadata
    error_details["result"] = result_dict
    task.error_details = error_details
    logger.debug(f"[submit_task_result_service] AFTER mutation: {task.error_details}")
    if data.error:
        task.status = TaskStatus.FAILED
        task.error_message = data.error
    else:
        task.status = TaskStatus.COMPLETED
    await db.commit()
    await db.refresh(task)


async def list_agents_service(
    db: AsyncSession,
    search: str | None = None,
    state: str | None = None,
    page: int = 1,
    size: int = 20,
) -> tuple[list[Agent], int]:
    query = select(Agent)
    if search:
        query = query.filter(Agent.host_name.ilike(f"%{search}%"))
    if state:
        query = query.filter(Agent.state == state)
    total = (
        await db.execute(
            select(func.count().label("count")).select_from(query.subquery())
        )
    ).scalar_one()
    agents = (
        (await db.execute(query.offset((page - 1) * size).limit(size))).scalars().all()
    )
    return list(agents), total


async def get_agent_by_id_service(agent_id: int, db: AsyncSession) -> Agent | None:
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    return result.scalar_one_or_none()


async def toggle_agent_enabled_service(
    agent_id: int,
    user: User,
    db: AsyncSession,
) -> Agent:
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError("Agent not found")
    resource = f"agent:{agent.id}"
    if not user_can(user, resource, "toggle_agent"):
        raise PermissionError("Not authorized to toggle agent state")
    agent.enabled = not agent.enabled
    await db.commit()
    await db.refresh(agent)
    return agent


async def get_agent_benchmark_summary_service(
    agent_id: int, db: AsyncSession
) -> dict[int, list[dict[str, Any]]]:
    """
    Fetch all benchmarks for the agent, grouped by hash_type_id, with hash type info and per-device breakdown.
    Returns a dict: {hash_type_id: [ {hash_type_name, hash_type_description, hash_speed, device, runtime, created_at}, ... ]}
    """
    result = await db.execute(
        select(HashcatBenchmark, HashType)
        .join(HashType, HashcatBenchmark.hash_type_id == HashType.id)
        .where(HashcatBenchmark.agent_id == agent_id)
        .order_by(HashcatBenchmark.hash_type_id, HashcatBenchmark.device)
    )
    rows = result.all()
    if not rows:
        # Check if agent exists
        agent_result = await db.execute(select(Agent).filter(Agent.id == agent_id))
        agent = agent_result.scalar_one_or_none()
        if not agent:
            raise AgentNotFoundError(f"Agent {agent_id} not found")
    benchmarks_by_hash_type: dict[int, list[dict[str, Any]]] = {}
    for b, ht in rows:
        key = b.hash_type_id
        if key not in benchmarks_by_hash_type:
            benchmarks_by_hash_type[key] = []
        benchmarks_by_hash_type[key].append(
            {
                "hash_type_id": b.hash_type_id,
                "hash_type_name": ht.name,
                "hash_type_description": ht.description,
                "hash_speed": b.hash_speed,
                "device": b.device,
                "runtime": b.runtime,
                "created_at": b.created_at,
            }
        )
    return benchmarks_by_hash_type


async def can_handle_hash_type(
    agent_id: int, hash_type_id: int, db: AsyncSession
) -> bool:
    """
    Return True if the agent has a benchmark for the given hash_type_id, else False.
    Raise AgentNotFoundError if the agent does not exist.
    """
    # Check if agent exists
    agent_result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = agent_result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError(f"Agent {agent_id} not found")
    # Check for benchmark
    result = await db.execute(
        select(HashcatBenchmark)
        .where(HashcatBenchmark.agent_id == agent_id)
        .where(HashcatBenchmark.hash_type_id == hash_type_id)
    )
    return result.scalar_one_or_none() is not None


async def trigger_agent_benchmark_service(
    agent_id: int, user: User, db: AsyncSession
) -> Agent:
    """Set the agent's state to 'pending' to trigger a benchmark run. Only allowed for authorized users."""
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError("Agent not found")
    resource = f"agent:{agent.id}"
    if not user_can(user, resource, "trigger_benchmark"):
        raise PermissionError("Not authorized to trigger benchmark for this agent")
    agent.state = AgentState.pending
    await db.commit()
    await db.refresh(agent)
    return agent


async def test_presigned_url_service(url: str) -> bool:
    """Test if a presigned S3/MinIO URL is accessible (HTTP 200 HEAD)."""
    try:
        client = httpx.AsyncClient(follow_redirects=False, timeout=3.0)
        resp = await client.head(url)
        await client.aclose()
    except Exception as e:  # noqa: BLE001 - network errors must be caught here
        logger.warning(f"Presigned URL test failed: {e}")
        return False
    else:
        return resp.status_code == httpx.codes.OK
