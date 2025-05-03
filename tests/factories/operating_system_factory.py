# type: ignore[assignment]

from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.operating_system import OperatingSystem, OSName


class OperatingSystemFactory(SQLAlchemyFactory[OperatingSystem]):
    __model__ = OperatingSystem
    name = OSName.linux
    cracker_command = "hashcat -m 0"
