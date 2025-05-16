from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import JSONResponse
from packaging.version import InvalidVersion, Version
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.client_service import get_latest_cracker_binary_for_os
from app.models.agent import OperatingSystemEnum
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


router = APIRouter(prefix="/client/crackers", tags=["Crackers"])


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
    version: Annotated[str, Query(description="Current cracker version (semver)")],
    operating_system: Annotated[
        str, Query(description="Operating system (windows, linux, darwin)")
    ],
) -> JSONResponse:
    try:
        # Accept 'darwin' as 'macos' for compatibility
        os_str = operating_system.lower()
        if os_str == "darwin":
            os_str = "macos"
        os_enum = OperatingSystemEnum(os_str)
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
        try:
            current_version = Version(version)
            latest_version = Version(getattr(cracker, "version", "0.0.0"))
        except InvalidVersion as e:
            raise HTTPException(status_code=400, detail="Invalid version format") from e
        if current_version < latest_version:
            resp = CrackerUpdateResponse(
                available=True,
                latest_version=str(latest_version),
                download_url=getattr(cracker, "download_url", None),
                exec_name=getattr(cracker, "exec_name", None),
                message=f"Update available: {latest_version}",
            )
            return JSONResponse(status_code=200, content=resp.model_dump(mode="json"))
        resp = CrackerUpdateResponse(
            available=False,
            latest_version=str(latest_version),
            download_url=None,
            exec_name=getattr(cracker, "exec_name", None),
            message="You are up to date.",
        )
        return JSONResponse(status_code=200, content=resp.model_dump(mode="json"))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
