from typing import Optional

from pydantic import BaseModel, Field, field_validator

from database.constants import USER_GROUP_CODE_MAX_LEN
from database.models import UserRole


class PromoteRequest(BaseModel):
    uid: str
    role: UserRole


class InitUserRequest(BaseModel):
    group_code: Optional[str] = Field(default=None, max_length=USER_GROUP_CODE_MAX_LEN)

    @field_validator("group_code")
    @classmethod
    def strip_group_code(cls, value):
        return value.strip() or None if value is not None else None
