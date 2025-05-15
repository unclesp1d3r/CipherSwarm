from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class AttackTemplate(BaseModel):
    """JSON-compatible model for exporting/importing attack configurations in templates."""

    mode: str = Field(..., description="Attack mode (e.g., dictionary, mask, etc.)")
    wordlist_guid: UUID | None = Field(
        None, description="GUID of the wordlist resource, if applicable"
    )
    rule_file: str | None = Field(
        None, description="Name of the rule file, if applicable"
    )
    min_length: int | None = Field(None, description="Minimum password length")
    max_length: int | None = Field(None, description="Maximum password length")
    masks: list[str] | None = Field(
        None, description="List of mask patterns, if applicable"
    )
    masks_inline: list[str] | None = Field(
        None, description="Ephemeral mask list lines, if inlined"
    )
    wordlist_inline: list[str] | None = Field(
        None, description="Ephemeral wordlist lines, if inlined"
    )
    # Add other attack config fields as needed for round-trip safety

    model_config = ConfigDict(from_attributes=True)


class CampaignTemplate(BaseModel):
    """Top-level structure for campaign import/export, including attacks and hash list reference."""

    schema_version: str = Field(
        "20250511", description="Schema version for compatibility"
    )
    name: str = Field(..., description="Campaign name")
    description: str | None = Field(None, description="Campaign description")
    attacks: list[AttackTemplate] = Field(..., description="List of attack templates")
    # Hashlist is referenced by ID, not embedded
    hash_list_id: int | None = Field(None, description="ID of the hash list to use")
    # Add other campaign-level fields as needed

    model_config = ConfigDict(from_attributes=True)


__all__ = ["AttackTemplate", "CampaignTemplate"]

if __name__ == "__main__":
    # Simple test: instantiate and round-trip as JSON
    attack = AttackTemplate(
        mode="dictionary",
        min_length=6,
        max_length=12,
        wordlist_guid=None,
        rule_file=None,
        masks=None,
        masks_inline=None,
        wordlist_inline=None,
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
