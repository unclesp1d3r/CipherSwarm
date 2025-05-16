from typing import Annotated

from pydantic import BaseModel, Field


class ResourceLine(BaseModel):
    id: Annotated[
        int, Field(description="Unique line identifier (index in file or DB)")
    ]
    index: Annotated[int, Field(description="Line index (0-based)")]
    content: Annotated[str, Field(description="Content of the line")]
    valid: Annotated[
        bool,
        Field(
            description="Whether the line is valid according to resource type validation"
        ),
    ]
    error_message: Annotated[
        str | None, Field(description="Validation error message, if any")
    ] = None


class ResourceLineValidationError(BaseModel):
    line_index: Annotated[int, Field(description="Index of the line with error")]
    content: Annotated[str, Field(description="Content of the line with error")]
    valid: Annotated[bool, Field(default=False, description="Always false for errors")]
    message: Annotated[str, Field(description="Validation error message")]
