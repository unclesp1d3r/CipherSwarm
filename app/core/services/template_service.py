from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attack_template_record import AttackTemplateRecord
from app.models.user import User, UserRole
from app.schemas.shared import (
    AttackTemplateRecordCreate,
    AttackTemplateRecordOut,
    AttackTemplateRecordUpdate,
)


def is_admin(user: User) -> bool:
    return user.role == UserRole.ADMIN or bool(getattr(user, "is_superuser", False))


async def list_templates_service(
    db: AsyncSession,
    current_user: User,
    attack_mode: str | None = None,
    project_id: int | None = None,
    recommended: bool | None = None,
) -> list[AttackTemplateRecordOut]:
    stmt = select(AttackTemplateRecord)
    if attack_mode:
        stmt = stmt.where(AttackTemplateRecord.attack_mode == attack_mode)
    if is_admin(current_user):
        if recommended is not None:
            stmt = stmt.where(AttackTemplateRecord.recommended.is_(recommended))
        if project_id is not None:
            stmt = stmt.where(
                or_(
                    AttackTemplateRecord.project_ids.is_(None),
                    AttackTemplateRecord.project_ids.op("@>")([project_id]),
                )
            )
    else:
        stmt = stmt.where(
            or_(
                AttackTemplateRecord.recommended.is_(True),
                AttackTemplateRecord.project_ids.is_(None),
            )
        )
    stmt = stmt.order_by(AttackTemplateRecord.created_at.desc())
    result = await db.execute(stmt)
    records = result.scalars().all()
    return [
        AttackTemplateRecordOut.model_validate(
            {
                "id": r.id,
                "name": r.name,
                "description": r.description,
                "attack_mode": r.attack_mode,
                "recommended": r.recommended,
                "project_ids": r.project_ids,
                "template_json": r.template_json,
                "created_at": r.created_at,
            },
            from_attributes=False,
        )
        for r in records
    ]


async def create_template_service(
    data: AttackTemplateRecordCreate,
    db: AsyncSession,
    current_user: User,
) -> AttackTemplateRecordOut:
    if not is_admin(current_user):
        raise PermissionError("Admin only")
    record = AttackTemplateRecord(
        name=data.name,
        description=data.description,
        attack_mode=data.attack_mode,
        recommended=data.recommended,
        project_ids=data.project_ids,
        template_json=data.template_json.model_dump(),
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    return AttackTemplateRecordOut.model_validate(
        {
            "id": record.id,
            "name": record.name,
            "description": record.description,
            "attack_mode": record.attack_mode,
            "recommended": record.recommended,
            "project_ids": record.project_ids,
            "template_json": record.template_json,
            "created_at": record.created_at,
        },
        from_attributes=False,
    )


async def get_template_service(
    template_id: int,
    db: AsyncSession,
) -> AttackTemplateRecordOut:
    record = await db.get(AttackTemplateRecord, template_id)
    if not record:
        raise LookupError("Template not found")
    return AttackTemplateRecordOut.model_validate(
        {
            "id": record.id,
            "name": record.name,
            "description": record.description,
            "attack_mode": record.attack_mode,
            "recommended": record.recommended,
            "project_ids": record.project_ids,
            "template_json": record.template_json,
            "created_at": record.created_at,
        },
        from_attributes=False,
    )


async def update_template_service(
    template_id: int,
    data: AttackTemplateRecordUpdate,
    db: AsyncSession,
    current_user: User,
) -> AttackTemplateRecordOut:
    if not is_admin(current_user):
        raise PermissionError("Admin only")
    record = await db.get(AttackTemplateRecord, template_id)
    if not record:
        raise LookupError("Template not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        if field == "template_json" and value is not None:
            setattr(record, field, value.model_dump())
        elif value is not None:
            setattr(record, field, value)
    await db.commit()
    await db.refresh(record)
    return AttackTemplateRecordOut.model_validate(
        {
            "id": record.id,
            "name": record.name,
            "description": record.description,
            "attack_mode": record.attack_mode,
            "recommended": record.recommended,
            "project_ids": record.project_ids,
            "template_json": record.template_json,
            "created_at": record.created_at,
        },
        from_attributes=False,
    )


async def delete_template_service(
    template_id: int,
    db: AsyncSession,
    current_user: User,
) -> None:
    if not is_admin(current_user):
        raise PermissionError("Admin only")
    record = await db.get(AttackTemplateRecord, template_id)
    if not record:
        raise LookupError("Template not found")
    await db.delete(record)
    await db.commit()
