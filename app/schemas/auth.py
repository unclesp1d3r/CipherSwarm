from typing import Annotated

from pydantic import BaseModel, Field


class LoginResult(BaseModel):
    message: Annotated[
        str, Field(description="Result message", examples=["Login successful."])
    ]
    level: Annotated[str, Field(description="Result level", examples=["success"])]


class ProjectContextDetail(BaseModel):
    id: int
    name: str


class UserContextDetail(BaseModel):
    id: str  # Assuming user ID is UUID, so str
    email: str
    name: str
    role: str  # Assuming role is string representation e.g. user.role.value


class ContextResponse(BaseModel):
    user: Annotated[UserContextDetail, Field(description="User context")]
    active_project: Annotated[
        ProjectContextDetail | None, Field(description="Active project context")
    ]
    available_projects: Annotated[
        list[ProjectContextDetail], Field(description="Available projects")
    ]


class SetContextRequest(BaseModel):
    project_id: Annotated[
        int, Field(description="Project ID to set as active", examples=[1])
    ]
