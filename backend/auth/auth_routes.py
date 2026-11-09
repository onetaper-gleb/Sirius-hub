import uuid

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from auth.schemas import PromoteRequest, Token, UserCreate
from auth.security import (
    ALGORITHM,
    DUMMY_PASSWORD_HASH,
    SECRET_KEY,
    create_access_token,
    get_password_hash,
    verify_password,
)
from database.database import get_db
from database.models import User as DBUser
from database.models import UserRole

router = APIRouter(prefix="/auth", tags=["Auth"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")


async def get_current_user(
    token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db)
) -> dict:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Ошибка при проверке учетных данных",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
            options={"require": ["sub", "exp", "iat"]},
        )
        uid = payload["sub"]
        if not isinstance(uid, str) or not uid:
            raise credentials_exception
    except jwt.InvalidTokenError:
        raise credentials_exception

    result = await db.execute(select(DBUser).where(DBUser.id == uid))
    user = result.scalar_one_or_none()
    if user is None:
        raise credentials_exception
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Пользователь деактивирован")
    return {
        "uid": user.id,
        "email": user.email,
        "name": user.display_name,
        "role": user.role,
    }


async def require_council_role(user: dict = Depends(get_current_user)) -> dict:
    if user["role"] not in (UserRole.council.value, UserRole.admin.value):
        raise HTTPException(status_code=403, detail="Доступ запрещен")
    return user


async def require_admin_role(user: dict = Depends(get_current_user)) -> dict:
    if user["role"] != UserRole.admin.value:
        raise HTTPException(status_code=403, detail="Доступ запрещен")
    return user


@router.post("/register", response_model=Token, status_code=201)
async def register(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(DBUser.id).where(func.lower(DBUser.email) == str(user_data.email))
    )
    if result.scalar_one_or_none() is not None:
        raise HTTPException(status_code=409, detail="Email уже существует")
    uid = str(uuid.uuid4())
    db.add(
        DBUser(
            id=uid,
            email=str(user_data.email),
            display_name=user_data.display_name,
            hashed_password=get_password_hash(user_data.password),
            role=UserRole.student.value,
            is_active=True,
        )
    )
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=409, detail="Email уже существует")
    return Token(access_token=create_access_token({"sub": uid}))


@router.post("/token", response_model=Token)
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(DBUser).where(
            func.lower(DBUser.email) == form_data.username.strip().lower()
        )
    )
    user = result.scalar_one_or_none()
    valid_password = (
        verify_password(
            form_data.password, user.hashed_password if user else DUMMY_PASSWORD_HASH
        )
        if len(form_data.password) <= 1024
        else False
    )
    if user is None or not valid_password:
        raise HTTPException(
            status_code=401,
            detail="Неверный email или пароль",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Пользователь неактивен")
    return Token(access_token=create_access_token({"sub": user.id}))


@router.get("/me")
async def read_me(user: dict = Depends(get_current_user)):
    return {
        "id": user["uid"],
        "email": user["email"],
        "role": user["role"],
        "display_name": user["name"],
        "is_active": True,
    }


@router.post("/promote-user")
async def promote_user(
    request: PromoteRequest,
    db: AsyncSession = Depends(get_db),
    _admin: dict = Depends(require_admin_role),
):
    result = await db.execute(
        update(DBUser).where(DBUser.id == request.uid).values(role=request.role.value)
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    await db.commit()
    return {"status": "success"}
