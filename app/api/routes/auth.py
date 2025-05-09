from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Form, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import create_access_token, verify_password
from app.db.session import get_db
from app.models.user import User

router = APIRouter()


@router.post("/auth/login")
async def login(
    email: str, password: str, db: Annotated[AsyncSession, Depends(get_db)]
) -> dict[str, str]:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=400, detail="Invalid credentials")
    hashed_password = str(user.hashed_password)
    user_id = UUID(str(user.id))
    if not verify_password(password, hashed_password):
        raise HTTPException(status_code=400, detail="Invalid credentials")
    access_token = create_access_token(user_id)
    return {"access_token": access_token}


@router.post("/auth/jwt/login")
async def jwt_login(
    db: Annotated[AsyncSession, Depends(get_db)],
    email: Annotated[str, Form(alias="email")],
    password: Annotated[str, Form(alias="password")],
) -> dict[str, str]:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=400, detail="Invalid credentials")
    hashed_password = str(user.hashed_password)
    user_id = UUID(str(user.id))
    if not verify_password(password, hashed_password):
        raise HTTPException(status_code=400, detail="Invalid credentials")
    access_token = create_access_token(user_id)
    return {"access_token": access_token}
