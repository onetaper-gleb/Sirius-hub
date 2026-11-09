import os
from datetime import datetime, timedelta, timezone

import jwt
from dotenv import load_dotenv
from pwdlib import PasswordHash
from pwdlib.exceptions import UnknownHashError

load_dotenv()

SECRET_KEY = os.getenv("JWT_SECRET_KEY", "")
if len(SECRET_KEY.encode()) < 32:
    raise RuntimeError("JWT_SECRET_KEY must contain at least 32 bytes.")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))
if not 1 <= ACCESS_TOKEN_EXPIRE_MINUTES <= 10080:
    raise RuntimeError("ACCESS_TOKEN_EXPIRE_MINUTES must be between 1 and 10080.")

password_hash = PasswordHash.recommended()
DUMMY_PASSWORD_HASH = password_hash.hash("unused-login-timing-password")


def verify_password(password: str, hashed_password: str) -> bool:
    try:
        return password_hash.verify(password, hashed_password)
    except (UnknownHashError, ValueError):
        return False


def get_password_hash(password: str) -> str:
    return password_hash.hash(password)


def create_access_token(data: dict, expire_time: timedelta | None = None) -> str:
    now = datetime.now(timezone.utc)
    lifetime = (
        expire_time
        if expire_time is not None
        else timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    return jwt.encode(
        {**data, "iat": now, "exp": now + lifetime}, SECRET_KEY, algorithm=ALGORITHM
    )
