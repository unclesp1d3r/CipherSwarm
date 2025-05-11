from faker import Faker
from polyfactory import Use
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.campaign import Campaign

fake = Faker()


class CampaignFactory(SQLAlchemyFactory[Campaign]):
    __model__ = Campaign
    __async_session__ = None
    _name_counter = 0

    @classmethod
    def name(cls) -> str:
        cls._name_counter += 1
        return f"campaign-{cls.__faker__.uuid4()}-{cls._name_counter}"

    description = Use(lambda: fake.unique.sentence())
    project_id = None  # Must be set explicitly in tests
    priority = 0
    state = None
