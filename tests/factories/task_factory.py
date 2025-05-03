# type: ignore[assignment]
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.task import Task, TaskStatus
from tests.factories.attack_factory import AttackFactory


class TaskFactory(SQLAlchemyFactory[Task]):
    __model__ = Task
    attack = AttackFactory
    status = TaskStatus.PENDING
    stale = False
    progress_percent = 0.0
    progress_keyspace = 0
    result_json = None
    agent_id = None
