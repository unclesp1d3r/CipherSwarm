"""
🧭 JSON API Refactor – CipherSwarm Web UI

Follow these rules for all endpoints in this file:
1. Must return Pydantic models as JSON (no TemplateResponse or render()).
2. Must use FastAPI parameter types: Query, Path, Body, Depends, etc.
3. Must not parse inputs manually — let FastAPI validate and raise 422s.
4. Must use dependency-injected context for auth/user/project state.
5. Must not include database logic — delegate to a service layer (e.g. campaign_service).
6. Must not contain HTMX, Jinja, or fragment-rendering logic.
7. Must annotate live-update triggers with: # WS_TRIGGER: <event description>
8. Must update test files to expect JSON (not HTML) and preserve test coverage.

📘 See canonical task list and instructions:
↪️  docs/v2_rewrite_implementation_plan/side_quests/web_api_json_tasks.md
"""

from typing import Any

from fastapi import APIRouter, Request

from app.web.templates import jinja

router = APIRouter(prefix="/modals", tags=["Modals"])


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
