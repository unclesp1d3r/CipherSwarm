# 🎯 CipherSwarm Phase 2 Endpoint Hygiene Sweep

Skirmish must complete this sweep after all `/api/v1/web/*` endpoints have been implemented and tested.

This pass is required to clean up minor violations of project-specific coding standards that may not be caught by `just ci-check` but are essential to long-term quality.

---

## 🔍 Common Skipped Rules to Fix

### ❌ Skipped: Proper HTMX Integration

-   [ ] Replace all `TemplateResponse(...)` and `return {"foo": bar}` in HTMX-compatible endpoints with `FastHX.template(...)` or `FastHX.partial(...)`
-   [ ] HTMX endpoints **must return a Pydantic `BaseModel`**, not a `dict`
-   [ ] The model fields are unpacked automatically and available as top-level variables in the Jinja2 template

> ✅ Correct Usage:

```python
from pydantic import BaseModel
from app.web.templates import jinja

class AgentListContext(BaseModel):
    agents: list[AgentSummary]

@router.get("/agents")
@jinja.page("agents/list.html")
async def list_agents(...) -> AgentListContext:
    # build context using service layer
    return AgentListContext(agents=await get_agents(...))
```

> ⚠️ Don't do this:
>
> -   `return TemplateResponse(...)`
> -   `return {"agents": agents}` (will raise `TypeError`)
> -   `context: dict = {...}` — violates model unpacking and schema typing

> 📘 See: `fasthx-guidelines.mdc` — HTMX views must always use FastHX.

---

### ❌ Skipped: Endpoint Purity

-   [ ] Ensure **no database access** occurs in endpoint functions (move all DB access to services or `crud.py`)
-   [ ] Use `Depends(get_db)` only inside service-layer helpers, not in the route body

> 📘 See: `service-patterns.mdc` — all persistence logic must be kept outside endpoints.

---

### ❌ Skipped: FastAPI Idiomatic Parameter Usage

-   [ ] Remove all usage of `request: Request` for parameter parsing or user/project extraction
-   [ ] Replace with proper `Annotated[...]` dependencies:

```python
user: Annotated[User, Depends(current_user)]
project: Annotated[Project, Depends(get_current_project)]
```

> 📘 See: `fastapi-guidelines.mdc` — context should always use DI, never request-manual parsing.

---

### 🧼 Style Cleanups

#### 🔧 `getattr` vs direct access

-   [ ] Replace `getattr(foo, "bar")` with `foo.bar` unless:

    -   Field is dynamic
    -   There's a fallback value
    -   Object may be missing the attribute and is guarded

#### 🔧 Typing + Models

-   [ ] Eliminate `dict[str, object]` returns
-   [ ] Ensure all route input/output is typed with Pydantic v2 models

#### 🔧 Imports

-   [ ] Alphabetize imports within groups (`stdlib`, `third-party`, `local`)
-   [ ] Remove any unused imports that snuck back in

> 📘 See: `python-style.mdc` — use direct access over reflection, and structure imports consistently.

---

## 🧪 Final Checks

-   [ ] Run full `just ci-check` again
-   [ ] Run Swagger + ReDoc to visually inspect OpenAPI docs
-   [ ] Re-export `/openapi.json` if route metadata was updated
-   [ ] Confirm all HTMX fragment endpoints behave correctly when triggered via frontend

---

## ✅ Completion Criteria

All existing `/api/v1/web/*` endpoints must conform to:

-   FastHX for any HTMX route
-   Service-layer separation for DB logic
-   Proper FastAPI DI for context
-   Clean, direct attribute access
-   Valid OpenAPI schema (Pydantic-typed, no JSON dict hacks)
