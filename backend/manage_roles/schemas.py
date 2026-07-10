from pydantic import BaseModel


class CreateRoleRequest(BaseModel):
    admin_id: str
    u_email: str
    u_role: str


class Role(BaseModel):
    u_email: str
    u_role: str
