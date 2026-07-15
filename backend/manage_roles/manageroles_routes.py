from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPBearer
from firebase_admin import auth
from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from auth.auth_routes import get_current_user
from auth.PromoteRequest import PromoteRequest
from database.database import get_db
from database.models import USER_DISPLAY_NAME_MAX_LEN
from database.models import User as DBUser

from .schemas import CreateRoleRequest
from .schemas import Role as RoleScheme

security = HTTPBearer()

router = APIRouter(
    prefix="/roles",
    tags=["Roles"],
)


@router.post("/test-give_me_role", response_model=RoleScheme)
async def give_me_role(
    request: CreateRoleRequest,
    db_postgres: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):

    try:

        if user is None:
            raise HTTPException(status_code=404, detail="Пользователь не найден")

        email_u = request.u_email
        if email_u is None:
            raise HTTPException(status_code=404, detail="Пользователь не найден")

        role_u = request.u_role
        user_record = auth.get_user_by_email(email_u)
        uid = user_record.uid
        aid = request.admin_id

        # role_a = user.get("role", "student")
        role_a = select(DBUser.role).where(DBUser.id == aid)
        # if role != role2:
        #     role_u = "student"
        #     print(f"Роли не совпадают, установлена роль 'student'")

        if role_a == "student" or role_a == "council":
            raise HTTPException(status_code=403, detail="Доступ запрещен.")

        stmt = update(DBUser).where(DBUser.email == email_u).values(role=role_u)
        await db_postgres.execute(stmt)

        try:
            auth.set_custom_user_claims(uid, {"role": role_u})
        except Exception as e:
            await db_postgres.rollback()
            if "User not found" in str(e):
                raise HTTPException(
                    status_code=404, detail="Пользователь не найден в Firebase"
                )
            raise HTTPException(status_code=500, detail=f"Ошибка Firebase: {str(e)}")

        await db_postgres.commit()

        return {"u_email": email_u, "u_role": role_u}

    except Exception as e:
        await db_postgres.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка: {str(e)}")
