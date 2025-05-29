"""
These endpoints are used to support modals in the web UI and are typically not used to manipulate
data.

They are typically unauthenticated and do not require a database connection.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.core.services.agent_service import list_agents_service
from app.models.agent import AgentState
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
    rule_explanations: list[RuleExplanation]


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
    id: int
    display_name: str
    state: AgentState

    class Config:
        from_attributes = True


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
