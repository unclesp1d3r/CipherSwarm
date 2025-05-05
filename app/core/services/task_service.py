from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import InvalidAgentTokenError, InvalidUserAgentError
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
    if not user_agent.startswith("CipherSwarm-Agent/"):
        raise InvalidUserAgentError("Invalid User-Agent header")
    if not authorization.startswith("Bearer csa_"):
        raise InvalidAgentTokenError("Invalid or missing agent token")
    token = authorization.removeprefix("Bearer ").strip()
    result = await db.execute(select(Agent).filter(Agent.token == token))
    agent = result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Invalid agent token")
    # Enforce one running task per agent
    running_task_result = await db.execute(
        select(Task).filter(
            Task.agent_id == agent.id, Task.status == TaskStatus.RUNNING
        )
    )
    running_task = running_task_result.scalar_one_or_none()
    if running_task:
        raise NoPendingTasksError("Agent already has a running task")
    result = await db.execute(
        select(Task).filter(Task.status == TaskStatus.PENDING, Task.agent_id.is_(None))
    )
    task = result.scalar_one_or_none()
    if not task:
        raise NoPendingTasksError("No pending tasks available")
    task.agent_id = agent.id
    task.status = TaskStatus.RUNNING
    await db.commit()
    await db.refresh(task)
    return TaskOut.model_validate(task, from_attributes=True)


__all__ = [
    "InvalidAgentTokenError",
    "NoPendingTasksError",
    "assign_task_service",
]
