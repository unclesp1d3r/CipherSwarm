import secrets
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
from fastapi import Request
from loguru import logger
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

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
from app.models.agent_device_performance import AgentDevicePerformance
from app.models.agent_error import AgentError, Severity
from app.models.attack import Attack
from app.models.campaign import Campaign
from app.models.crack_result import CrackResult
from app.models.hash_list import HashList
from app.models.hash_type import HashType
from app.models.hashcat_benchmark import HashcatBenchmark
from app.models.task import Task, TaskStatus
from app.models.user import User
from app.schemas.agent import (
    AdvancedAgentConfiguration,
    AgentBenchmark,
    AgentErrorV1,
    AgentHeartbeatRequest,
    AgentRegisterRequest,
    AgentRegisterResponse,
    AgentStateUpdateRequest,
    DevicePerformancePoint,
    DevicePerformanceSeries,
)
from app.schemas.task import (
    TaskProgressUpdate,
    TaskResultSubmit,
    TaskStatusUpdate,
)

__all__ = [
    "AgentForbiddenError",
    "AgentNotAssignedError",
    "AgentNotFoundError",
    "TaskNotRunningError",
    "can_handle_hash_type",
    "get_agent_benchmark_summary_service",
    "get_agent_device_performance_timeseries",
    "get_agent_error_log_service",
    "get_agent_service",
    "list_agents_service",
    "record_agent_device_performance",
    "send_heartbeat_service",
    "shutdown_agent_service",
    "submit_benchmark_service",
    "submit_cracked_hash_service",
    "submit_error_service",
    "submit_task_result_service",
    "submit_task_status_service",
    "test_presigned_url_service",
    "toggle_agent_enabled_service",
    "trigger_agent_benchmark_service",
    "update_agent_config_service",
    "update_agent_devices_service",
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
    agent_id: int, current_agent: Agent, db: AsyncSession, error: AgentErrorV1
) -> None:
    if current_agent.id != agent_id:
        raise AgentForbiddenError("Not authorized to submit errors for this agent")
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError("Agent not found")

    # Severity must be a valid enum value
    try:
        severity = Severity(error.severity)
    except ValueError as err:
        raise ValueError(f"Invalid severity: {error.severity}") from err

    agent_error = AgentError(
        message=error.message,
        severity=severity,
        error_code=None,  # Not present in v1 schema
        details=error.metadata,
        agent_id=agent_id,
        task_id=error.task_id,
    )
    db.add(agent_error)

    # Set agent state to error if severity is major, critical, or fatal
    if severity in {Severity.major, Severity.critical, Severity.fatal}:
        agent.state = AgentState.error

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
    task_result = await db.execute(
        select(Task)
        .options(
            selectinload(Task.attack)
            .selectinload(Attack.campaign)
            .selectinload(Campaign.hash_list)
            .selectinload(HashList.items)
        )
        .filter(Task.id == task_id)
    )
    task = task_result.scalar_one_or_none()
    if not task:
        raise TaskNotFoundError("Task not found")
    if task.agent_id is None or task.agent_id != agent.id:
        raise AgentNotAssignedError("Agent not assigned to this task")
    if task.status != TaskStatus.RUNNING:
        raise TaskNotRunningError("Task is not running")
    # Update status and error_message
    if data.error:
        task.status = TaskStatus.FAILED
        task.error_message = data.error
    else:
        task.status = TaskStatus.COMPLETED
        task.error_message = None
    # Update error_details with metadata and cracked_hashes if present
    details = task.error_details.copy() if task.error_details else {}
    if data.metadata is not None:
        details["metadata"] = data.metadata
    else:
        details.pop("metadata", None)
    if data.cracked_hashes:
        details["cracked_hashes"] = data.cracked_hashes
    else:
        details.pop("cracked_hashes", None)
    task.error_details = details if details else None
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
) -> dict[
    int, list[dict[str, Any]]
]:  # TODO: I hate sloppy, untyped dicts as return types. This MUST be fixed.
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


async def update_agent_config_service(
    agent_id: int, config: AdvancedAgentConfiguration, db: AsyncSession
) -> Agent:
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError("Agent not found")
    # Validate and update config
    agent.advanced_configuration = config.model_dump()
    await db.commit()
    await db.refresh(agent)
    return agent


async def get_agent_error_log_service(
    agent_id: int, db: AsyncSession, limit: int = 50
) -> list[AgentError]:
    """Fetch recent AgentError log entries for the given agent, ordered by most recent."""
    result = await db.execute(
        select(AgentError)
        .where(AgentError.agent_id == agent_id)
        .order_by(AgentError.id.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def update_agent_devices_service(
    agent_id: int, enabled_indices: list[int], user: User, db: AsyncSession
) -> Agent:
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()
    if not agent:
        raise AgentNotFoundError("Agent not found")
    resource = f"agent:{agent.id}"
    # Allow system admins to always update
    if not (
        getattr(user, "is_superuser", False)
        or getattr(user, "role", None) == "admin"
        or user_can(user, resource, "update_agent")
    ):
        raise PermissionError("Not authorized to update agent devices")
    # Update backend_device in advanced_configuration
    if agent.advanced_configuration is None:
        agent.advanced_configuration = {}
    # Only allow indices that exist in agent.devices
    if not agent.devices:
        raise ValueError("Agent has no devices to toggle")
    max_index = len(agent.devices)
    for idx in enabled_indices:
        if idx < 1 or idx > max_index:
            raise ValueError(f"Invalid device index: {idx}")
    # Set backend_device as comma-separated string (empty string if none enabled)
    agent.advanced_configuration["backend_device"] = (
        ",".join(str(i) for i in sorted(enabled_indices)) if enabled_indices else ""
    )
    await db.commit()
    await db.refresh(agent)
    return agent


async def record_agent_device_performance(
    agent_id: int,
    device_speeds: dict[str, float],
    db: AsyncSession,
    timestamp: datetime | None = None,
) -> None:
    """
    Store a new AgentDevicePerformance row for each device with its speed and timestamp.

    Args:
        agent_id: The agent's ID
        device_speeds: Mapping of device name to current speed (guesses/sec)
        db: AsyncSession
        timestamp: Optional override for the measurement time (defaults to now)
    """
    now = timestamp or datetime.now(UTC)
    for device_name, speed in device_speeds.items():
        perf = AgentDevicePerformance(
            agent_id=agent_id,
            device_name=device_name,
            timestamp=now,
            speed=speed,
        )
        db.add(perf)
    await db.commit()


async def get_agent_device_performance_timeseries(
    agent_id: int,
    db: AsyncSession,
    window_hours: int = 8,
    buckets: int = 48,
) -> list[DevicePerformanceSeries]:
    """
    Retrieve reduced time series data for each device on the agent.
    Groups raw data into N buckets (e.g., 48 for 8 hours at 10-min intervals), averaging speed per bucket.
    Returns a list of DevicePerformanceSeries objects.
    """
    end_time = datetime.now(UTC)
    start_time = end_time - timedelta(hours=window_hours)
    interval = (end_time - start_time) / buckets

    device_names_result = await db.execute(
        select(AgentDevicePerformance.device_name)
        .where(AgentDevicePerformance.agent_id == agent_id)
        .distinct()
    )
    device_names = [row[0] for row in device_names_result.all()]
    series: list[DevicePerformanceSeries] = []
    for device in device_names:
        bucket_data: list[DevicePerformancePoint] = []
        for i in range(buckets):
            bucket_start = start_time + i * interval
            bucket_end = bucket_start + interval
            avg_result = await db.execute(
                select(func.avg(AgentDevicePerformance.speed))
                .where(AgentDevicePerformance.agent_id == agent_id)
                .where(AgentDevicePerformance.device_name == device)
                .where(AgentDevicePerformance.timestamp >= bucket_start)
                .where(AgentDevicePerformance.timestamp < bucket_end)
            )
            avg_speed = avg_result.scalar() or 0.0
            bucket_data.append(
                DevicePerformancePoint(
                    timestamp=bucket_start,
                    speed=avg_speed,
                )
            )
        series.append(DevicePerformanceSeries(device=device, data=bucket_data))
    return series


async def submit_cracked_hash_service(  # noqa: C901
    task_id: int,
    hash_value: str,
    plain_text: str,
    db: AsyncSession,
    authorization: str,
) -> None:
    """
    Accept a cracked hash for a task, update the associated HashItem with the new plain text,
    and create a CrackResult if not already present.
    """
    # Validate agent token
    if not authorization.startswith("Bearer csa_"):
        raise InvalidAgentTokenError("Invalid or missing agent token")
    token = authorization.removeprefix("Bearer ").strip()
    agent_result = await db.execute(select(Agent).filter(Agent.token == token))
    agent = agent_result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Invalid agent token")
    # Fetch task with all required relationships eagerly loaded
    task_result = await db.execute(
        select(Task)
        .options(
            selectinload(Task.attack)
            .selectinload(Attack.campaign)
            .selectinload(Campaign.hash_list)
            .selectinload(HashList.items)
        )
        .filter(Task.id == task_id)
    )
    task = task_result.scalar_one_or_none()
    if not task:
        raise TaskNotFoundError("Task not found")
    if task.agent_id is None or task.agent_id != agent.id:
        raise AgentNotAssignedError("Agent not assigned to this task")
    if task.status != TaskStatus.RUNNING:
        raise TaskNotRunningError("Task is not running")
    # Fetch attack, campaign, and hash list (now eagerly loaded)
    attack = task.attack
    if not attack or not attack.campaign or not attack.campaign.hash_list:
        raise TaskNotFoundError("Task not found")
    hash_list = attack.campaign.hash_list
    # Find the HashItem for the cracked hash
    hash_item = None
    for item in hash_list.items:
        if item.hash == hash_value:
            hash_item = item
            break
    if not hash_item:
        raise ValueError("Hash not found in hash list")
    # Update the HashItem with the plain text if not already set
    if hash_item.plain_text is None:
        hash_item.plain_text = plain_text
        await db.flush()
    # Create CrackResult if not already present for this agent/attack/hash_item
    crack_result_exists = await db.execute(
        select(CrackResult).filter(
            CrackResult.agent_id == agent.id,
            CrackResult.attack_id == attack.id,
            CrackResult.hash_item_id == hash_item.id,
        )
    )
    if not crack_result_exists.scalar_one_or_none():
        db.add(
            CrackResult(
                agent_id=agent.id,
                attack_id=attack.id,
                hash_item_id=hash_item.id,
            )
        )
        await db.flush()
    await db.commit()


# Handles submission of an agent task status update (not final result).
#
# This is the main status heartbeat endpoint for agents actively working on a task.
# It validates the agent identity, fetches the active task, and appends a new HashcatStatus record.
#
# This status includes the current hashcat output line, recovered counts, and estimated progress.
# It also optionally includes:
# - a HashcatGuess record (describing the current base/mod candidate context)
# - one or more DeviceStatus records (with temperature, utilization, and speed)
#
# ❗This service must:
# - Reject unauthorized or incorrectly scoped agents
# - Enforce task ownership (agent must match)
# - Validate that task is still running
# - Require presence of both guess and device statuses
# - Return one of the following:
#     204 No Content (normal update accepted)
#     202 Accepted (stale task, update ignored)
#     410 Gone (paused task, update ignored)
#     422 Unprocessable Entity (bad guess or device payloads)
#
# Steps:
# 1. Authenticate the agent using the bearer token and validate `csa_*` prefix.
# 2. Load the matching task and ensure:
#     - It belongs to the current agent
#     - It is not finished or paused
# 3. Update `activity_timestamp` on the task to now.
# 4. Create a new HashcatStatus entry with the given metadata.
# 5. If a `hashcat_guess` is present:
#     - Build a new HashcatGuess model and populate its fields.
#     - Attach it to the new HashcatStatus instance.
#     - If missing or invalid, raise 422 with error message `"Guess not found"`.
# 6. If `device_statuses` or `devices` is present:
#     - Normalize the input (accept both `device_statuses` and legacy `devices`)
#     - For each device:
#         - Create a DeviceStatus model instance with speed, temperature, etc.
#         - Attach it to the new HashcatStatus
#     - If none are present, raise 422 with `"Device Statuses not found"`.
# 7. Save the HashcatStatus (with nested guess + devices) to the DB.
#     - If commit fails, raise 422 and include model validation errors.
# 8. Call `accept_status()` on the Task (inline logic per state machine)
#    If paused, return 410
#    If not running (stale/complete/failed/abandoned), return 202
#    Otherwise, return 204 No Content
#    See `docs/v2_rewrite_implementation_plan/core_algorithm_implementation_guide.md` for more details on State Machine logic.
# 9. If `accept_status()` fails validation, return 422 with task errors.
async def submit_task_status_service(  # noqa: C901
    task_id: int,
    data: TaskStatusUpdate,
    db: AsyncSession,
    authorization: str,
) -> int:
    """
    Implements the v1 agent status update contract. Returns HTTP status code to be used by the route handler.
    """
    # TODO: Update activity_timestamp on the task when a status update is received (see docstring step 3)
    # TODO: Encapsulate state transition logic in a method like accept_status() on the Task model/service (see docstring step 8)
    # TODO: Provide error details if state transition fails (for 422 Unprocessable Entity, see docstring step 9)
    from sqlalchemy import select
    from sqlalchemy.orm import selectinload

    from app.core.exceptions import InvalidAgentTokenError
    from app.core.services.client_service import (
        AgentNotAssignedError,
        TaskNotRunningError,
    )
    from app.models.agent import Agent
    from app.models.task import (
        DeviceStatus,
        HashcatGuess,
        Task,
        TaskStatus,
        TaskStatusUpdate,
    )

    # 1. Authenticate agent
    if not authorization.startswith("Bearer csa_"):
        raise InvalidAgentTokenError("Invalid or missing agent token")
    token = authorization.removeprefix("Bearer ").strip()
    result = await db.execute(select(Agent).filter(Agent.token == token))
    agent = result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Invalid agent token")

    # 2. Load the matching task and ensure agent ownership and status
    task_result = await db.execute(
        select(Task)
        .options(selectinload(Task.status_updates))
        .filter(Task.id == task_id)
    )
    task = task_result.scalar_one_or_none()
    if not task:
        raise TaskNotFoundError("Task not found")
    if task.agent_id is None or task.agent_id != agent.id:
        raise AgentNotAssignedError("Agent not assigned to this task")
    if task.status != TaskStatus.RUNNING:
        raise TaskNotRunningError("Task is not running")

    # 3. Validate and normalize input (Pydantic schema)
    if data.device_statuses:
        device_statuses = data.device_statuses
    else:
        raise ValueError("Device Statuses not found")
    if data.hashcat_guess is None:
        raise ValueError("Guess not found")

    # 4. Create TaskStatusUpdate ORM entry
    status_update = TaskStatusUpdate(
        task_id=task.id,
        original_line=data.original_line,
        time=data.time,
        session=data.session,
        status=data.status,
        target=data.target,
        progress={"progress": data.progress},
        restore_point=data.restore_point,
        recovered_hashes={"recovered_hashes": data.recovered_hashes},
        recovered_salts={"recovered_salts": data.recovered_salts},
        rejected=data.rejected,
        time_start=data.time_start,
        estimated_stop=data.estimated_stop,
    )
    db.add(status_update)
    await db.flush()

    # 5. Create and attach HashcatGuess
    guess = data.hashcat_guess
    guess_orm = HashcatGuess(
        status_update_id=status_update.id,
        guess_base=guess.guess_base,
        guess_base_count=guess.guess_base_count,
        guess_base_offset=guess.guess_base_offset,
        guess_base_percentage=guess.guess_base_percentage,
        guess_mod=guess.guess_mod,
        guess_mod_count=guess.guess_mod_count,
        guess_mod_offset=guess.guess_mod_offset,
        guess_mod_percentage=guess.guess_mod_percentage,
        guess_mode=guess.guess_mode,
    )
    db.add(guess_orm)
    await db.flush()
    status_update.hashcat_guess = guess_orm

    # 6. Create and attach DeviceStatus entries
    for dev in device_statuses:
        dev_orm = DeviceStatus(
            status_update_id=status_update.id,
            device_id=dev.device_id,
            device_name=dev.device_name,
            device_type=dev.device_type,
            speed=dev.speed,
            utilization=dev.utilization,
            temperature=dev.temperature,
        )
        db.add(dev_orm)
    await db.flush()
    # status_update.device_statuses relationship is populated by ORM

    # Record device performance timeseries for this agent (task_id:agent.add_timeseries_call)
    device_speeds = {dev.device_name: float(dev.speed) for dev in device_statuses}
    await record_agent_device_performance(agent.id, device_speeds, db)

    # 7. Save to DB
    try:
        await db.commit()
    except Exception as e:
        await db.rollback()
        raise ValueError(f"Failed to save status update: {e}") from e

    # 8. Call accept_status() on the Task (inline logic per state machine)
    # If paused, return 410
    if (
        getattr(task.status, "value", task.status) == "paused"
    ):  # TODO: These should be enums
        return 410
    # If not running (stale/complete/failed/abandoned), return 202
    if (
        getattr(task.status, "value", task.status) != "running" or task.is_complete
    ):  # TODO: These should be enums
        return 202
    # Otherwise, return 204 No Content
    return 204
