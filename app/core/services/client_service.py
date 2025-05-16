# mypy: disable-error-code="attr-defined"
# v2-only service functions removed as part of v2 Agent API removal and v1 decoupling (see v2_agent_api_removal.md)
from packaging.version import InvalidVersion, Version
from sqlalchemy import Result, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import (
    InvalidAgentTokenError,
)
from app.models.agent import OperatingSystemEnum
from app.models.cracker_binary import CrackerBinary


class TaskNotFoundError(Exception):
    pass


class AgentNotAssignedError(Exception):
    pass


class TaskNotRunningError(Exception):
    pass


# v2-only service functions removed below
# (see git history for previous v2 implementations)


async def get_latest_cracker_binary_for_os(
    db: AsyncSession, os_name: OperatingSystemEnum
) -> CrackerBinary | None:
    """Return the latest CrackerBinary for the given OS, using semantic version ordering."""
    result: Result[tuple[CrackerBinary]] = await db.execute(
        select(CrackerBinary).where(CrackerBinary.operating_system == os_name)
    )
    binaries = result.scalars().all()
    if not binaries:
        return None

    # Use packaging.version.Version to select the latest
    def safe_version(b: CrackerBinary) -> Version:
        try:
            return Version(b.version)
        except InvalidVersion:
            return Version("0.0.0")

    return max(binaries, key=safe_version)


__all__ = [
    "AgentNotAssignedError",
    "InvalidAgentTokenError",
    "TaskNotFoundError",
    "TaskNotRunningError",
    "get_latest_cracker_binary_for_os",
]
