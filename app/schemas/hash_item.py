from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field


class HashItemOut(BaseModel):
    id: Annotated[int, Field(description="Unique identifier for the hash item")]
    hash: Annotated[str, Field(description="Hash value")]
    salt: Annotated[str | None, Field(description="Salt value, if present")] = None
    meta: Annotated[
        dict[str, str] | None,
        Field(description="User-defined metadata for the hash item"),
    ] = None
    plain_text: Annotated[
        str | None, Field(description="Cracked plain text, if available")
    ] = None

    model_config = ConfigDict(from_attributes=True)
