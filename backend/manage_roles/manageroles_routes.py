
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

from auth.auth_routes import get_current_user

security = HTTPBearer()
db_firestore = firestore.client()

router = APIRouter(
    prefix="/roles",
    tags=["Roles"],
)

@router.post("/test-give_me_role{uid}{role_u}")
async def give_me_role(uid: str, role_u: str,
    db_postgres: AsyncSession = Depends(get_db), user: dict = Depends(get_current_user)):
    #uid = user.get("uid")

    try:
        auth.set_custom_user_claims(uid, {"role": role_u})

        stmt = update(DBUser).where(DBUser.id == uid).values(role=role_u)
        await db_postgres.execute(stmt)
        await db_postgres.commit()

        user_ref = db_firestore.collection("users").document(uid)
        user_ref.update({"role": role_u})

        return {"status": "success", "message": "Роль обновлена везде!"}
    
    except Exception as e:
        await db_postgres.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка: {str(e)}")
