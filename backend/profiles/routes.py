import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth.auth_routes import get_current_user
from database.database import get_db
from database.models import (
    USER_AVATAR_EMOJI_MAX_LEN,
    USER_BIO_MAX_LEN,
    USER_DISPLAY_NAME_MAX_LEN,
    USER_GROUP_CODE_MAX_LEN,
    USER_TELEGRAM_HANDLE_MAX_LEN,
)
from database.models import User as DBUser

router = APIRouter(
    prefix="/profile",
    tags=["Profile"],
)


class ProfileResponse(BaseModel):
    id: str
    email: str | None
    role: str
    avatar_emoji: str | None
    display_name: str | None
    group_code: str | None
    bio: str | None
    telegram_handle: str | None
    created_at: datetime.datetime

    class Config:
        from_attributes = True


class PublicProfileResponse(BaseModel):
    """Профиль другого пользователя (без email)."""

    id: str
    role: str
    avatar_emoji: str | None
    display_name: str | None
    group_code: str | None
    bio: str | None
    telegram_handle: str | None
    created_at: datetime.datetime

    class Config:
        from_attributes = True


class ProfileUpdateBody(BaseModel):
    display_name: str | None = Field(default=None, max_length=USER_DISPLAY_NAME_MAX_LEN)
    group_code: str | None = Field(default=None, max_length=USER_GROUP_CODE_MAX_LEN)
    bio: str | None = Field(default=None, max_length=USER_BIO_MAX_LEN)
    telegram_handle: str | None = Field(
        default=None, max_length=USER_TELEGRAM_HANDLE_MAX_LEN
    )

    @field_validator("group_code")
    @classmethod
    def strip_group_code(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        return v or None

    @field_validator("display_name", "bio")
    @classmethod
    def strip_optional_text(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        return v or None

    @field_validator("telegram_handle")
    @classmethod
    def telegram_strip(cls, v: str | None) -> str | None:
        if v is None or v == "":
            return None
        v = v.strip()
        if v.startswith("tg/"):
            v = v[3:].strip()
        if v.startswith("@"):
            v = v[1:]
        return v or None


class AvatarPatchBody(BaseModel):
    avatar_emoji: str = Field(..., min_length=1, max_length=USER_AVATAR_EMOJI_MAX_LEN)

    @field_validator("avatar_emoji")
    @classmethod
    def single_emoji_only(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Пустой эмодзи")
        if " " in v:
            raise ValueError("Допустим только один эмодзи")
        return v


async def _get_db_user(db: AsyncSession, uid: str) -> DBUser | None:
    result = await db.execute(select(DBUser).where(DBUser.id == uid))
    return result.scalar_one_or_none()


@router.get("/me", response_model=ProfileResponse)
async def get_my_profile(
    db: AsyncSession = Depends(get_db),
    user_data: dict = Depends(get_current_user),
):
    uid = user_data.get("uid")
    row = await _get_db_user(db, uid)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Пользователь не найден в БД. Сначала вызовите POST /auth/init.",
        )
    return row


@router.get("/user/{user_id}", response_model=PublicProfileResponse)
async def get_user_public_profile(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    _user_data: dict = Depends(get_current_user),
):
    row = await _get_db_user(db, user_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Пользователь не найден.",
        )
    return row


@router.put("/update", response_model=ProfileResponse)
async def update_profile(
    body: ProfileUpdateBody,
    db: AsyncSession = Depends(get_db),
    user_data: dict = Depends(get_current_user),
):
    uid = user_data.get("uid")
    row = await _get_db_user(db, uid)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Пользователь не найден.",
        )

    data = body.model_dump(exclude_unset=True)

    for key, value in data.items():
        setattr(row, key, value)

    await db.commit()
    await db.refresh(row)
    return row


@router.patch("/avatar", response_model=ProfileResponse)
async def patch_avatar(
    body: AvatarPatchBody,
    db: AsyncSession = Depends(get_db),
    user_data: dict = Depends(get_current_user),
):
    uid = user_data.get("uid")
    row = await _get_db_user(db, uid)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Пользователь не найден.",
        )

    row.avatar_emoji = body.avatar_emoji
    await db.commit()
    await db.refresh(row)
    return row
