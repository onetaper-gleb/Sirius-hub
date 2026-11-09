from pydantic import BaseModel, EmailStr

from database.models import UserRole


class CreateRoleRequest(BaseModel):
    admin_id: str | None = None
    u_email: EmailStr
    u_role: UserRole


class Role(BaseModel):
    u_email: str
    u_role: str
