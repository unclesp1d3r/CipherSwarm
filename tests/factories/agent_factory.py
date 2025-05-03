# type: ignore[assignment]
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.agent import Agent, AgentState
from tests.factories.operating_system_factory import OperatingSystemFactory


class AgentFactory(SQLAlchemyFactory[Agent]):
    __model__ = Agent
    client_signature = "sig-test"
    host_name = "host-test"
    state = AgentState.active
    enabled = True
    operating_system = OperatingSystemFactory
