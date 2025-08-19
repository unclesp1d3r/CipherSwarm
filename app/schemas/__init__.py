"""CipherSwarm Pydantic schemas package.

This package contains all Pydantic schemas used for API request/response validation,
data serialization, and type safety across the CipherSwarm application.
"""

# Import v2 schemas for Agent API
from app.schemas.agent_v2 import (
    AgentHeartbeatRequestV2,
    AgentHeartbeatResponseV2,
    AgentRegisterRequestV2,
    AgentRegisterResponseV2,
    CrackedHashV2,
    ErrorResponseV2,
    ResourceUrlRequestV2,
    ResourceUrlResponseV2,
    TaskAssignmentResponseV2,
    TaskProgressResponseV2,
    TaskProgressUpdateV2,
    TaskResultResponseV2,
    TaskResultSubmissionV2,
)

__all__ = [
    # Agent API v2 schemas
    "AgentHeartbeatRequestV2",
    "AgentHeartbeatResponseV2",
    "AgentRegisterRequestV2",
    "AgentRegisterResponseV2",
    "CrackedHashV2",
    "ErrorResponseV2",
    "ResourceUrlRequestV2",
    "ResourceUrlResponseV2",
    "TaskAssignmentResponseV2",
    "TaskProgressResponseV2",
    "TaskProgressUpdateV2",
    "TaskResultResponseV2",
    "TaskResultSubmissionV2",
]
