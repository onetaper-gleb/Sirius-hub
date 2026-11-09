from pydantic import BaseModel

from database.models import UserRole


class CreateRoleRequest(BaseModel):
    admin_id: str
    u_email: str
    u_role: UserRole


class Role(BaseModel):
    u_email: str
    u_role: str
