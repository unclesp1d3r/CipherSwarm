"""
Helper for validating, coercing, and upgrading campaign/attack templates.
"""

from app.models.attack import Attack, AttackMode
from app.models.campaign import Campaign

from .shared import AttackTemplate, CampaignTemplate


def validate_campaign_template(data: dict[str, object]) -> CampaignTemplate:
    """
    Validate and coerce a dict or JSON-like object into a CampaignTemplate.
    Raises ValidationError if invalid.
    """
    return CampaignTemplate.model_validate(data)


def validate_attack_template(data: dict[str, object]) -> AttackTemplate:
    """
    Validate and coerce a dict or JSON-like object into an AttackTemplate.
    Raises ValidationError if invalid.
    """
    return AttackTemplate.model_validate(data)


def load_campaign_template(template: CampaignTemplate, project_id: int) -> Campaign:
    """
    Load a CampaignTemplate into a new Campaign SQLAlchemy model instance.
    Does not commit to DB. Requires project_id for multi-tenancy.
    """
    return Campaign(
        name=template.name,
        description=template.description,
        project_id=project_id,
        hash_list_id=template.hash_list_id,
        # priority and other fields can be extended as needed
    )


def load_attack_template(
    template: AttackTemplate,
    campaign_id: int,
    hash_list_url: str,
    hash_list_checksum: str,
) -> Attack:
    """
    Load an AttackTemplate into a new Attack SQLAlchemy model instance.
    Does not commit to DB. Requires campaign_id and hash list info.
    """
    return Attack(
        name=f"Imported {template.mode.title()} Attack",
        description=None,
        campaign_id=campaign_id,
        attack_mode=AttackMode(template.mode),
        mask=None,  # Extend as needed for mask/dictionary/rule
        hash_list_id=None,  # Set if needed
        hash_list_url=hash_list_url,
        hash_list_checksum=hash_list_checksum,
        # Set other fields as needed from template
    )
