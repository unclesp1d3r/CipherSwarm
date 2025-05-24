from datetime import datetime
from typing import Annotated, Generic, TypeVar
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.attack import AttackMode

T = TypeVar("T")


class PaginatedResponse(BaseModel, Generic[T]):
    """Generic response model for paginated results."""

    items: Annotated[list[T], Field(description="List of items")]
    total: Annotated[int, Field(description="Total number of items")]
    page: Annotated[int, Field(description="Current page number", ge=1, le=100)] = 1
    page_size: Annotated[
        int, Field(description="Number of items per page", ge=1, le=100)
    ] = 20
    search: Annotated[str | None, Field(description="Search query")] = None


class AttackTemplate(BaseModel):
    """JSON-compatible model for exporting/importing attack configurations in templates.

    Fields:
        - mode: Attack mode (e.g., dictionary, mask, etc.)
        - wordlist_guid: GUID of the wordlist resource, if applicable
        - rulelist_guid: GUID of the rule list resource, if applicable
        - masklist_guid: GUID of the mask list resource, if applicable
        - min_length: Minimum password length
        - max_length: Maximum password length
        - masks: List of mask patterns, if applicable
        - masks_inline: Ephemeral mask list lines, if inlined
        - wordlist_inline: Ephemeral wordlist lines, if inlined
        - rules_inline: Ephemeral rule list lines, if inlined
        - position: Numeric ordering field within a campaign
        - comment: User-provided description for UI display
    """

    mode: Annotated[AttackMode, Field(..., description="Attack mode")] = Field(
        ..., description="Attack mode (e.g., dictionary, mask, etc.)"
    )
    wordlist_guid: Annotated[
        UUID | None,
        Field(..., description="GUID of the wordlist resource, if applicable"),
    ] = None
    rulelist_guid: Annotated[
        UUID | None,
        Field(..., description="GUID of the rule list resource, if applicable"),
    ] = None
    masklist_guid: Annotated[
        UUID | None,
        Field(..., description="GUID of the mask list resource, if applicable"),
    ] = None
    min_length: Annotated[
        int | None,
        Field(..., description="Minimum password length"),
    ] = None
    max_length: Annotated[
        int | None,
        Field(..., description="Maximum password length"),
    ] = None
    masks: Annotated[
        list[str] | None,
        Field(..., description="List of mask patterns, if applicable"),
    ] = None
    masks_inline: Annotated[
        list[str] | None,
        Field(..., description="Ephemeral mask list lines, if inlined"),
    ] = None
    wordlist_inline: Annotated[
        list[str] | None,
        Field(..., description="Ephemeral wordlist lines, if inlined"),
    ] = None
    rules_inline: Annotated[
        list[str] | None,
        Field(..., description="Ephemeral rule list lines, if inlined"),
    ] = None
    position: Annotated[
        int | None,
        Field(..., description="Numeric ordering field within a campaign"),
    ] = None
    comment: Annotated[
        str | None,
        Field(..., description="User-provided description for UI display"),
    ] = None
    # Add other attack config fields as needed for round-trip safety

    model_config = ConfigDict(from_attributes=True)


class CampaignTemplate(BaseModel):
    """Top-level structure for campaign import/export, including attacks and hash list reference."""

    schema_version: Annotated[
        str,
        Field(..., description="Schema version for compatibility"),
    ] = "20250511"
    name: Annotated[
        str,
        Field(..., description="Campaign name"),
    ]
    description: Annotated[
        str | None,
        Field(None, description="Campaign description"),
    ] = None
    attacks: Annotated[
        list[AttackTemplate],
        Field(description="List of attack templates"),
    ] = []
    # Hashlist is referenced by ID, not embedded
    hash_list_id: Annotated[
        int | None,
        Field(None, description="ID of the hash list to use"),
    ] = None
    # Add other campaign-level fields as needed

    model_config = ConfigDict(from_attributes=True)


class AttackTemplateRecordOut(BaseModel):
    id: int
    name: str
    description: str | None = None
    attack_mode: str
    recommended: bool
    project_ids: list[int] | None = None
    template_json: AttackTemplate
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AttackTemplateRecordCreate(BaseModel):
    name: str
    description: str | None = None
    attack_mode: str
    recommended: bool = False
    project_ids: list[int] | None = None
    template_json: AttackTemplate


class AttackTemplateRecordUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    attack_mode: str | None = None
    recommended: bool | None = None
    project_ids: list[int] | None = None
    template_json: AttackTemplate | None = None


class HashGuessCandidate(BaseModel):
    hash_type: int
    name: str
    confidence: float


class HashModeItem(BaseModel):
    mode: int
    name: str
    category: str


class HashModeMetadata(BaseModel):
    hash_mode_map: Annotated[
        dict[int, HashModeItem],
        Field(description="Mapping of hashcat hash modes to their names"),
    ] = {}
    category_map: Annotated[
        dict[int, str],
        Field(description="Mapping of hashcat hash modes to their categories"),
    ] = {}
