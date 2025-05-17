# pyright: reportMissingTypeStubs=false
from pathlib import Path

import casbin  # type: ignore[import-untyped]

from app.models.project import Project, ProjectUserRole
from app.models.user import User

# Singleton enforcer
_enforcer = None

MODEL_PATH = Path(__file__).parents[2] / "config" / "model.conf"
POLICY_PATH = Path(__file__).parents[2] / "config" / "policy.csv"


def get_enforcer() -> casbin.Enforcer:
    if not hasattr(get_enforcer, "_enforcer"):
        if not MODEL_PATH.exists() or not POLICY_PATH.exists():
            raise RuntimeError(f"Casbin config missing: {MODEL_PATH} or {POLICY_PATH}")
        get_enforcer._enforcer = casbin.Enforcer(str(MODEL_PATH), str(POLICY_PATH))  # type: ignore[attr-defined]  # noqa: SLF001
    return get_enforcer._enforcer  # type: ignore[attr-defined]  # noqa: SLF001


def user_can(user: User, resource: str, action: str) -> bool:
    # Fast path for system-level admin checks
    if resource == "system" and action == "create_users":
        return (
            getattr(user, "is_superuser", False)
            or getattr(user, "role", None) == "admin"
        )
    enforcer = get_enforcer()
    role = get_user_role(user)
    return bool(enforcer.enforce(role, resource, action))


def user_can_access_project(user: User, project: Project, action: str = "read") -> bool:
    # For now, resource is project:{project_id}
    resource = f"project:{project.id}"
    return user_can(user, resource, action)


def get_user_role(user: User) -> str:
    # Check for superuser status
    if getattr(user, "is_superuser", False):
        return "admin"

    # Check project-specific roles
    for association in user.project_associations:
        if association.role == ProjectUserRole.admin:
            return "project_admin"

    # Default role
    return "project_user"
