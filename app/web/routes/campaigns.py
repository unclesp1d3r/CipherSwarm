from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Form, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.models.project import Project

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
        "campaigns/list.html",
        {"request": request, "campaigns": campaigns},
    )


@router.get("/campaigns/new", response_class=HTMLResponse)
async def new_campaign_form(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(
        "campaigns/form.html",
        {"request": request, "campaign": None, "action": "/campaigns/new"},
    )


@router.post("/campaigns/new")
async def create_campaign(
    db: Annotated[AsyncSession, Depends(get_db)],
    name: Annotated[str, Form(...)],
    description: Annotated[str | None, Form(None)],
    private: Annotated[bool, Form(default=False)],
    notes: Annotated[str | None, Form(None)],
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
        "campaigns/form.html",
        {
            "request": request,
            "campaign": campaign,
            "action": f"/campaigns/{campaign_id}/edit",
        },
    )


@router.post("/campaigns/{campaign_id}/edit")
async def update_campaign(
    campaign_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    name: Annotated[str, Form(...)],
    description: Annotated[str | None, Form(None)],
    private: Annotated[bool, Form(default=False)],
    notes: Annotated[str | None, Form(None)],
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
        "campaigns/delete_confirm.html",
        {"request": request, "campaign": campaign},
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
        "campaigns/detail.html",
        {"request": request, "campaign": campaign},
    )
