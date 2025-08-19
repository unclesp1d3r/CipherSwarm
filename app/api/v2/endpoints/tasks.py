import logging

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.decorators.error_handling import handle_agent_errors
from app.core.deps import get_current_agent_v2, get_db
from app.core.services.agent_v2_service import agent_v2_service
from app.models.agent import Agent
from app.schemas.agent_v2 import (
    TaskProgressResponseV2,
    TaskProgressUpdateV2,
    TaskResultResponseV2,
    TaskResultSubmissionV2,
)
from app.schemas.task import TaskOut

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/client/agents/tasks",
    tags=["Task Management"],
    responses={
        401: {"description": "Invalid or missing agent token"},
        403: {"description": "Task not assigned to this agent"},
        404: {"description": "Task not found"},
    },
)


@router.get(
    "/",
    response_model=list[TaskOut],
    summary="Get agent tasks",
    description="Get tasks assigned to the current agent",
)
@handle_agent_errors
async def get_tasks(
    skip: int = 0,
    limit: int = 100,
    status_filter: str | None = None,
    db: AsyncSession = Depends(get_db),
    current_agent: Agent = Depends(get_current_agent_v2),
) -> list[TaskOut]:
    """Get tasks assigned to the current agent."""
    return await agent_v2_service.get_agent_tasks_v2_service(
        db, current_agent, skip, limit, status_filter
    )


@router.get(
    "/{task_id}",
    response_model=TaskOut,
    summary="Get specific task",
    description="Get a specific task by ID",
)
@handle_agent_errors
async def get_task(
    task_id: str,
    db: AsyncSession = Depends(get_db),
    current_agent: Agent = Depends(get_current_agent_v2),
) -> TaskOut:
    """Get a specific task by ID."""
    return await agent_v2_service.get_task_v2_service(db, current_agent, task_id)


@router.get(
    "/next",
    response_model=TaskOut,
    summary="Get next available task",
    description="Get the next available task for the current agent",
)
@handle_agent_errors
async def get_next_task(
    db: AsyncSession = Depends(get_db),
    current_agent: Agent = Depends(get_current_agent_v2),
) -> TaskOut:
    """Get the next available task for the current agent."""
    return await agent_v2_service.get_next_task_v2_service(db, current_agent)


@router.post(
    "/{task_id}/progress",
    response_model=TaskProgressResponseV2,
    summary="Update task progress",
    description="Update the progress of a specific task",
)
@handle_agent_errors
async def update_task_progress(
    task_id: str,
    progress_update: TaskProgressUpdateV2,
    db: AsyncSession = Depends(get_db),
    current_agent: Agent = Depends(get_current_agent_v2),
) -> TaskProgressResponseV2:
    """Update the progress of a specific task."""
    return await agent_v2_service.update_task_progress_v2_service(
        db, current_agent, task_id, progress_update
    )


@router.post(
    "/{task_id}/results",
    response_model=TaskResultResponseV2,
    summary="Submit task results",
    description="Submit results for a completed task",
)
@handle_agent_errors
async def submit_task_results(
    task_id: str,
    results: TaskResultSubmissionV2,
    db: AsyncSession = Depends(get_db),
    current_agent: Agent = Depends(get_current_agent_v2),
) -> TaskResultResponseV2:
    """Submit results for a completed task."""
    return await agent_v2_service.submit_task_results_v2_service(
        db, current_agent, task_id, results
    )
