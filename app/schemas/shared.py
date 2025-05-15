from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.attack import AttackMode


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
        - rule_file: (Deprecated) Name of the rule file, for legacy compatibility only
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
    rule_file: Annotated[
        str | None,
        Field(
            ...,
            description="(Deprecated) Name of the rule file, for legacy compatibility only",
        ),
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


__all__ = ["AttackTemplate", "CampaignTemplate"]

if __name__ == "__main__":
    # Simple test: instantiate and round-trip as JSON
    from app.models.attack import AttackMode

    attack = AttackTemplate(
        mode=AttackMode.DICTIONARY,
        min_length=6,
        max_length=12,
        wordlist_guid=None,
        rulelist_guid=None,
        masklist_guid=None,
        wordlist_inline=None,
        rules_inline=None,
        masks=None,
        masks_inline=None,
        position=0,
        comment=None,
        rule_file=None,
    )
    campaign = CampaignTemplate(
        schema_version="20250511",
        name="Test Campaign",
        description=None,
        attacks=[attack],
        hash_list_id=None,
    )
    data = campaign.model_dump()
    loaded = CampaignTemplate.model_validate(data)
