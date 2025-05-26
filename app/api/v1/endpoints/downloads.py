import io
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, status
from fastapi.responses import StreamingResponse
from loguru import logger
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import InvalidAgentTokenError, ResourceNotFoundError
from app.core.services.resource_service import (
    get_resource_download_url_service,
)
from app.db.session import get_db
from app.models.agent import Agent
from app.models.attack_resource_file import AttackResourceFile
from app.schemas.resource import EPHEMERAL_RESOURCE_TYPES

router = APIRouter(prefix="/downloads", tags=["Downloads"])


class ResourceDownloadResponseStub:
    url: str


@router.get(
    "/{resource_id}/download",
    status_code=status.HTTP_200_OK,
    summary="Get resource download URL",
    description="Generate a presigned URL for the given resource. Requires valid Authorization.",
)
async def get_resource_download_url(
    resource_id: UUID,  # This must be a UUID, not an int, unlike nearly all other IDs (except for user IDs)
    authorization: Annotated[str, Header(alias="Authorization")],
) -> dict[str, str]:
    try:
        url = await get_resource_download_url_service(resource_id, authorization)

    except InvalidAgentTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        ) from e
    except ResourceNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    else:
        return {"url": url}


@router.get(
    "/{resource_id}/ephemeral-download",
    status_code=status.HTTP_200_OK,
    summary="Download ephemeral resource as file",
    description="Download an ephemeral resource as a file. Requires valid Authorization.",
)
async def download_ephemeral_resource(
    resource_id: UUID,
    authorization: Annotated[str, Header(alias="Authorization")],
) -> StreamingResponse:
    if not authorization.startswith("Bearer csa_"):
        raise HTTPException(status_code=401, detail="Invalid or missing agent token")
    token = authorization.removeprefix("Bearer ").strip()
    db_gen = get_db()
    db: AsyncSession = await anext(db_gen)
    try:
        agent = await db.execute(select(Agent).where(Agent.token == token))
        agent_obj = agent.scalar_one_or_none()
        if not agent_obj:
            raise HTTPException(
                status_code=401, detail="Invalid or missing agent token"
            )
        resource = await db.get(AttackResourceFile, resource_id)
        if not resource:
            raise HTTPException(status_code=404, detail="Resource not found")
        if not (
            resource.resource_type in EPHEMERAL_RESOURCE_TYPES
            or not resource.is_uploaded
        ):
            raise HTTPException(status_code=404, detail="Resource is not ephemeral")
        lines = (
            resource.content["lines"]
            if resource.content and "lines" in resource.content
            else []
        )
        if not isinstance(lines, list):
            raise HTTPException(status_code=400, detail="Resource lines are not a list")
        file_content = "\n".join(lines)
        file_like = io.BytesIO(file_content.encode(resource.line_encoding or "utf-8"))
        logger.info(f"Agent {agent_obj.id} downloaded ephemeral resource {resource_id}")
        return StreamingResponse(
            file_like,
            media_type="text/plain",
            headers={
                "Content-Disposition": f"attachment; filename=resource_{resource_id}.txt"
            },
        )
    finally:
        await db.aclose()
