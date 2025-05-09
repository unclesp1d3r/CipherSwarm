# type: ignore[assignment]

from faker import Faker
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.agent import Agent, AgentState, AgentType

fake = Faker()


class AgentFactory(SQLAlchemyFactory[Agent]):
    __model__ = Agent
    __async_session__ = None
    _host_counter = 0
    _sig_counter = 0
    _token_counter = 0
    _label_counter = 0

    @classmethod
    def host_name(cls) -> str:
        cls._host_counter += 1
        return f"host-{cls.__faker__.uuid4()}-{cls._host_counter}"

    @classmethod
    def client_signature(cls) -> str:
        cls._sig_counter += 1
        return f"sig-{cls.__faker__.sha256()}-{cls._sig_counter}"

    @classmethod
    def token(cls) -> str:
        cls._token_counter += 1
        return f"csa_{cls._token_counter}_{cls.__faker__.sha256()}"

    @classmethod
    def custom_label(cls) -> str:
        cls._label_counter += 1
        return f"label-{cls.__faker__.word()}-{cls._label_counter}"

    agent_type = AgentType.physical
    state = AgentState.active
    operating_system_id = None  # Must be set explicitly in tests
    user_id = None  # Must be set in test if needed
    # All FKs must be set explicitly in tests.

    # operating_system and user handled in build


# Don't try to override build or create_async methods
