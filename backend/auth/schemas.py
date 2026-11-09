from pydantic import BaseModel, EmailStr, Field, field_validator

from database.constants import (
    USER_DISPLAY_NAME_MAX_LEN,
    USER_PASSWORD_MAX_LEN,
    USER_PASSWORD_MIN_LEN,
)
from database.models import UserRole


class PromoteRequest(BaseModel):
    uid: str
    role: UserRole


class UserCreate(BaseModel):
    email: EmailStr = Field(max_length=254)
    password: str = Field(
        min_length=USER_PASSWORD_MIN_LEN, max_length=USER_PASSWORD_MAX_LEN
    )
    display_name: str | None = Field(default=None, max_length=USER_DISPLAY_NAME_MAX_LEN)

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, value):
        return value.strip().lower() if isinstance(value, str) else value


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
