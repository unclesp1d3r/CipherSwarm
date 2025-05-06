from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import InvalidAgentTokenError, InvalidUserAgentError
from app.core.logging import logger
from app.models.agent import Agent
from app.models.task import Task, TaskStatus
from app.schemas.task import TaskOut

# mypy: disable-error-code="attr-defined"


class NoPendingTasksError(Exception):
    pass


async def assign_task_service(
    db: AsyncSession,
    authorization: str,
    user_agent: str,
) -> TaskOut:
    try:
        if not user_agent.startswith("CipherSwarm-Agent/"):
            raise InvalidUserAgentError("Invalid User-Agent header")
        if not authorization.startswith("Bearer csa_"):
            raise InvalidAgentTokenError("Invalid or missing agent token")
        token = authorization.removeprefix("Bearer ").strip()
        result = await db.execute(
            select(Agent)
            .options(selectinload(Agent.benchmarks))
            .filter(Agent.token == token)
        )
        agent = result.scalar_one_or_none()
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
        result = await db.execute(
            select(Task).filter(
                Task.status == TaskStatus.PENDING, Task.agent_id.is_(None)
            )
        )
        pending_tasks = result.scalars().all()
        for task in pending_tasks:
            # Ensure attack is loaded
            if not hasattr(task, "attack") or task.attack is None:
                await db.refresh(task, attribute_names=["attack"])
            # Part B: Exclude tasks with zero keyspace
            if task.keyspace_total <= 0:
                # Optionally log here
                continue
            if agent.can_handle_hash_type(task.attack.hash_type_id):
                task.agent_id = agent.id
                task.status = TaskStatus.RUNNING
                await db.commit()
                await db.refresh(task)
                return TaskOut.model_validate(task, from_attributes=True)
        raise NoPendingTasksError("No compatible pending tasks available")
    except Exception:
        logger.exception("Task assignment failed (v1 service)")
        raise


__all__ = [
    "InvalidAgentTokenError",
    "NoPendingTasksError",
    "assign_task_service",
]
