from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, update
from sqlalchemy.ext.asyncio import AsyncSession

from auth.auth_routes import require_admin_role
from database.database import get_db
from database.models import User as DBUser

from .schemas import CreateRoleRequest
from .schemas import Role as RoleScheme

router = APIRouter(prefix="/roles", tags=["Roles"])


@router.post("/test-give_me_role", response_model=RoleScheme)
async def give_me_role(
    request: CreateRoleRequest,
    db_postgres: AsyncSession = Depends(get_db),
    _admin: dict = Depends(require_admin_role),
):
    result = await db_postgres.execute(
        update(DBUser)
        .where(func.lower(DBUser.email) == str(request.u_email).lower())
        .values(role=request.u_role.value)
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    await db_postgres.commit()
    return {"u_email": str(request.u_email), "u_role": request.u_role.value}
