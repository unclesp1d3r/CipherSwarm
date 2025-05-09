from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field


class ErrorObject(BaseModel):
    error: Annotated[str, Field(..., description="Error message")]
    model_config = ConfigDict(extra="forbid")
