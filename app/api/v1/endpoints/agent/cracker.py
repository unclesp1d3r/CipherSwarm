from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.client_service import get_latest_cracker_binary_for_os
from app.models.operating_system import OSName
from app.schemas.error import ErrorObject


class CrackerUpdateResponse(BaseModel):
    available: bool = Field(
        ..., description="A new version of the cracker binary is available"
    )
    latest_version: str | None = Field(
        None, description="The latest version of the cracker binary"
    )
    download_url: str | None = Field(
        None, description="The download URL of the new version"
    )
    exec_name: str | None = Field(None, description="The name of the executable")
    message: str | None = Field(None, description="A message about the update")


router = APIRouter()


@router.get(
    "/check_for_cracker_update",
    response_model=CrackerUpdateResponse,
    summary="Check for cracker update (v1 agent API)",
    description="Checks for an update to the cracker and returns update info if available.",
    tags=["Crackers"],
    responses={
        status.HTTP_200_OK: {"description": "successful"},
        status.HTTP_400_BAD_REQUEST: {
            "description": "bad request",
            "model": ErrorObject,
        },
        status.HTTP_401_UNAUTHORIZED: {
            "description": "unauthorized",
            "model": ErrorObject,
        },
    },
)
async def check_for_cracker_update_v1(
    db: Annotated[AsyncSession, Depends(get_db)],
    operating_system: Annotated[
        str, Query(description="Operating system (windows, linux, darwin)")
    ],
) -> JSONResponse:
    try:
        os_enum = (
            OSName(operating_system)
            if not isinstance(operating_system, OSName)
            else operating_system
        )
        cracker = await get_latest_cracker_binary_for_os(db, os_enum)
        if cracker is None:
            resp = CrackerUpdateResponse(
                available=False,
                latest_version=None,
                download_url=None,
                exec_name=None,
                message="No updated crackers found for the specified operating system",
            )
            return JSONResponse(status_code=200, content=resp.model_dump(mode="json"))
        # If cracker is not None, build the response
        resp = CrackerUpdateResponse(
            available=True,
            latest_version=getattr(cracker, "version", None),
            download_url=getattr(cracker, "download_url", None),
            exec_name=getattr(cracker, "exec_name", None),
            message="A new version of the cracker binary is available",
        )
        return JSONResponse(status_code=200, content=resp.model_dump(mode="json"))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
