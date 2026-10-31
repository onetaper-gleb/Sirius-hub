from typing import Optional

from pydantic import BaseModel, EmailStr, Field

from database.models import UserRole
from database.constants import (
    USER_PASSWORD_MIN_LEN,
    USER_PASSWORD_MAX_LEN,
    USER_DISPLAY_NAME_MAX_LEN,
)


class PromoteRequest(BaseModel):
    uid: str
    role: UserRole


class InitUserRequest(BaseModel):
    group_code: Optional[str] = None


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(
        min_length=USER_PASSWORD_MIN_LEN, max_length=USER_PASSWORD_MAX_LEN
    )
    display_name: str | None = Field(default=None, max_length=USER_DISPLAY_NAME_MAX_LEN)


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
