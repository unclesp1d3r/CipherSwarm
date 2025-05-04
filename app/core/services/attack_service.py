from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attack import Attack


class InvalidUserAgentError(Exception):
    pass


class InvalidAgentTokenError(Exception):
    pass


class AttackNotFoundError(Exception):
    pass


async def get_attack_config_service(
    attack_id: int,
    db: AsyncSession,
    authorization: str,
    user_agent: str,
) -> Attack:
    if not user_agent.startswith("CipherSwarm-Agent/"):
        raise InvalidUserAgentError("Invalid User-Agent header")
    if not authorization.startswith("Bearer csa_"):
        raise InvalidAgentTokenError("Invalid or missing agent token")
    # TODO: Validate agent token and fetch agent (stub for now)
    # TODO: Validate agent capability for attack (stub for now)
    result = await db.execute(select(Attack).filter(Attack.id == attack_id))
    attack = result.scalar_one_or_none()
    if not attack:
        raise AttackNotFoundError("Attack not found")
    return attack
