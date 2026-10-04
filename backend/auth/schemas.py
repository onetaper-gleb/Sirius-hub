from typing import Optional

from pydantic import BaseModel

from database.models import UserRole


class PromoteRequest(BaseModel):
    uid: str
    role: UserRole


class InitUserRequest(BaseModel):
    group_code: Optional[str] = None
