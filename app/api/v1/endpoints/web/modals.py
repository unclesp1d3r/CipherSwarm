"""
These endpoints are used to support modals in the web UI and are typically not used to manipulate
data.

They are typically unauthenticated and do not require a database connection.
"""

from typing import Annotated

from fastapi import APIRouter
from pydantic import BaseModel, Field

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
