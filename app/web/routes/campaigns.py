import csv
import io
import json
import typing
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Form, HTTPException, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse, StreamingResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user, get_db
from app.models.attack import Attack
from app.models.campaign import Campaign
from app.models.hash_list import HashList
from app.models.project import Project, ProjectUserAssociation
from app.models.task import Task
from app.models.user import User

router = APIRouter()
templates = Jinja2Templates(directory="templates")


@router.get("/campaigns", response_class=HTMLResponse)
async def list_campaigns(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> HTMLResponse:
    result = await db.execute(select(Project))
    campaigns = result.scalars().all()
    return templates.TemplateResponse(
        request,
        "campaigns/list.html",
        {"campaigns": campaigns},
    )


@router.get("/campaigns/new", response_class=HTMLResponse)
async def new_campaign_form(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(
        request,
        "campaigns/form.html",
        {"campaign": None, "action": "/campaigns/new"},
    )


@router.post("/campaigns/new")
async def create_campaign(
    db: Annotated[AsyncSession, Depends(get_db)],
    name: Annotated[str, Form(...)],
    description: Annotated[str | None, Form()] = None,
    private: Annotated[bool, Form()] = False,
    notes: Annotated[str | None, Form()] = None,
) -> RedirectResponse:
    project = Project(
        name=name,
        description=description,
        private=private,
        notes=notes,
    )
    db.add(project)
    await db.commit()
    return RedirectResponse("/campaigns", status_code=status.HTTP_303_SEE_OTHER)


@router.get("/campaigns/{campaign_id}/edit", response_class=HTMLResponse)
async def edit_campaign_form(
    request: Request,
    campaign_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> HTMLResponse:
    result = await db.execute(select(Project).where(Project.id == campaign_id))
    campaign = result.scalar_one_or_none()
    return templates.TemplateResponse(
        request,
        "campaigns/form.html",
        {
            "campaign": campaign,
            "action": f"/campaigns/{campaign_id}/edit",
        },
    )


@router.post("/campaigns/{campaign_id}/edit")
async def update_campaign(
    campaign_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    name: Annotated[str, Form(...)],
    description: Annotated[str | None, Form()] = None,
    private: Annotated[bool, Form()] = False,
    notes: Annotated[str | None, Form()] = None,
) -> RedirectResponse:
    result = await db.execute(select(Project).where(Project.id == campaign_id))
    campaign = result.scalar_one_or_none()
    if campaign:
        campaign.name = name
        campaign.description = description
        campaign.private = private
        campaign.notes = notes
        await db.commit()
    return RedirectResponse("/campaigns", status_code=status.HTTP_303_SEE_OTHER)


@router.get("/campaigns/{campaign_id}/delete", response_class=HTMLResponse)
async def delete_campaign_confirm(
    request: Request,
    campaign_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> HTMLResponse:
    result = await db.execute(select(Project).where(Project.id == campaign_id))
    campaign = result.scalar_one_or_none()
    return templates.TemplateResponse(
        request,
        "campaigns/delete_confirm.html",
        {"campaign": campaign},
    )


@router.post("/campaigns/{campaign_id}/delete")
async def delete_campaign(
    campaign_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> RedirectResponse:
    result = await db.execute(select(Project).where(Project.id == campaign_id))
    campaign = result.scalar_one_or_none()
    if campaign:
        await db.delete(campaign)
        await db.commit()
    return RedirectResponse("/campaigns", status_code=status.HTTP_303_SEE_OTHER)


@router.get("/campaigns/{campaign_id}", response_class=HTMLResponse)
async def campaign_detail(
    request: Request,
    campaign_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> HTMLResponse:
    result = await db.execute(select(Project).where(Project.id == campaign_id))
    campaign = result.scalar_one_or_none()
    return templates.TemplateResponse(
        request,
        "campaigns/detail.html",
        {"campaign": campaign},
    )


@router.get("/campaigns/{campaign_id}/export.csv")
async def export_campaign_results_csv(  # noqa: C901
    campaign_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> StreamingResponse:
    stmt = (
        select(Campaign)
        .options(
            selectinload(Campaign.attacks).selectinload(Attack.tasks),
            selectinload(Campaign.project)
            .selectinload(Project.user_associations)
            .joinedload(ProjectUserAssociation.user),
        )
        .where(Campaign.id == campaign_id)
    )
    result = await db.execute(stmt)
    campaign = result.scalar_one_or_none()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
    # Check user is a member of the project
    project = campaign.project
    if not project or current_user not in project.users:
        raise HTTPException(status_code=403, detail="Not authorized for this campaign")

    # Helper to get cracked hashes for a task via HashList.items
    async def get_cracked_hashes_for_task(
        task: Task, db: AsyncSession
    ) -> list[dict[str, str]]:
        attack = getattr(task, "attack", None)
        if not attack:
            return []
        hash_list_id = getattr(attack, "hash_list_id", None)
        if not hash_list_id:
            return []
        hash_list_result = await db.execute(
            select(HashList).where(HashList.id == hash_list_id)
        )
        hash_list = hash_list_result.scalar_one_or_none()
        if not hash_list:
            return []
        return [
            {
                "hash": item.hash,
                "plain_text": item.plain_text,
                "attack_id": attack.id,
                "agent_id": str(task.agent_id) if task.agent_id else "",
                "timestamp_cracked": str(getattr(task, "updated_at", "")),
                "metadata": json.dumps(item.meta) if item.meta else "",
            }
            for item in hash_list.items
            if getattr(item, "plain_text", None)
        ]

    # Gather all cracked hashes for all attacks/tasks in this campaign
    rows = []
    for attack in campaign.attacks or []:
        for task in attack.tasks or []:
            cracked_hashes = await get_cracked_hashes_for_task(task, db)
            rows.extend(
                [
                    [
                        entry["hash"],
                        entry["plain_text"],
                        str(attack.id),
                        entry["agent_id"],
                        entry["timestamp_cracked"],
                        entry["metadata"],
                    ]
                    for entry in cracked_hashes
                ]
            )

    # Define CSV headers
    headers = [
        "hash",
        "plaintext",
        "attack_id",
        "agent_id",
        "timestamp_cracked",
        "metadata",
    ]

    # CSV generator
    def csv_generator() -> typing.Generator[str]:
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(headers)
        for row in rows:
            writer.writerow(row)
            yield output.getvalue()
            output.seek(0)
            output.truncate(0)

    # Return StreamingResponse
    return StreamingResponse(
        csv_generator(),
        media_type="text/csv",
        headers={
            "Content-Disposition": f"attachment; filename=campaign_{campaign_id}_results.csv",
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0",
        },
    )
