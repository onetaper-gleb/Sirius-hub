from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
# from firebase_admin import auth
from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from auth.schemas import PromoteRequest
from auth.schemas import Token, UserCreate
from auth.security import (
    ALGORITHM,
    SECRET_KEY,
    create_access_token,
    get_password_hash,
    verify_password,
)

from database.constants import USER_DISPLAY_NAME_MAX_LEN
from database.database import get_db
from database.models import User as DBUser, UserRole

import uuid
from datetime import timedelta
from jose import JWTError, jwt

#security = HTTPBearer()

router = APIRouter(
    prefix="/auth",
    tags=["Auth"],
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

async def get_current_user(token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db),):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Ошибка при проверке учетных данных",
        headers={"WWW-Authenticate": "Bearer"},)

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        uid: str | None = payload.get("sub")
        if uid is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    result = await db.execute(select(DBUser).where(DBUser.id == uid))
    user = result.scalar_one_or_none()
    
    if user is None:
        raise credentials_exception
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Пользователь деактивирован")
    return user


async def require_council_role(current_user: DBUser = Depends(get_current_user)):

    if current_user.role not in (UserRole.council.value, UserRole.admin.value):
        raise HTTPException(
            status_code=403, detail="Только студсовет и администраторы имеют доступ.")
    return current_user


# def _name_from_token(name: object | None) -> str | None:
#     if name is None:
#         return None
#     s = str(name).strip()[:USER_DISPLAY_NAME_MAX_LEN]
#     return s or None


# @router.post("/init")
# async def init_new_user(
#     db: AsyncSession = Depends(get_db), user_data: dict = Depends(get_current_user)
# ):
#     uid = user_data.get("uid")
#     email = user_data.get("email")
#     display_name = _name_from_token(user_data.get("name"))

#     try:
#         # auth.set_custom_user_claims(uid, {"role": "student"})  # replace
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=f"Firebase error: {e}")

#     try:
#         stmt = insert(DBUser).values(
#             id=uid,
#             email=email,
#             role="student",
#             display_name=display_name,
#         )

#         stmt = stmt.on_conflict_do_update(
#             index_elements=["id"],
#             set_={
#                 "email": email,
#             },
#         )

#         await db.execute(stmt)
#         await db.commit()
#         return {"status": "ok"}

#     except Exception as e:
#         await db.rollback()
#         raise HTTPException(status_code=500, detail=f"Database error: {e}")


# @router.post("/admin-action")
# async def do_something_secret(user: dict = Depends(get_current_user)):
#     role = user.get("role", "student")
#     if role != "council":
#         raise HTTPException(
#             status_code=403, detail="Доступ запрещен. Только для студсовета."
#         )

#     return {"message": "Секретное действие выполнено"}


@router.post("/register", response_model=Token, status_code=201)
async def register():
    pass

@router.post("/token", response_model=Token)
async def login_for_access_token():
    pass

# TODO УДАЛИТЬ ЭТУ АПИШКУ КОГДА БУДУТ ИТОГОВЫЕ ПОЛЬЗОВАТЕЛИ.
@router.post("/test-make-me-council")
async def make_me_council(
    db: AsyncSession = Depends(get_db), current_user: DBUser = Depends(get_current_user),):

    try:

        stmt = update(DBUser).where(DBUser.id == current_user.id).values(role=UserRole.council.value)
        await db.execute(stmt)
        await db.commit()

        return {"status": "success", "message": "Роль обновлена везде!"}

    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка: {str(e)}")


@router.post("/promote-user")
async def promote_user(
    request: PromoteRequest,
    db: AsyncSession = Depends(get_db),
    current_admin: dict = Depends(require_council_role),
):

    try:
        stmt = update(DBUser).where(DBUser.id == request.uid).values(role=request.role.value)
        result = await db.execute(stmt)

        if result.rowcount == 0:
            raise HTTPException(
                status_code=404, detail="Пользователь не найден в PostgreSQL."
            )

        await db.commit()

        return {
            "status": "success",
            "message": f"Пользователь {request.uid} теперь в студсовете.",
        }

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при повышении: {str(e)}")
