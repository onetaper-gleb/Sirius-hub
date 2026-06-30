from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth, firestore
from sqlalchemy import update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from auth.PromoteRequest import PromoteRequest
from database.database import get_db
from database.models import USER_DISPLAY_NAME_MAX_LEN
from database.models import User as DBUser

security = HTTPBearer()
db_firestore = firestore.client()

router = APIRouter(
    prefix="/auth",
    tags=["Auth"],
)


def get_current_user(res: HTTPAuthorizationCredentials = Depends(security)):
    token = res.credentials

    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Невалидный или истекший токен: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


def require_council_role(user: dict = Depends(get_current_user)):
    role = user.get("role", "student")
    if role != "council":
        raise HTTPException(
            status_code=403, detail="Только студсовет может публиковать новости."
        )
    return user


def _name_from_token(name: object | None) -> str | None:
    if name is None:
        return None
    s = str(name).strip()[:USER_DISPLAY_NAME_MAX_LEN]
    return s or None


@router.post("/init")
async def init_new_user(
    db: AsyncSession = Depends(get_db), user_data: dict = Depends(get_current_user)
):
    uid = user_data.get("uid")
    email = user_data.get("email")
    display_name = _name_from_token(user_data.get("name"))

    try:
        auth.set_custom_user_claims(uid, {"role": "student"})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Firebase error: {e}")

    try:
        stmt = insert(DBUser).values(
            id=uid,
            email=email,
            role="student",
            display_name=display_name,
        )

        stmt = stmt.on_conflict_do_update(
            index_elements=["id"],
            set_={
                "email": email,
            },
        )

        await db.execute(stmt)
        await db.commit()
        return {"status": "ok"}

    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error: {e}")


@router.post("/admin-action")
async def do_something_secret(user: dict = Depends(get_current_user)):
    role = user.get("role", "student")
    if role != "council":
        raise HTTPException(
            status_code=403, detail="Доступ запрещен. Только для студсовета."
        )

    return {"message": "Секретное действие выполнено"}


# TODO УДАЛИТЬ ЭТУ АПИШКУ КОГДА БУДУТ ИТОГОВЫЕ ПОЛЬЗОВАТЕЛИ.
@router.post("/test-make-me-council")
async def make_me_council(
    db_postgres: AsyncSession = Depends(get_db), user: dict = Depends(get_current_user)
):
    uid = user.get("uid")

    try:
        auth.set_custom_user_claims(uid, {"role": "council"})

        stmt = update(DBUser).where(DBUser.id == uid).values(role="council")
        await db_postgres.execute(stmt)
        await db_postgres.commit()

        user_ref = db_firestore.collection("users").document(uid)
        user_ref.update({"role": "council"})

        return {"status": "success", "message": "Роль обновлена везде!"}

    except Exception as e:
        await db_postgres.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка: {str(e)}")


@router.post("/promote-user")
async def promote_user(
    request: PromoteRequest,
    db: AsyncSession = Depends(get_db),
    current_admin: dict = Depends(require_council_role),
):
    target_uid = request.uid

    try:
        auth.set_custom_user_claims(target_uid, {"role": "council"})

        stmt = update(DBUser).where(DBUser.id == target_uid).values(role="council")
        result = await db.execute(stmt)

        if result.rowcount == 0:
            raise HTTPException(
                status_code=404, detail="Пользователь не найден в PostgreSQL."
            )

        user_ref = db_firestore.collection("users").document(target_uid)
        user_ref.set({"role": "council"}, merge=True)

        await db.commit()

        return {
            "status": "success",
            "message": f"Пользователь {target_uid} теперь в студсовете.",
        }

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при повышении: {str(e)}")
