from typing import Any

from fastapi import APIRouter, Request

from app.web.templates import jinja

router = APIRouter(prefix="/modals", tags=["Modals"])

"""
Rules to follow:
1. This endpoint MUST return a Pydantic response model via FastAPI.
2. DO NOT return TemplateResponse or render HTML fragments — this is a pure JSON API.
3. DO NOT include database logic — delegate to a service layer (e.g. campaign_service).
4. All request context (user, project, etc.) MUST come from DI dependencies — not request.query_params.
5. Use idiomatic FastAPI parameter handling — validate with Query(), Path(), Body(), Form(), etc.
6. Authorization checks are implemented — use user_can() instead of TODO comments.
7. Use Pydantic models for all input (query, body) and output (response).
8. Keep endpoints thin: only transform data, call service, and return results.
"""


# --- Rule Explanation Modal ---
@router.get("/rule_explanation")
@jinja.page("fragments/rule_explanation_modal.html.j2")
async def rule_explanation_modal(request: Request) -> dict[str, Any]:
    # Static mapping of common hashcat rules to explanations
    rule_explanations = [
        {"rule": "c", "desc": "Lowercase all characters"},
        {"rule": "u", "desc": "Uppercase all characters"},
        {"rule": "T0", "desc": "Toggle case of first character"},
        {"rule": "l", "desc": "Lowercase (legacy)"},
        {"rule": "d", "desc": "Duplicate word"},
        {"rule": "r", "desc": "Reverse word"},
        {"rule": "sa@", "desc": "Substitute 'a' with '@' (leetspeak)"},
        {"rule": "sa4", "desc": "Substitute 'a' with '4' (leetspeak)"},
        # ... add more as needed ...
    ]
    # Optionally, load more from bundled rule files if needed
    return {"request": request, "rule_explanations": rule_explanations}
