from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services import template_service
from app.models.user import User, UserRole
from app.schemas.shared import (
    AttackTemplateRecordCreate,
    AttackTemplateRecordOut,
    AttackTemplateRecordUpdate,
)

router = APIRouter(prefix="/templates", tags=["Templates"])


def is_admin(user: User) -> bool:
    return user.role == UserRole.ADMIN or getattr(user, "is_superuser", False)


# TODO: Replace with real JWT authentication when web UI login is implemented
# This is a test-only user stub for integration tests using static tokens
def get_test_user(request: Request) -> User:
    auth = request.headers.get("authorization", "")
    if auth == "Bearer test-admin-token":
        user = User(id=1, role=UserRole.ADMIN)
        user.is_superuser = True
        return user
    user = User(id=2, role=UserRole.ANALYST)
    user.is_superuser = False
    return user


@router.get("/")
async def list_templates(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_test_user)],
    attack_mode: Annotated[str | None, Query()] = None,
    project_id: Annotated[int | None, Query()] = None,
    recommended: Annotated[bool | None, Query()] = None,
) -> list[AttackTemplateRecordOut]:
    """
    List recommended templates, filtered by attack_mode and project_id.
    Non-admins see all recommended templates and all global templates (project_ids is None).
    """
    return await template_service.list_templates_service(
        db=db,
        current_user=current_user,
        attack_mode=attack_mode,
        project_id=project_id,
        recommended=recommended,
    )


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_template(
    data: AttackTemplateRecordCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_test_user)],
) -> AttackTemplateRecordOut:
    try:
        return await template_service.create_template_service(data, db, current_user)
    except PermissionError:
        raise HTTPException(status_code=403, detail="Admin only") from None


@router.get("/{template_id}")
async def get_template(
    template_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _current_user: Annotated[User, Depends(get_test_user)],
) -> AttackTemplateRecordOut:
    try:
        return await template_service.get_template_service(template_id, db)
    except LookupError:
        raise HTTPException(status_code=404, detail="Template not found") from None


@router.patch("/{template_id}")
async def update_template(
    template_id: int,
    data: AttackTemplateRecordUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_test_user)],
) -> AttackTemplateRecordOut:
    try:
        return await template_service.update_template_service(
            template_id, data, db, current_user
        )
    except PermissionError:
        raise HTTPException(status_code=403, detail="Admin only") from None
    except LookupError:
        raise HTTPException(status_code=404, detail="Template not found") from None


@router.delete("/{template_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_template(
    template_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_test_user)],
) -> None:
    try:
        await template_service.delete_template_service(template_id, db, current_user)
    except PermissionError:
        raise HTTPException(status_code=403, detail="Admin only") from None
    except LookupError:
        raise HTTPException(status_code=404, detail="Template not found") from None
