from loguru import logger
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import InvalidAgentTokenError
from app.core.services.attack_complexity_service import AttackEstimationService
from app.models.agent import Agent
from app.models.attack import Attack, AttackState
from app.models.hashcat_benchmark import HashcatBenchmark
from app.schemas.attack import (
    AttackCreate,
    AttackMoveDirection,
    AttackOut,
    AttackResourceEstimationContext,
    EstimateAttackRequest,
    EstimateAttackResponse,
)
from app.schemas.shared import AttackTemplate


class AttackNotFoundError(Exception):
    pass


class AttackAlreadyExistsError(Exception):
    pass


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


async def export_attack_template_service(
    attack_id: int, db: AsyncSession
) -> AttackTemplate:
    result = await db.execute(select(Attack).where(Attack.id == attack_id))
    attack = result.scalar_one_or_none()
    if not attack:
        raise AttackNotFoundError(f"Attack {attack_id} not found")
    wordlist_guid = None
    rule_file = None
    masks = None
    wordlist_inline = None
    if attack.mask:
        masks = [attack.mask]
    if attack.left_rule:
        rule_file = attack.left_rule
    # TODO: If attack has an inlined wordlist, set wordlist_inline
    return AttackTemplate(
        mode=attack.attack_mode.value,
        wordlist_guid=wordlist_guid,
        rule_file=rule_file,
        min_length=attack.increment_minimum,
        max_length=attack.increment_maximum,
        masks=masks,
        wordlist_inline=wordlist_inline,
    )


__all__ = [
    "AttackNotFoundError",
    "InvalidAgentTokenError",
    "bulk_delete_attacks_service",
    "duplicate_attack_service",
    "estimate_attack_keyspace_and_complexity",
    "export_attack_template_service",
    "get_attack_config_service",
    "move_attack_service",
]
