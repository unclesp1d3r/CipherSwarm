# type: ignore[assignment]
from typing import ClassVar

from faker import Faker
from polyfactory import Use
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.operating_system import OperatingSystem, OSName

fake = Faker()


class OperatingSystemFactory(SQLAlchemyFactory[OperatingSystem]):
    __model__ = OperatingSystem
    __async_session__ = None
    _name_counter = 0
    _os_names: ClassVar[list[OSName]] = list(OSName)

    @classmethod
    def name(cls) -> OSName:
        # Cycle through OSName enum values for uniqueness
        value = cls._os_names[cls._name_counter % len(cls._os_names)]
        cls._name_counter += 1
        return value

    cracker_command = Use(lambda: f"hashcat-{fake.unique.uuid4()}")
    # No FKs; pure factory.


# Don't try to override build or create_async methods
