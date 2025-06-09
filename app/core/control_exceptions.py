"""Custom Control API exceptions using RFC9457 Problem Details format."""

from fastapi_problem.error import (
    BadRequestProblem,
    ForbiddenProblem,
    NotFoundProblem,
    ServerProblem,
)


class CampaignNotFoundError(NotFoundProblem):
    """Campaign not found error."""

    title = "Campaign Not Found"


class AttackNotFoundError(NotFoundProblem):
    """Attack not found error."""

    title = "Attack Not Found"


class AgentNotFoundError(NotFoundProblem):
    """Agent not found error."""

    title = "Agent Not Found"


class HashListNotFoundError(NotFoundProblem):
    """Hash list not found error."""

    title = "Hash List Not Found"


class HashItemNotFoundError(NotFoundProblem):
    """Hash item not found error."""

    title = "Hash Item Not Found"


class ResourceNotFoundError(NotFoundProblem):
    """Resource not found error."""

    title = "Resource Not Found"


class UserNotFoundError(NotFoundProblem):
    """User not found error."""

    title = "User Not Found"


class ProjectNotFoundError(NotFoundProblem):
    """Project not found error."""

    title = "Project Not Found"


class TaskNotFoundError(NotFoundProblem):
    """Task not found error."""

    title = "Task Not Found"


class InvalidAttackConfigError(BadRequestProblem):
    """Invalid attack configuration error."""

    title = "Invalid Attack Configuration"


class InvalidHashFormatError(BadRequestProblem):
    """Invalid hash format error."""

    title = "Invalid Hash Format"


class InvalidResourceFormatError(BadRequestProblem):
    """Invalid resource format error."""

    title = "Invalid Resource Format"


class InsufficientPermissionsError(ForbiddenProblem):
    """Insufficient permissions error."""

    title = "Insufficient Permissions"


class ProjectAccessDeniedError(ForbiddenProblem):
    """Project access denied error."""

    title = "Project Access Denied"


class InternalServerError(ServerProblem):
    """Internal server error."""

    title = "Internal Server Error"
