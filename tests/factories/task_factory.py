# type: ignore[assignment]
from faker import Faker
from polyfactory import Use
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.task import Task, TaskStatus

fake = Faker()


class TaskFactory(SQLAlchemyFactory[Task]):
    __model__ = Task
    __async_session__ = None
    __check_model__ = False
    __set_relationships__ = False
    __set_association_proxy__ = False
    attack_id = None  # Must be set explicitly in tests
    agent_id = None  # Must be set in test if needed
    campaign_id = None  # Must be set explicitly in tests if needed
    start_date = Use(lambda: fake.date_time_this_decade(tzinfo=None))
    status = TaskStatus.PENDING
    error_details = {}  # noqa: RUF012
    stale = False
    progress = 0.0
    # FK fields (attack_id, agent_id, campaign_id) must be set explicitly in tests.


# Don't try to override build or create_async methods
