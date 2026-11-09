from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth.auth_routes import promote_user, require_admin_role
from auth.schemas import PromoteRequest
from database.database import get_db
from database.models import User as DBUser

from .schemas import CreateRoleRequest
from .schemas import Role as RoleScheme

router = APIRouter(prefix="/roles", tags=["Roles"])


@router.post("/test-give_me_role", response_model=RoleScheme)
async def give_me_role(
    request: CreateRoleRequest,
    db_postgres: AsyncSession = Depends(get_db),
    user: dict = Depends(require_admin_role),
):
    result = await db_postgres.execute(
        select(DBUser.id).where(DBUser.email == request.u_email)
    )
    uid = result.scalar_one_or_none()
    if uid is None:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    await promote_user(
        request=PromoteRequest(uid=uid, role=request.u_role),
        db=db_postgres,
        current_admin=user,
    )
    return {"u_email": request.u_email, "u_role": request.u_role}
