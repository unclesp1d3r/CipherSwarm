from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    Form,
    HTTPException,
    Request,
    Response,
)
from fastapi import (
    status as http_status,
)
from fastapi.templating import Jinja2Templates
from loguru import logger
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import create_access_token
from app.core.deps import get_current_user, get_db
from app.core.services.user_service import authenticate_user_service
from app.models.user import User
from app.web.templates import jinja

router = APIRouter(prefix="/auth", tags=["Auth"])
templates = Jinja2Templates(directory="templates")


class LoginResult(BaseModel):
    message: str
    level: str


@router.post("/login", summary="Login (Web UI)")
@jinja.hx("fragments/alert.html.j2")
async def login(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    email: Annotated[str, Form(...)],
    password: Annotated[str, Form(...)],
) -> LoginResult:
    user = await authenticate_user_service(email, password, db)
    if not user:
        logger.warning(f"Failed login attempt for email: {email}")
        request.state.hx_status_code = http_status.HTTP_401_UNAUTHORIZED
        return LoginResult(message="Invalid email or password.", level="error")
    if not user.is_active:
        logger.warning(f"Inactive user login attempt: {email}")
        request.state.hx_status_code = http_status.HTTP_403_FORBIDDEN
        return LoginResult(message="Account is inactive.", level="error")
    token = create_access_token(user.id)
    logger.info(f"User {user.email} logged in successfully.")
    response = LoginResult(message="Login successful.", level="success")
    # Set cookie via response headers (handled by FastAPI response hook)
    # FastHX does not allow direct response mutation, so set via request.state
    request.state.set_cookie = {
        "key": "access_token",
        "value": token,
        "httponly": True,
        "secure": True,
        "samesite": "lax",
        "max_age": 60 * 60,
    }
    return response


@router.post("/logout", summary="Logout (Web UI)")
async def logout(request: Request, response: Response) -> Response:
    response = templates.TemplateResponse(
        "fragments/alert.html.j2",
        {"request": request, "message": "Logged out.", "level": "success"},
        status_code=http_status.HTTP_200_OK,
    )
    response.delete_cookie("access_token")
    return response


@router.post("/refresh", summary="Refresh JWT token (Web UI)")
async def refresh_token() -> Response:
    # TODO: Implement token refresh logic
    raise HTTPException(status_code=501, detail="Not implemented yet.")


@router.get("/me", summary="Get current user profile (Web UI)")
async def get_me(current_user: Annotated[User, Depends(get_current_user)]) -> Response:  # noqa: ARG001
    # TODO: Return user profile fragment
    raise HTTPException(status_code=501, detail="Not implemented yet.")


@router.patch("/me", summary="Update current user profile (Web UI)")
async def update_me() -> Response:
    # TODO: Implement profile update
    raise HTTPException(status_code=501, detail="Not implemented yet.")


@router.post("/change_password", summary="Change password (Web UI)")
async def change_password() -> Response:
    # TODO: Implement password change
    raise HTTPException(status_code=501, detail="Not implemented yet.")


@router.get("/context", summary="Get user/project context (Web UI)")
async def get_context() -> Response:
    # TODO: Implement context fetch
    raise HTTPException(status_code=501, detail="Not implemented yet.")


@router.post("/context", summary="Set user/project context (Web UI)")
async def set_context() -> Response:
    # TODO: Implement context set
    raise HTTPException(status_code=501, detail="Not implemented yet.")
