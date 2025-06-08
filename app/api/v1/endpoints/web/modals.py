"""
These endpoints are used to support modals in the web UI and are typically not used to manipulate
data.

They are typically unauthenticated and do not require a database connection.
"""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.services.agent_service import (
    _load_hash_mode_metadata,
    list_agents_service,
)
from app.core.services.resource_service import list_resources_for_modal_service
from app.db.session import get_db
from app.models.agent import AgentState
from app.models.attack_resource_file import AttackResourceFile, AttackResourceType
from app.models.user import User

router = APIRouter(prefix="/modals", tags=["Modals"])


class RuleExplanation(BaseModel):
    rule: Annotated[
        str,
        Field(description="Hashcat rule string", examples=["c"]),
    ]
    desc: Annotated[
        str,
        Field(
            description="Explanation of the rule", examples=["Lowercase all characters"]
        ),
    ]


class RuleExplanationList(BaseModel):
    rule_explanations: Annotated[
        list[RuleExplanation],
        Field(description="List of hashcat rule explanations"),
    ]


@router.get(
    "/rule_explanation",
    summary="Get hashcat rule explanations",
    description="Returns a list of common hashcat rules and their explanations for UI display.",
)
async def rule_explanation_modal() -> RuleExplanationList:
    rule_explanations = [
        RuleExplanation(rule="c", desc="Lowercase all characters"),
        RuleExplanation(rule="u", desc="Uppercase all characters"),
        RuleExplanation(rule="T0", desc="Toggle case of first character"),
        RuleExplanation(rule="l", desc="Lowercase (legacy)"),
        RuleExplanation(rule="d", desc="Duplicate word"),
        RuleExplanation(rule="r", desc="Reverse word"),
        RuleExplanation(rule="sa@", desc="Substitute 'a' with '@' (leetspeak)"),
        RuleExplanation(rule="sa4", desc="Substitute 'a' with '4' (leetspeak)"),
        # ... add more as needed ...
    ]
    return RuleExplanationList(rule_explanations=rule_explanations)


class AgentDropdownItem(BaseModel):
    id: Annotated[
        int,
        Field(description="Agent ID"),
    ]
    display_name: Annotated[
        str,
        Field(
            description="Agent display name, either custom_label or host_name if custom_label is not set"
        ),
    ]
    state: Annotated[
        AgentState,
        Field(description="Agent state, either active, stopped, error, or offline"),
    ]

    model_config = ConfigDict(populate_by_name=True)


@router.get(
    "/agents",
    summary="Get agent dropdown list",
    description="Returns a list of agents with display_name and status for dropdowns. Any authenticated user may access.",
)
async def agent_dropdown_modal(
    db: Annotated[AsyncSession, Depends(get_db)],
    _current_user: Annotated[User, Depends(get_current_user)],
    state: Annotated[
        AgentState | None, Query(description="Filter by agent state")
    ] = None,
    search: Annotated[
        str | None, Query(description="Search by host name or label")
    ] = None,
) -> list[AgentDropdownItem]:
    agents, _ = await list_agents_service(
        db, search=search, state=state.value if state else None, page=1, size=1000
    )
    # Use display_name = custom_label or host_name
    return [
        AgentDropdownItem(
            id=a.id,
            display_name=a.custom_label or a.host_name,
            state=a.state,
        )
        for a in agents
    ]


class ResourceDropdownItem(BaseModel):
    id: Annotated[
        UUID,
        Field(description="Resource ID"),
    ]
    file_name: Annotated[
        str,
        Field(description="Resource file name"),
    ]
    resource_type: AttackResourceType
    line_count: Annotated[
        int | None,
        Field(description="Number of lines in the resource"),
    ] = None
    byte_size: Annotated[
        int | None, Field(description="Size of the resource in bytes")
    ] = None
    updated_at: Annotated[
        str | None,
        Field(description="Last updated timestamp"),
    ] = None
    project_id: Annotated[
        int | None,
        Field(description="Project ID, if the resource is linked to a project"),
    ] = None
    unrestricted: Annotated[
        bool | None,
        Field(
            description="Whether the resource is visible to all system users or limited to a specific project"
        ),
    ] = None


@router.get(
    "/resources",
    summary="Get resource dropdown list",
    description="Returns a list of resources for dropdown selectors, filtered by current project or unrestricted. Excludes ephemeral/dynamic types. Admins see all.",
)
async def resource_dropdown_modal(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    resource_type: Annotated[
        AttackResourceType | None,
        Query(description="Filter by resource type"),
    ] = None,
    q: Annotated[str | None, Query(description="Search by resource name")] = None,
) -> list[ResourceDropdownItem]:
    items: list[AttackResourceFile] = await list_resources_for_modal_service(
        db=db,
        current_user=current_user,
        resource_type=resource_type,
        q=q,
    )
    return [
        ResourceDropdownItem(
            id=r.id,
            file_name=r.file_name,
            resource_type=r.resource_type,
            line_count=r.line_count,
            byte_size=r.byte_size,
            updated_at=r.updated_at.isoformat() if r.updated_at else None,
            project_id=r.project_id,
            unrestricted=(r.project_id is None),
        )
        for r in items
    ]


class HashTypeDropdownItem(BaseModel):
    mode: int
    name: str
    category: str
    confidence: float | None = None


@router.get(
    "/hash_types",
    summary="Get hash type dropdown list",
    description="Returns a list of hash types (mode, name, category) for dropdowns. Supports optional filtering by name or mode, and confidence score if provided.",
)
async def hash_types_dropdown_modal(
    q: Annotated[str | None, Query(description="Filter by name or mode")] = None,
) -> list[HashTypeDropdownItem]:
    metadata = _load_hash_mode_metadata()
    items = list(metadata.hash_mode_map.values())
    # Filtering
    if q:
        q_lower = q.lower()
        items = [
            i for i in items if q_lower in i.name.lower() or q_lower in str(i.mode)
        ]
    # Sorting: by name ascending
    items.sort(key=lambda i: i.name)
    return [
        HashTypeDropdownItem(mode=i.mode, name=i.name, category=i.category)
        for i in items
    ]
