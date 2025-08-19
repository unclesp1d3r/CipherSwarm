"""
Agent API v2 Service Layer

This module contains all business logic for Agent API v2 operations.
All API endpoints delegate to these service functions.
"""

import logging
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import SecureTokenGenerator
from app.crud import resource as crud_resource
from app.models.agent import Agent
from app.models.attack import Attack
from app.models.hash_type import HashType
from app.models.resource import Resource
from app.models.task import Task
from app.schemas.agent_v2 import (
    AgentHeartbeatRequestV2,
    AgentHeartbeatResponseV2,
    AgentInfoResponseV2,
    AgentRegisterRequestV2,
    AgentRegisterResponseV2,
    AgentUpdateRequestV2,
    AgentUpdateResponseV2,
    AttackConfigurationResponseV2,
    ResourceUrlResponseV2,
    TaskPriorityV2,
    TaskProgressResponseV2,
    TaskProgressUpdateV2,
    TaskResultResponseV2,
    TaskResultSubmissionV2,
)
from app.schemas.task import TaskOut

logger = logging.getLogger(__name__)


class AgentV2Service:
    """Service class for Agent API v2 operations."""

    @staticmethod
    async def register_agent_v2_service(
        db: AsyncSession, registration_data: AgentRegisterRequestV2
    ) -> AgentRegisterResponseV2:
        """
        Register a new agent in the system.

        Args:
            db: Database session
            registration_data: Agent registration request data

        Returns:
            AgentRegisterResponseV2: Registration response with agent ID and token

        Raises:
            ValueError: If registration fails due to validation errors
        """
        try:
            logger.info(
                f"Registering new agent with signature: {registration_data.signature}"
            )

            # Generate secure temporary token
            temp_token = SecureTokenGenerator.generate_temp_token()

            # Create agent record
            agent_data = {
                "name": registration_data.signature,
                "description": f"Agent on {registration_data.hostname}",
                "version": registration_data.version,
                "capabilities": registration_data.capabilities
                or settings.AGENT_V2_DEFAULT_CAPABILITIES,
                "supported_task_types": settings.AGENT_V2_DEFAULT_CAPABILITIES,
                "token": temp_token,
            }

            # Create agent directly
            agent = Agent(
                name=agent_data["name"],
                description=agent_data["description"],
                version=agent_data["version"],
                capabilities=agent_data["capabilities"],
                supported_task_types=agent_data["supported_task_types"],
                token=agent_data["token"],
            )
            db.add(agent)
            await db.commit()
            await db.refresh(agent)

            # Generate final secure token with agent ID
            final_token = SecureTokenGenerator.generate_agent_token(agent.id)

            # Update agent with final token
            agent.token = final_token
            await db.commit()
            await db.refresh(agent)

            logger.info(f"Successfully registered agent {agent.id}")

            return AgentRegisterResponseV2(
                agent_id=str(agent.id),
                token=final_token,
                expires_at=datetime.now(UTC)
                + timedelta(days=settings.AGENT_V2_TOKEN_EXPIRY_DAYS),
                server_version=settings.AGENT_V2_SERVER_VERSION,
                heartbeat_interval=settings.AGENT_V2_DEFAULT_HEARTBEAT_INTERVAL,
            )

        except Exception as e:
            logger.exception("Failed to register agent")
            raise ValueError(f"Agent registration failed: {e!s}") from e

    @staticmethod
    async def process_heartbeat_v2_service(
        db: AsyncSession,
        agent: Agent,
        heartbeat_data: AgentHeartbeatRequestV2 | None = None,
    ) -> AgentHeartbeatResponseV2:
        """
        Process agent heartbeat and update agent status.

        Args:
            db: Database session
            agent: Current agent
            heartbeat_data: Optional heartbeat data

        Returns:
            AgentHeartbeatResponseV2: Heartbeat response
        """
        try:
            logger.debug(f"Processing heartbeat for agent {agent.id}")

            # Update agent heartbeat
            agent.last_seen_at = datetime.now(UTC)
            if heartbeat_data and hasattr(heartbeat_data, "state"):
                # Update agent state if provided
                agent.state = heartbeat_data.state
            await db.commit()
            await db.refresh(agent)

            return AgentHeartbeatResponseV2(
                status="ok",
                timestamp=datetime.now(UTC),
                agent_id=str(agent.id),
                instructions=None,  # TODO: Implement server instructions
                next_heartbeat_in=settings.AGENT_V2_DEFAULT_NEXT_HEARTBEAT_IN,
            )

        except Exception as e:
            logger.exception(f"Failed to process heartbeat for agent {agent.id}")
            raise ValueError(f"Heartbeat processing failed: {e!s}") from e

    @staticmethod
    async def get_agent_info_v2_service(
        db: AsyncSession, agent: Agent
    ) -> AgentInfoResponseV2:
        """
        Get agent information.

        Args:
            db: Database session
            agent: Current agent

        Returns:
            AgentInfoResponseV2: Agent information
        """
        try:
            # Get agent statistics in a single optimized query
            result = await db.execute(
                select(
                    func.count(Task.id).label("total_tasks"),
                    func.count(Task.id)
                    .filter(Task.status == "in_progress")
                    .label("active_tasks"),
                ).filter(Task.agent_id == agent.id)
            )
            row = result.first()
            if row is None:
                total_tasks = 0
                active_tasks = 0
            else:
                total_tasks = row.total_tasks or 0
                active_tasks = row.active_tasks or 0

            return AgentInfoResponseV2(
                agent_id=str(agent.id),
                signature=agent.host_name,
                hostname=agent.custom_label or agent.host_name,
                agent_type="hashcat",  # Default type
                operating_system=agent.operating_system.value,
                status=agent.state,
                last_seen=agent.last_seen_at,
                capabilities=(agent.advanced_configuration or {}),
                version=agent.client_signature,
                total_tasks=total_tasks,
                active_tasks=active_tasks,
                registered_at=agent.created_at,
                api_version=2,
            )

        except Exception as e:
            logger.exception(f"Failed to get agent info for {agent.id}")
            raise ValueError(f"Failed to get agent info: {e!s}") from e

    @staticmethod
    async def update_agent_v2_service(
        db: AsyncSession, agent: Agent, update_data: AgentUpdateRequestV2
    ) -> AgentUpdateResponseV2:
        """
        Update agent information.

        Args:
            db: Database session
            agent: Current agent
            update_data: Update request data

        Returns:
            AgentUpdateResponseV2: Update response
        """
        try:
            logger.info(f"Updating agent {agent.id}")

            # Convert v2 update request to v1 format for CRUD
            update_dict = {}
            updated_fields = []

            if update_data.signature is not None:
                update_dict["name"] = update_data.signature
                updated_fields.append("signature")
            if update_data.hostname is not None:
                update_dict["description"] = update_data.hostname
                updated_fields.append("hostname")
            if update_data.version is not None:
                update_dict["version"] = update_data.version
                updated_fields.append("version")
            if update_data.capabilities is not None:
                update_dict["capabilities"] = update_data.capabilities
                updated_fields.append("capabilities")
            if update_data.status is not None:
                update_dict["status"] = update_data.status
                updated_fields.append("status")

            if update_dict:
                # Update agent fields directly
                for field, value in update_dict.items():
                    setattr(agent, field, value)
                await db.commit()
                await db.refresh(agent)

            return AgentUpdateResponseV2(
                agent_id=str(agent.id),
                status="updated",
                timestamp=datetime.now(UTC),
                updated_fields=updated_fields,
            )

        except Exception as e:
            logger.exception(f"Failed to update agent {agent.id}")
            raise ValueError(f"Agent update failed: {e!s}") from e

    @staticmethod
    async def get_agent_tasks_v2_service(
        db: AsyncSession,
        agent: Agent,
        skip: int = 0,
        limit: int = 100,
        status_filter: str | None = None,
    ) -> list[TaskOut]:
        """
        Get tasks assigned to an agent.

        Args:
            db: Database session
            agent: Current agent
            skip: Number of tasks to skip
            limit: Maximum number of tasks to return
            status_filter: Optional status filter

        Returns:
            List[TaskOut]: List of tasks
        """
        try:
            query = select(Task).filter(Task.agent_id == agent.id)

            if status_filter:
                query = query.filter(Task.status == status_filter)

            query = query.offset(skip).limit(limit)
            result = await db.execute(query)
            tasks = result.scalars().all()
            return [TaskOut.model_validate(task) for task in tasks]

        except Exception as e:
            logger.exception(f"Failed to get tasks for agent {agent.id}")
            raise ValueError(f"Failed to get tasks: {e!s}") from e

    @staticmethod
    async def get_task_v2_service(
        db: AsyncSession, agent: Agent, task_id: str
    ) -> TaskOut:
        """
        Get a specific task by ID.

        Args:
            db: Database session
            agent: Current agent
            task_id: Task identifier

        Returns:
            TaskOut: Task object

        Raises:
            ValueError: If task not found or not authorized
        """
        try:
            # Convert task_id string to integer
            try:
                task_id_int = int(task_id)
            except ValueError as e:
                raise ValueError("Invalid task id") from e

            result = await db.execute(select(Task).filter(Task.id == task_id_int))
            task = result.scalar_one_or_none()
            if not task:
                raise ValueError("Task not found")

            if task.agent_id != agent.id:
                raise ValueError("Task not assigned to this agent")

            return TaskOut.model_validate(task)

        except Exception:
            logger.exception(f"Failed to get task {task_id} for agent {agent.id}")
            raise

    @staticmethod
    async def update_task_progress_v2_service(
        db: AsyncSession,
        agent: Agent,
        task_id: str,
        progress_data: TaskProgressUpdateV2,
    ) -> TaskProgressResponseV2:
        """
        Update task progress.

        Args:
            db: Database session
            agent: Current agent
            task_id: Task identifier
            progress_data: Progress update data

        Returns:
            TaskProgressResponseV2: Progress update response
        """
        try:
            # Convert task_id string to integer
            try:
                task_id_int = int(task_id)
            except ValueError as e:
                raise ValueError("Invalid task id") from e

            # Get and validate task (get the actual SQLAlchemy model, not the schema)
            result = await db.execute(select(Task).filter(Task.id == task_id_int))
            task = result.scalar_one_or_none()
            if not task:
                raise ValueError("Task not found")

            if task.agent_id != agent.id:
                raise ValueError("Task not assigned to this agent")

            # Update task progress
            if progress_data.status:
                task.status = progress_data.status
            # progress_percent is always present in TaskProgressUpdateV2
            task.progress = int(progress_data.progress_percent)
            if progress_data.message:
                task.error_message = progress_data.message
            if progress_data.estimated_completion:
                task.estimated_completion = progress_data.estimated_completion
            if progress_data.keyspace_processed is not None:
                # Store keyspace_processed in error_details for now
                if not task.error_details:
                    task.error_details = {}
                task.error_details["keyspace_processed"] = (
                    progress_data.keyspace_processed
                )
            if progress_data.current_speed is not None:
                # Store current_speed in error_details for now
                if not task.error_details:
                    task.error_details = {}
                task.error_details["current_speed"] = progress_data.current_speed

            await db.commit()
            await db.refresh(task)

            return TaskProgressResponseV2(
                task_id=task_id,
                status="updated",
                timestamp=datetime.now(UTC),
                next_update_in=settings.AGENT_V2_DEFAULT_NEXT_HEARTBEAT_IN,
            )

        except Exception as e:
            logger.exception(f"Failed to update task progress {task_id}")
            raise ValueError(f"Progress update failed: {e!s}") from e

    @staticmethod
    async def submit_task_results_v2_service(
        db: AsyncSession,
        agent: Agent,
        task_id: str,
        results_data: TaskResultSubmissionV2,
    ) -> TaskResultResponseV2:
        """
        Submit task results.

        Args:
            db: Database session
            agent: Current agent
            task_id: Task identifier
            results_data: Results submission data

        Returns:
            TaskResultResponseV2: Results submission response
        """
        try:
            # Convert task_id string to integer
            try:
                task_id_int = int(task_id)
            except ValueError as e:
                raise ValueError("Invalid task id") from e

            # Get and validate task (get the actual SQLAlchemy model, not the schema)
            result = await db.execute(select(Task).filter(Task.id == task_id_int))
            task = result.scalar_one_or_none()
            if not task:
                raise ValueError("Task not found")

            if task.agent_id != agent.id:
                raise ValueError("Task not assigned to this agent")

            # Convert v2 results to v1 format
            results_dict = {
                "cracked_hashes": [
                    {
                        "hash": crack.hash_value,
                        "plaintext": crack.plaintext,
                        "crack_time": crack.crack_time.isoformat(),
                    }
                    for crack in results_data.cracked_hashes
                ],
                "execution_time": results_data.execution_time,
                "keyspace_processed": results_data.keyspace_processed,
                "final_speed": results_data.final_speed,
                "error_message": results_data.error_message,
                "error_code": results_data.error_code,
                "metadata": results_data.metadata or {},
            }

            # Submit results
            task.status = results_data.status
            # Store results in error_details for now (TODO: Add proper results field)
            if not task.error_details:
                task.error_details = {}
            task.error_details["results"] = results_dict
            task.error_details["result_submitted"] = True

            await db.commit()
            await db.refresh(task)

            return TaskResultResponseV2(
                task_id=task_id,
                status="accepted",
                timestamp=datetime.now(UTC),
                results_processed=len(results_data.cracked_hashes),
                campaign_updated=True,  # TODO: Implement campaign update logic
            )

        except Exception as e:
            logger.exception(f"Failed to submit results for task {task_id}")
            raise ValueError(f"Results submission failed: {e!s}") from e

    @staticmethod
    async def generate_resource_url_v2_service(
        db: AsyncSession,
        agent: Agent,
        resource_id: int,
    ) -> ResourceUrlResponseV2:
        """
        Generate presigned URL for resource access.

        Args:
            db: Database session
            agent: Current agent
            resource_id: Resource identifier

        Returns:
            ResourceUrlResponseV2: Presigned URL response
        """
        try:
            # Get resource
            result = await db.execute(
                select(Resource).filter(Resource.id == resource_id)
            )
            resource = result.scalar_one_or_none()
            if not resource:
                raise ValueError("Resource not found")

            # Check authorization
            if not crud_resource.agent_can_access_resource(
                db=db, agent_id=str(agent.id), resource_id=resource_id
            ):
                raise ValueError("Agent not authorized to access this resource")

            # Generate presigned URL
            expires_at = datetime.now(UTC) + timedelta(
                hours=settings.AGENT_V2_RESOURCE_URL_EXPIRY_HOURS
            )
            presigned_url = await crud_resource.generate_presigned_url(
                db=db, resource_id=resource_id, expires_at=expires_at
            )

            return ResourceUrlResponseV2(
                resource_id=str(resource_id),
                download_url=presigned_url,
                expires_at=expires_at,
                expected_hash=resource.file_hash,
                hash_algorithm=settings.AGENT_V2_RESOURCE_HASH_ALGORITHM,
                file_size=resource.file_size,
                content_type=resource.content_type,
                filename=resource.name,
            )

        except Exception as e:
            logger.exception(f"Failed to generate resource URL for {resource_id}")
            raise ValueError(f"Resource URL generation failed: {e!s}") from e

    @staticmethod
    async def get_attack_configuration_v2_service(
        db: AsyncSession, agent: Agent, attack_id: int
    ) -> AttackConfigurationResponseV2:
        """
        Get attack configuration for a specific attack ID.

        Args:
            db: Database session
            agent: Current agent
            attack_id: Attack identifier

        Returns:
            AttackConfigurationResponseV2: Attack configuration

        Raises:
            ValueError: If attack not found or not authorized
        """
        try:
            # Get attack from database
            result = await db.execute(select(Attack).filter(Attack.id == attack_id))
            attack = result.scalar_one_or_none()
            if not attack:
                raise ValueError("Attack not found")

            # Check if agent is authorized for this attack
            # This is a simplified check - in a real implementation, you'd check
            # if the agent is assigned to tasks for this attack
            result = await db.execute(
                select(Task).filter(
                    Task.attack_id == attack_id, Task.agent_id == agent.id
                )
            )
            tasks = result.scalar_one_or_none()

            if not tasks:
                raise ValueError("Agent not authorized for this attack")

            # Get hash type information
            result = await db.execute(
                select(HashType).filter(HashType.id == attack.hash_mode)
            )
            hash_type = result.scalar_one_or_none()
            hash_type_name = hash_type.name if hash_type else "Unknown"

            return AttackConfigurationResponseV2(
                attack_id=str(attack.id),
                attack_type=attack.attack_mode.value,
                hash_type=attack.hash_mode,
                hash_type_name=hash_type_name,
                parameters={
                    "mask": attack.mask,
                    "increment_mode": attack.increment_mode,
                    "increment_minimum": attack.increment_minimum,
                    "increment_maximum": attack.increment_maximum,
                    "optimized": attack.optimized,
                    "workload_profile": attack.workload_profile,
                    "left_rule": attack.left_rule,
                    "right_rule": attack.right_rule,
                },
                required_resources=[
                    str(resource_id)
                    for resource_id in [
                        attack.word_list_id,
                        attack.rule_list_id,
                        attack.mask_list_id,
                        attack.charset_id,
                    ]
                    if resource_id is not None
                ],
                priority=TaskPriorityV2.MEDIUM,  # TODO: Map attack.priority to TaskPriorityV2
                timeout=None,  # TODO: Add timeout field to Attack model
                description=attack.description,
                created_at=datetime.now(
                    UTC
                ),  # TODO: Add created_at field to Attack model
                updated_at=datetime.now(
                    UTC
                ),  # TODO: Add updated_at field to Attack model
            )
        except ValueError:
            raise
        except Exception as e:
            logger.exception("Error getting attack configuration")
            raise ValueError("Failed to retrieve attack configuration") from e

    @staticmethod
    async def get_next_task_v2_service(db: AsyncSession, agent: Agent) -> TaskOut:
        """
        Get the next available task for an agent.

        Args:
            db: Database session
            agent: Current agent

        Returns:
            TaskOut: Next available task

        Raises:
            ValueError: If no tasks are available
        """
        try:
            # Get the next available task for the agent
            # Priority: pending tasks first, then by creation time
            result = await db.execute(
                select(Task)
                .filter(Task.agent_id == agent.id, Task.status == "pending")
                .order_by(Task.created_at.asc())
            )
            task = result.scalar_one_or_none()

            if not task:
                raise ValueError("No tasks available")

            # Convert to TaskOut schema
            return TaskOut.model_validate(task)
        except ValueError:
            raise
        except Exception as e:
            logger.exception("Error getting next task")
            raise ValueError("Failed to retrieve next task") from e


# Create service instance
agent_v2_service = AgentV2Service()
