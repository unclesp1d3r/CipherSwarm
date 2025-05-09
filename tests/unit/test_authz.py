import typing
from types import SimpleNamespace

import pytest
from casbin.enforcer import Enforcer  # type: ignore[import-untyped]

from app.core.authz import (
    get_enforcer,
    get_user_role,
    user_can,
    user_can_access_project,
)
from app.models.project import Project, ProjectUserAssociation, ProjectUserRole
from app.models.user import User


class FakeUser:
    def __init__(self, is_superuser: bool = False) -> None:
        self.is_superuser = is_superuser


class FakeProject:
    def __init__(self, id: int) -> None:  # noqa: A002
        self.id = id


@pytest.fixture(scope="module")
def enforcer() -> Enforcer:
    return get_enforcer()


@pytest.mark.parametrize(
    ("role", "resource", "action", "expected"),
    [
        ("admin", "project:abc", "read", True),
        ("admin", "project:abc", "write", True),
        ("admin", "project:abc", "delete", True),
        ("project_admin", "project:abc", "read", True),
        ("project_admin", "project:abc", "write", True),
        ("project_admin", "project:abc", "delete", True),
        ("project_user", "project:abc", "read", True),
        ("project_user", "project:abc", "write", True),
        ("project_user", "project:abc", "delete", False),
    ],
)
def test_user_can_roles(
    role: str,
    resource: str,
    action: str,
    expected: bool,
    enforcer: Enforcer,
) -> None:
    # Patch get_user_role to return the role
    class DummyUser:
        pass

    user = typing.cast("User", DummyUser())
    # Patch get_user_role
    orig = __import__("app.core.authz").core.authz.get_user_role
    __import__("app.core.authz").core.authz.get_user_role = lambda u: role  # noqa: ARG005
    try:
        assert user_can(user, resource, action) is expected
    finally:
        __import__("app.core.authz").core.authz.get_user_role = orig


@pytest.mark.parametrize(
    ("is_superuser", "expected_role"),
    [
        (True, "admin"),
        (False, "project_user"),
    ],
)
def test_get_user_role(is_superuser: bool, expected_role: str) -> None:
    user = typing.cast("User", FakeUser(is_superuser=is_superuser))
    # Patch: add project_associations for RBAC
    user.project_associations = [
        ProjectUserAssociation(project=Project(id="abc"), role=ProjectUserRole.member)
    ]
    assert get_user_role(user) == expected_role


@pytest.mark.parametrize(
    ("user_role", "action", "should_allow"),
    [
        ("admin", "read", True),
        ("admin", "write", True),
        ("admin", "delete", True),
        ("project_admin", "read", True),
        ("project_admin", "write", True),
        ("project_admin", "delete", True),
        ("project_user", "read", True),
        ("project_user", "write", True),
        ("project_user", "delete", False),
    ],
)
def test_user_can_access_project(
    user_role: str,
    action: str,
    should_allow: bool,
    enforcer: Enforcer,
) -> None:
    user = typing.cast("User", SimpleNamespace())
    # Patch get_user_role
    orig = __import__("app.core.authz").core.authz.get_user_role
    __import__("app.core.authz").core.authz.get_user_role = lambda u: user_role  # noqa: ARG005
    project = typing.cast("Project", FakeProject(id=1))
    try:
        assert user_can_access_project(user, project, action) is should_allow
    finally:
        __import__("app.core.authz").core.authz.get_user_role = orig


def test_user_cannot_perform_unsupported_action(enforcer: Enforcer) -> None:
    # project_user tries unsupported action 'shutdown_system' on project:abc
    class DummyUser:
        pass

    user = typing.cast("User", DummyUser())
    orig = __import__("app.core.authz").core.authz.get_user_role
    __import__("app.core.authz").core.authz.get_user_role = lambda u: "project_user"  # noqa: ARG005
    try:
        assert user_can(user, "project:abc", "shutdown_system") is False
    finally:
        __import__("app.core.authz").core.authz.get_user_role = orig
