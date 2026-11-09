from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth
from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from auth.schemas import InitUserRequest, PromoteRequest
from database.constants import USER_DISPLAY_NAME_MAX_LEN
from database.database import get_db
from database.models import User as DBUser

security = HTTPBearer()

router = APIRouter(
    prefix="/auth",
    tags=["Auth"],
)


def get_current_user(res: HTTPAuthorizationCredentials = Depends(security)):
    token = res.credentials

    try:
        decoded_token = auth.verify_id_token(token, check_revoked=True)
        return decoded_token
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Невалидный или истекший токен",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def require_council_role(
    db: AsyncSession = Depends(get_db), user: dict = Depends(get_current_user)
):
    uid = user.get("uid")
    stmt = select(DBUser.role).where(DBUser.id == uid)
    result = await db.execute(stmt)
    role = result.scalar()

    if role not in ["council", "admin"]:
        raise HTTPException(
            status_code=403, detail="Только студсовет и администраторы имеют доступ."
        )
    return {**user, "role": role}


async def require_admin_role(
    db: AsyncSession = Depends(get_db), user: dict = Depends(get_current_user)
):
    result = await db.execute(select(DBUser.role).where(DBUser.id == user.get("uid")))
    if result.scalar() != "admin":
        raise HTTPException(
            status_code=403, detail="Только администраторы имеют доступ."
        )
    return {**user, "role": "admin"}


def _name_from_token(name: object | None) -> str | None:
    if name is None:
        return None
    s = str(name).strip()[:USER_DISPLAY_NAME_MAX_LEN]
    return s or None


@router.post("/init")
async def init_new_user(
    request: InitUserRequest | None = None,
    db: AsyncSession = Depends(get_db),
    user_data: dict = Depends(get_current_user),
):
    uid = user_data.get("uid")
    email = user_data.get("email")
    display_name = _name_from_token(user_data.get("name"))

    final_group_code = request.group_code if request else None

    if final_group_code == "":
        final_group_code = None

    try:
        stmt = insert(DBUser).values(
            id=uid,
            email=email,
            role="student",
            display_name=display_name,
            group_code=final_group_code,
        )

        update_values = {"email": email}
        if request is not None and "group_code" in request.model_fields_set:
            update_values["group_code"] = final_group_code
        stmt = stmt.on_conflict_do_update(
            index_elements=["id"],
            set_=update_values,
        )

        await db.execute(stmt)
        await db.commit()
        return {"status": "ok"}

    except Exception:
        await db.rollback()
        raise HTTPException(status_code=500, detail="Не удалось создать профиль")


@router.post("/promote-user")
async def promote_user(
    request: PromoteRequest,
    db: AsyncSession = Depends(get_db),
    current_admin: dict = Depends(require_admin_role),
):
    target_uid = request.uid
    target_role = request.role.value

    try:
        stmt = update(DBUser).where(DBUser.id == target_uid).values(role=target_role)
        result = await db.execute(stmt)

        if result.rowcount == 0:
            raise HTTPException(
                status_code=404, detail="Пользователь не найден в PostgreSQL."
            )

        auth.set_custom_user_claims(target_uid, {"role": target_role})
        await db.commit()

        return {
            "status": "success",
            "message": f"Пользователь {target_uid} теперь выдана роль {target_role}.",
        }

    except HTTPException:
        await db.rollback()
        raise
    except Exception:
        await db.rollback()
        raise HTTPException(status_code=500, detail="Не удалось изменить роль")
