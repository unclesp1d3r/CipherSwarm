from collections.abc import Sequence

from sqlalchemy import Result, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import InvalidAgentTokenError
from app.core.logging import logger
from app.core.services.client_service import AgentNotAssignedError
from app.models.agent import Agent
from app.models.hash_item import HashItem
from app.models.hash_list import HashList, hash_list_items
from app.models.task import Task, TaskStatus
from app.schemas.task import TaskOutV1

# mypy: disable-error-code="attr-defined"


class NoPendingTasksError(Exception):
    pass


class TaskNotFoundError(Exception):
    pass


class TaskAlreadyCompletedError(Exception):
    pass


class TaskAlreadyExhaustedError(Exception):
    pass


class TaskAlreadyAbandonedError(Exception):
    pass


async def assign_task_service(
    db: AsyncSession,
    authorization: str,
    _user_agent: str,
) -> TaskOutV1:
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
        # Part A: Exclude agents without benchmarks
        if not agent.benchmarks or len(agent.benchmarks) == 0:
            # Optionally log here
            raise NoPendingTasksError(
                f"Agent {agent.id} has no benchmark data; skipping task assignment."
            )
        # Enforce one running task per agent
        running_task_result = await db.execute(
            select(Task).filter(
                Task.agent_id == agent.id, Task.status == TaskStatus.RUNNING
            )
        )
        running_task = running_task_result.scalar_one_or_none()
        if running_task:
            raise NoPendingTasksError("Agent already has a running task")
        # Iterate over pending tasks and assign the first compatible one
        task_result: Result[tuple[Task]] = await db.execute(
            select(Task)
            .options(selectinload(Task.attack))
            .filter(Task.status == TaskStatus.PENDING, Task.agent_id.is_(None))
        )
        pending_tasks: Sequence[Task] = task_result.scalars().all()
        for task in pending_tasks:
            # Attack should be loaded via selectinload
            if not task.attack:
                continue  # Skip tasks without valid attack
            # Part B: Exclude tasks with zero keyspace
            if task.keyspace_total <= 0:
                # Optionally log here
                continue
            if agent.can_handle_hash_type(task.attack.hash_mode):
                task.agent_id = agent.id
                task.status = TaskStatus.RUNNING
                await db.commit()
                await db.refresh(task)
                return TaskOutV1.model_validate(
                    {
                        "id": task.id,
                        "attack_id": task.attack_id,
                        "start_date": task.start_date,
                        "status": str(task.status.value)
                        if hasattr(task.status, "value")
                        else str(task.status),
                        "skip": task.skip,
                        "limit": task.limit,
                    }
                )
        raise NoPendingTasksError("No compatible pending tasks available")
    except NoPendingTasksError:
        # Re-raise business logic exceptions without logging as errors
        # This is not an error, it's a business logic exception
        raise
    except Exception:
        logger.exception("Task assignment failed (v1 service)")
        raise


async def get_task_by_id_service(
    task_id: int,
    db: AsyncSession,
    authorization: str,
) -> TaskOutV1:
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
    if task.agent_id != agent.id:
        raise PermissionError("Agent not assigned to this task")
    return TaskOutV1.model_validate(
        {
            "id": task.id,
            "attack_id": task.attack_id,
            "start_date": task.start_date,
            "status": str(task.status.value)
            if hasattr(task.status, "value")
            else str(task.status),
            "skip": task.skip,
            "limit": task.limit,
        }
    )


async def accept_task_service(
    task_id: int,
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
    if task.status != TaskStatus.PENDING:
        raise TaskAlreadyCompletedError("Task already completed")
    if task.agent_id is not None and task.agent_id != agent.id:
        raise PermissionError("Task already assigned to another agent")
    # Assign the agent and set status to RUNNING
    task.agent_id = agent.id
    task.status = TaskStatus.RUNNING
    await db.commit()
    await db.refresh(task)


async def exhaust_task_service(
    task_id: int,
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
    if task.agent_id != agent.id:
        raise PermissionError("Agent not assigned to this task")
    if task.status in [TaskStatus.COMPLETED, TaskStatus.FAILED, TaskStatus.ABANDONED]:
        raise TaskAlreadyExhaustedError("Task already completed or exhausted")
    # Mark as completed (exhausted means no more techniques, so task is done)
    # TODO: Add a new status for exhausted tasks
    task.status = TaskStatus.COMPLETED
    await db.commit()
    await db.refresh(task)


async def abandon_task_service(
    task_id: int,
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
    task_result: Result[tuple[Task]] = await db.execute(
        select(Task).filter(Task.id == task_id)
    )
    task: Task | None = task_result.scalar_one_or_none()
    if not task:
        raise TaskNotFoundError("Task not found")
    if task.agent_id != agent.id:
        raise PermissionError("Agent not assigned to this task")
    if task.status == TaskStatus.ABANDONED:
        raise TaskAlreadyAbandonedError("Task already abandoned")
    if task.status in [TaskStatus.COMPLETED, TaskStatus.FAILED]:
        raise TaskAlreadyCompletedError("Task already completed")
    # Mark as abandoned
    task.status = TaskStatus.ABANDONED
    await db.commit()
    await db.refresh(task)


async def get_task_zaps_service(
    task_id: int,
    db: AsyncSession,
    authorization: str,
) -> list[str]:
    """
    Returns a list of cracked hash values for the given task, enforcing v1 contract:
    - 401 if Authorization is missing/invalid or agent not found
    - 404 if task not found
    - 403 if agent is not assigned to the task
    - 422 if task is completed/abandoned (only if agent is assigned)
    - 200 with cracked hashes (one per line) otherwise
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise InvalidAgentTokenError("Bad credentials")
    agent_token = authorization.removeprefix("Bearer ").strip()
    # Validate agent token
    agent_result = await db.execute(select(Agent).filter(Agent.token == agent_token))
    agent = agent_result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Bad credentials")
    # Fetch task
    result = await db.execute(
        select(Task).options(selectinload(Task.attack)).where(Task.id == task_id)
    )
    task = result.scalar_one_or_none()
    if not task:
        raise TaskNotFoundError("Task not found")
    # Check agent assignment
    if not task.agent_id or task.agent_id != agent.id:
        raise AgentNotAssignedError("Forbidden")
    # Only after agent assignment check, check for completed/abandoned
    if task.status in [TaskStatus.COMPLETED, TaskStatus.ABANDONED]:
        raise TaskAlreadyCompletedError("Task already completed")
    # Legacy contract: cracked hashes are those HashItems in the HashList with non-null plain_text
    if not task.attack:
        raise TaskNotFoundError("Task not found")
    hash_list_id = task.attack.hash_list_id
    if not hash_list_id:
        raise TaskNotFoundError("Task not found")
    # Fetch the HashList to ensure it exists
    hash_list_result = await db.execute(
        select(HashList.id).where(HashList.id == hash_list_id)
    )
    if not hash_list_result.scalar_one_or_none():
        raise TaskNotFoundError("Task not found")

    # Fetch cracked hashes directly
    cracked_hashes_result = await db.execute(
        select(HashItem.hash)
        .join(hash_list_items)
        .where(hash_list_items.c.hash_list_id == hash_list_id)
        .where(HashItem.plain_text.isnot(None))
    )
    return cracked_hashes_result.scalars().all()


__all__ = [
    "InvalidAgentTokenError",
    "NoPendingTasksError",
    "TaskAlreadyAbandonedError",
    "TaskAlreadyCompletedError",
    "TaskAlreadyExhaustedError",
    "TaskNotFoundError",
    "abandon_task_service",
    "accept_task_service",
    "assign_task_service",
    "exhaust_task_service",
    "get_task_by_id_service",
    "get_task_zaps_service",
]
