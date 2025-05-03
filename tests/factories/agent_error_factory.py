# pyright: reportGeneralTypeIssues=false
# ruff: noqa: F401, F811
# type: ignore[assignment]
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.agent_error import AgentError, Severity
from tests.factories.agent_factory import AgentFactory
from tests.factories.task_factory import TaskFactory


class AgentErrorFactory(SQLAlchemyFactory[AgentError]):
    __model__ = AgentError
    message = "Test error message"
    severity = Severity.minor
    error_code = "E0001"
    agent = AgentFactory
    task = TaskFactory
