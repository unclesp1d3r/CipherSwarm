from typing import Any

from fastapi import APIRouter, Request

from app.web.templates import jinja

router = APIRouter(prefix="/modals", tags=["Modals"])

"""
Rules to follow:
1. Use @jinja.page() with a Pydantic return model
2. DO NOT use TemplateResponse or return dicts - absolutely avoid dict[str, object]
3. DO NOT put database logic here — call the appropriate service
4. Extract all context from DI dependencies, not request.query_params
5. Follow FastAPI idiomatic parameter usage
6. user_can() is available and implemented, so stop adding TODO items
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
