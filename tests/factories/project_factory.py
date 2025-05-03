# type: ignore[assignment]

from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.project import Project


class ProjectFactory(SQLAlchemyFactory[Project]):
    __model__ = Project
    name = "ProjectTest"
    description = "A test project"
    private = False
