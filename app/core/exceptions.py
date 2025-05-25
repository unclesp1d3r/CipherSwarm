class AgentAlreadyExistsError(Exception):
    """Raised when an agent with the same signature or hostname already exists."""


class AgentNotFoundError(Exception):
    """Raised when an agent is not found in the database."""


class InvalidAgentStateError(Exception):
    """Raised when an invalid agent state is provided."""


class InvalidAgentTokenError(Exception):
    """Raised when an agent token is invalid or missing."""


class ResourceNotFoundError(Exception):
    pass
