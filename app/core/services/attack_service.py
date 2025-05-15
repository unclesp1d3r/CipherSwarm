from uuid import UUID

from loguru import logger
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import InvalidAgentTokenError
from app.core.services.attack_complexity_service import AttackEstimationService
from app.models.agent import Agent
from app.models.attack import Attack, AttackMode, AttackState, WordlistSource
from app.models.attack_resource_file import AttackResourceFile, AttackResourceType
from app.models.campaign import Campaign
from app.models.hash_list import HashList
from app.models.hashcat_benchmark import HashcatBenchmark
from app.models.task import TaskStatus
from app.schemas.attack import (
    AttackCreate,
    AttackMoveDirection,
    AttackOut,
    AttackResourceEstimationContext,
    AttackUpdate,
    EstimateAttackRequest,
    EstimateAttackResponse,
)
from app.schemas.shared import AttackTemplate


class AttackNotFoundError(Exception):
    pass


class AttackAlreadyExistsError(Exception):
    pass


class AttackEditConfirmationError(Exception):
    def __init__(self, attack: Attack) -> None:
        self.attack: Attack = attack
        super().__init__(
            f"Edit confirmation required for attack in state {attack.state}"
        )


async def get_attack_config_service(
    attack_id: int,
    db: AsyncSession,
    authorization: str,
) -> Attack:
    if not authorization.startswith("Bearer csa_"):
        raise InvalidAgentTokenError("Invalid or missing agent token")
    token = authorization.removeprefix("Bearer ").strip()
    agent_result = await db.execute(select(Agent).filter(Agent.token == token))
    agent = agent_result.scalar_one_or_none()
    if not agent:
        raise InvalidAgentTokenError("Invalid agent token")
    result = await db.execute(select(Attack).filter(Attack.id == attack_id))
    attack = result.scalar_one_or_none()
    if not attack:
        raise AttackNotFoundError("Attack not found")
    # Validate agent capability for attack
    benchmark_result = await db.execute(
        select(HashcatBenchmark).filter(
            HashcatBenchmark.agent_id == agent.id,
            HashcatBenchmark.hash_type_id == attack.hash_type_id,
        )
    )
    benchmark = benchmark_result.scalar_one_or_none()
    if not benchmark:
        raise PermissionError(
            "Agent does not support required hash type for this attack"
        )
    return attack


async def move_attack_service(
    attack_id: int, direction: AttackMoveDirection, db: AsyncSession
) -> None:
    """
    Move an attack within its campaign by updating its position.

    Args:
        attack_id: The attack to move
        direction: One of AttackMoveDirection
        db: AsyncSession
    Raises:
        AttackNotFoundError: if attack not found or invalid direction
    """
    logger.info(f"Moving attack {attack_id} direction={direction}")
    result = await db.execute(select(Attack).where(Attack.id == attack_id))
    attack = result.scalar_one_or_none()
    if not attack:
        raise AttackNotFoundError(f"Attack {attack_id} not found")
    campaign_id = attack.campaign_id
    # Fetch all attacks in this campaign, ordered by position
    attacks_result = await db.execute(
        select(Attack)
        .where(Attack.campaign_id == campaign_id)
        .order_by(Attack.position)
    )
    attacks = list(attacks_result.scalars().all())
    idx = next((i for i, a in enumerate(attacks) if a.id == attack_id), None)
    if idx is None:
        raise AttackNotFoundError(f"Attack {attack_id} not found in campaign")
    # Move logic
    if direction == AttackMoveDirection.UP and idx > 0:
        attacks[idx - 1], attacks[idx] = attacks[idx], attacks[idx - 1]
    elif direction == AttackMoveDirection.DOWN and idx < len(attacks) - 1:
        attacks[idx], attacks[idx + 1] = attacks[idx + 1], attacks[idx]
    elif direction == AttackMoveDirection.TOP and idx > 0:
        attack_to_move = attacks.pop(idx)
        attacks.insert(0, attack_to_move)
    elif direction == AttackMoveDirection.BOTTOM and idx < len(attacks) - 1:
        attack_to_move = attacks.pop(idx)
        attacks.append(attack_to_move)
    # else: no-op if already at edge
    # Reassign positions
    for pos, a in enumerate(attacks):
        a.position = pos
    await db.commit()
    logger.info(f"Attack {attack_id} moved {direction} in campaign {campaign_id}")


async def duplicate_attack_service(attack_id: int, db: AsyncSession) -> AttackOut:
    """
    Duplicate an attack in-place, copying all fields except id, position, and timestamps.
    The clone is inserted at the end of the campaign's attack list.
    Returns the new attack as a Pydantic AttackOut schema.
    """
    result = await db.execute(select(Attack).where(Attack.id == attack_id))
    attack = result.scalar_one_or_none()
    if not attack:
        raise AttackNotFoundError(f"Attack {attack_id} not found")
    # Find max position in campaign
    max_pos_result = await db.execute(
        select(func.max(Attack.position)).where(
            Attack.campaign_id == attack.campaign_id
        )
    )
    max_position = max_pos_result.scalar() or 0
    # Use Pydantic v2 idiom to copy fields
    attack_out = AttackOut.model_validate(attack, from_attributes=True)
    clone_out = attack_out.model_copy(
        update={
            "name": f"{attack.name} (Copy)",
            "state": AttackState.PENDING,
            "template_id": attack.id,
        }
    )
    clone_data = clone_out.model_dump(
        exclude={
            "id",
            "position",
            "start_time",
            "end_time",
            "word_list",
            "rule_list",
            "mask_list",
        }
    )
    clone_data["position"] = max_position + 1
    clone = Attack(**clone_data)
    db.add(clone)
    await db.commit()
    await db.refresh(clone)
    return AttackOut.model_validate(clone, from_attributes=True)


async def bulk_delete_attacks_service(
    attack_ids: list[int], db: AsyncSession
) -> dict[str, list[int]]:
    """
    Delete multiple attacks by their IDs in a single transaction.
    Returns a dict with 'deleted_ids' and 'not_found_ids'.
    Raises AttackNotFoundError if any ID does not exist.
    """
    logger.info(f"Bulk deleting attacks: {attack_ids}")
    if not attack_ids:
        return {"deleted_ids": [], "not_found_ids": []}
    # Fetch all attacks matching the IDs
    result = await db.execute(select(Attack).where(Attack.id.in_(attack_ids)))
    attacks = result.scalars().all()
    found_ids = {a.id for a in attacks}
    not_found_ids = [aid for aid in attack_ids if aid not in found_ids]
    if not attacks:
        raise AttackNotFoundError(f"No attacks found for IDs: {attack_ids}")
    # Delete found attacks
    for attack in attacks:
        await db.delete(attack)
    await db.commit()
    logger.info(f"Deleted attacks: {found_ids}. Not found: {not_found_ids}")
    return {"deleted_ids": list(found_ids), "not_found_ids": not_found_ids}


# Deprecated: use AttackEstimationService instead
class KeyspaceEstimator:
    @staticmethod
    def estimate(
        attack: AttackCreate, resources: AttackResourceEstimationContext
    ) -> int:
        return AttackEstimationService.estimate_keyspace(attack, resources)


def _safe_int(val: object, default: int) -> int:
    if isinstance(val, int):
        return val
    if isinstance(val, str) and val.isdigit():
        return int(val)
    return default


async def estimate_attack_keyspace_and_complexity(
    attack_data: EstimateAttackRequest,
) -> EstimateAttackResponse:
    """
    Estimate keyspace and complexity score for an unsaved attack config.
    Accepts an EstimateAttackRequest model.
    Returns an EstimateAttackResponse model.
    """
    # Use AttackCreate for attack fields, fill missing with defaults
    attack = AttackCreate.model_validate(attack_data.model_dump(exclude_none=True))
    resources = AttackResourceEstimationContext(
        wordlist_size=attack_data.wordlist_size
        if attack_data.wordlist_size is not None
        else 10000,
        rule_count=attack_data.rule_count if attack_data.rule_count is not None else 1,
    )
    keyspace = AttackEstimationService.estimate_keyspace(attack, resources)
    complexity = AttackEstimationService.calculate_complexity_from_keyspace(keyspace)
    return EstimateAttackResponse(keyspace=keyspace, complexity_score=complexity)


def _extract_wordlist(attack: Attack) -> tuple[UUID | None, list[str] | None]:
    wl = getattr(attack, "word_list", None)
    if wl is not None:
        if (
            hasattr(wl, "resource_type")
            and str(wl.resource_type) == "ephemeral_word_list"
            and wl.content
            and "lines" in wl.content
        ):
            return None, wl.content["lines"]
        if hasattr(wl, "guid"):
            return wl.guid, None
    return None, None


def _extract_rulelist(
    attack: Attack,
) -> tuple[UUID | None, list[str] | None, str | None]:
    rl = getattr(attack, "left_rule", None)
    if rl is not None:
        if isinstance(rl, AttackResourceFile):
            if (
                hasattr(rl, "resource_type")
                and str(rl.resource_type) == "ephemeral_rule_list"
                and rl.content
                and "lines" in rl.content
            ):
                val = rl.content["lines"]
                return None, val if isinstance(val, list) else None, None
            if hasattr(rl, "guid"):
                return rl.guid, None, None
        elif isinstance(rl, str):
            return None, None, rl
    return None, None, None


def _extract_masklist(attack: Attack) -> tuple[UUID | None, list[str] | None]:
    mask_list = getattr(attack, "mask_list", None)
    if mask_list is not None:
        if (
            hasattr(mask_list, "resource_type")
            and str(mask_list.resource_type) == "ephemeral_mask_list"
            and mask_list.content
            and "lines" in mask_list.content
        ):
            return None, mask_list.content["lines"]
        if hasattr(mask_list, "guid"):
            return mask_list.guid, None
        if (
            hasattr(mask_list, "resource_type")
            and str(mask_list.resource_type) == "mask_list"
            and mask_list.content
            and "lines" in mask_list.content
        ):
            return None, mask_list.content["lines"]
    return None, None


def attack_to_template(attack: Attack) -> AttackTemplate:
    """
    Convert an Attack SQLAlchemy model to an AttackTemplate Pydantic model for save/load export.
    Follows the schema requirements from docs/v2_rewrite_implementation_plan/phase-2-api-implementation.md
    and phase-2-api-implementation-part-2.md (see 'shared-schema-saveload' and 'web-ui-api-campaign-management-save-load-schema-design').

    - Exports all editable fields: mode, position, comment, min/max length, etc.
    - For linked resources (wordlist, rulelist, masklist), exports their stable UUID (guid) if not ephemeral.
    - For ephemeral resources, inlines their content (wordlist_inline, rules_inline, masks_inline).
    - Field names and types match the schema exactly.
    """
    wordlist_guid, wordlist_inline = _extract_wordlist(attack)
    rulelist_guid, rules_inline, rule_file = _extract_rulelist(attack)
    masklist_guid, masks_inline = _extract_masklist(attack)
    masks = [attack.mask] if getattr(attack, "mask", None) else None
    if masks:
        filtered_masks = [m for m in masks if isinstance(m, str) and m is not None]
        masks_out = filtered_masks if filtered_masks else None
    else:
        masks_out = None

    return AttackTemplate(
        mode=attack.attack_mode,
        position=getattr(attack, "position", None),
        comment=getattr(attack, "comment", None),
        min_length=getattr(attack, "increment_minimum", None),
        max_length=getattr(attack, "increment_maximum", None),
        wordlist_guid=wordlist_guid,
        rulelist_guid=rulelist_guid,
        masklist_guid=masklist_guid,
        wordlist_inline=wordlist_inline,
        rules_inline=rules_inline if isinstance(rules_inline, list) else None,
        masks=masks_out,
        masks_inline=masks_inline,
        rule_file=rule_file,  # Deprecated, for legacy compatibility only
    )


async def export_attack_template_service(
    attack_id: int, db: AsyncSession
) -> AttackTemplate:
    """
    Export a single Attack as an AttackTemplate for save/load workflows.
    Ensures compliance with the shared schema (see docs).
    """
    result = await db.execute(select(Attack).where(Attack.id == attack_id))
    attack = result.scalar_one_or_none()
    if not attack:
        raise AttackNotFoundError(f"Attack {attack_id} not found")
    return attack_to_template(attack)


async def _check_attack_resource(
    resource_id: UUID | None,
    allowed_types: set[AttackResourceType],
    field_name: str,
    db: AsyncSession,
    mode_enum: AttackMode,
) -> None:
    if not resource_id:
        return
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        from fastapi import HTTPException, status

        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{field_name} resource not found.",
        )
    if resource.resource_type not in allowed_types:
        from fastapi import HTTPException, status

        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{field_name} resource type {resource.resource_type} is not allowed for attack mode {mode_enum}.",
        )


async def update_attack_service(  # noqa: C901, PLR0912
    attack_id: int,
    data: AttackUpdate,
    db: AsyncSession,
    confirm: bool = False,
) -> AttackOut:
    """
    Update an attack. If the attack is not pending and confirm is not set, raise AttackEditConfirmationError.
    If confirmed or pending, reset state to PENDING and clear times, then update fields.
    Only allow state transitions via this service (FSM rule).
    """
    result = await db.execute(select(Attack).where(Attack.id == attack_id))
    attack = result.scalar_one_or_none()
    if not attack:
        raise AttackNotFoundError(f"Attack {attack_id} not found")
    # If not pending and not confirmed, require confirmation
    if attack.state != AttackState.PENDING and not confirm:
        raise AttackEditConfirmationError(attack)
    # If confirmed or pending, reset state and update
    if attack.state != AttackState.PENDING or confirm:
        attack.state = AttackState.PENDING
        attack.start_time = None
        attack.end_time = None
        # Reset all associated tasks to PENDING for reprocessing
        if hasattr(attack, "tasks") and attack.tasks:
            for task in attack.tasks:
                task.status = TaskStatus.PENDING
                task.agent_id = None
                if hasattr(task, "retry_count") and task.retry_count is not None:
                    task.retry_count += 1
                else:
                    task.retry_count = 1
                task.error_message = None
                task.error_details = None
                task.progress = 0.0
            logger.info(
                f"Reset all tasks for attack_id={attack_id} to PENDING for reprocessing."
            )
    # If dictionary attack and modifiers are set, override rule_list_id
    if (
        getattr(data, "attack_mode", None) == "dictionary"
        or getattr(attack, "attack_mode", None) == "dictionary"
    ) and getattr(data, "modifiers", None):
        modifiers = data.modifiers or []
        if modifiers:
            rule_uuid = get_rule_file_for_modifiers(modifiers)
            if rule_uuid:
                # TODO: Actually fetch the AttackResourceFile and set relationship if needed
                attack.left_rule = str(rule_uuid)
    # Update fields from AttackUpdate
    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if hasattr(attack, field) and value is not None:
            # Only set modifiers if value is a list (avoid dict/None)
            if field == "modifiers" and not isinstance(value, list):
                setattr(attack, field, None)
                continue
            setattr(attack, field, value)
    # Defensive: ensure attack.modifiers is a list or None before returning
    if hasattr(attack, "modifiers") and not (
        isinstance(attack.modifiers, list) or attack.modifiers is None
    ):
        attack.modifiers = None
    await db.commit()
    await db.refresh(attack)
    return AttackOut.model_validate(attack, from_attributes=True)


# Modifier to rule file mapping (placeholder UUIDs, replace with real ones)
# Instead of rule files, this should actually compose an ephemeral rule list
MODIFIER_RULE_FILE_MAP = {
    "change_case": "00000000-0000-0000-0000-000000000001",  # TODO: Replace with real UUID
    "substitute_chars": "00000000-0000-0000-0000-000000000002",  # TODO: Replace with real UUID
    # Add more mappings as needed
}


def get_rule_file_for_modifiers(modifiers: list[str]) -> UUID | None:
    """
    Given a list of modifiers, return the UUID of the rule file to use.
    For now, if multiple modifiers are selected, pick the first. In the future, support combining rules.
    """
    if not modifiers:
        return None
    for mod in modifiers:
        if mod in MODIFIER_RULE_FILE_MAP:
            return UUID(MODIFIER_RULE_FILE_MAP[mod])
    return None


async def create_attack_service(
    data: AttackCreate,
    db: AsyncSession,
) -> AttackOut:
    """
    Create a new attack, including ephemeral mask lists (masks_inline) and dynamic previous passwords wordlist.
    Returns the new attack as a Pydantic AttackOut schema.
    """
    # Handle dynamic previous passwords wordlist
    word_list_id = None
    if (
        data.attack_mode == AttackMode.DICTIONARY
        and data.wordlist_source == WordlistSource.PREVIOUS_PASSWORDS
    ):
        campaign_id = data.campaign_id
        cracked_passwords = []
        if campaign_id:
            campaign_result = await db.execute(
                select(Campaign)
                .where(Campaign.id == campaign_id)
                .options(selectinload(Campaign.hash_list).selectinload(HashList.items))
            )
            campaign = campaign_result.scalar_one_or_none()
            if campaign and campaign.hash_list and campaign.hash_list.items:
                cracked_passwords = [
                    item.plain_text
                    for item in campaign.hash_list.items
                    if getattr(item, "plain_text", None)
                ]
        elif data.hash_list_id:
            hash_list_result = await db.execute(
                select(HashList)
                .where(HashList.id == data.hash_list_id)
                .options(selectinload(HashList.items))
            )
            hash_list = hash_list_result.scalar_one_or_none()
            if hash_list and hash_list.items:
                cracked_passwords = [
                    item.plain_text
                    for item in hash_list.items
                    if getattr(item, "plain_text", None)
                ]
        from uuid import uuid4

        dynamic_resource = AttackResourceFile(
            id=uuid4(),
            file_name="dynamic_previous_passwords.txt",
            download_url="",  # Not downloadable from MinIO
            checksum="",  # Not applicable
            guid=uuid4(),
            resource_type=AttackResourceType.DYNAMIC_WORD_LIST,
            line_format="freeform",
            line_encoding="utf-8",
            used_for_modes=[AttackMode.DICTIONARY],
            source="dynamic",
            line_count=len(cracked_passwords),
            byte_size=sum(len(p) for p in cracked_passwords),
            content={"lines": cracked_passwords},
        )
        db.add(dynamic_resource)
        await db.flush()  # Get PK if needed
        word_list_id = dynamic_resource.id
    # Prepare ORM model data
    attack_kwargs = data.model_dump(exclude_unset=True)
    if word_list_id is not None:
        attack_kwargs["word_list_id"] = word_list_id
    # Remove fields not present in the Attack model
    attack_kwargs.pop("rule_list_id", None)
    attack_kwargs.pop("mask_list_id", None)
    attack = Attack(**attack_kwargs)
    db.add(attack)
    await db.commit()
    await db.refresh(attack)
    return AttackOut.model_validate(attack, from_attributes=True)


__all__ = [
    "AttackNotFoundError",
    "InvalidAgentTokenError",
    "bulk_delete_attacks_service",
    "create_attack_service",
    "duplicate_attack_service",
    "estimate_attack_keyspace_and_complexity",
    "export_attack_template_service",
    "get_attack_config_service",
    "move_attack_service",
    "update_attack_service",
]
