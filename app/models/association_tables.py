from sqlalchemy import Column, ForeignKey, Table

from app.models.base import Base

project_users = Table(
    "project_users",
    Base.metadata,
    Column("project_id", ForeignKey("projects.id"), primary_key=True),
    Column("user_id", ForeignKey("user.id"), primary_key=True),
)

project_agents = Table(
    "project_agents",
    Base.metadata,
    Column("project_id", ForeignKey("projects.id"), primary_key=True),
    Column("agent_id", ForeignKey("agents.id"), primary_key=True),
)
