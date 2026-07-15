import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import asyncio
import base64
import json

import firebase_admin
from dotenv import load_dotenv
from firebase_admin import auth, credentials
from sqlalchemy import create_engine, select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import sessionmaker

from database.models import User as DBUser

load_dotenv()

DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    if DB_USER and DB_PASSWORD and DB_NAME:
        DATABASE_URL = (
            f"postgresql+asyncpg://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}"
        )
    else:
        DATABASE_URL = os.getenv("DATABASE_URL", "sqlite+aiosqlite:///./test.db")

print(f"DATABASE_URL: {DATABASE_URL}")
engine = create_async_engine(DATABASE_URL)
# SessionLocal = sessionmaker(bind=engine)
SessionLocal = async_sessionmaker(
    bind=engine, class_=AsyncSession, expire_on_commit=False
)

print("engine got")


def init_firebase():
    base64_config = os.getenv("FIREBASE_CONFIG_BASE64")
    if base64_config:
        decoded_bytes = base64.b64decode(base64_config)
        config_dict = json.loads(decoded_bytes)
        cred = credentials.Certificate(config_dict)
        firebase_admin.initialize_app(cred)
        print("Firebase инициализирован через Base64!")
    else:
        print("Base64 конфиг не найден, ищу файл...")
        cred = credentials.Certificate("firebase-adminsdk.json")
        firebase_admin.initialize_app(cred)


init_firebase()


async def give_me_role(email, role_u):
    async with SessionLocal() as session:
        print("Session done")

    try:
        # user_record = auth.get_user_by_email(email)
        # uid = user_record.uid
        # auth.set_custom_user_claims(uid, {"role": role_u})

        stmt = update(DBUser).where(DBUser.email == email).values(role=role_u)

        print("stmt created")
        result = await session.execute(stmt)
        print("stmt executed")

        await session.commit()

        if result.rowcount == 0:
            print(f"Ошибка: пользователь с email {email} не найден")
            sys.exit(1)
        else:
            print(f"status: success; Роль обновлена везде!")

    # except auth.UserNotFoundError:
    #     print(f"Ошибка: Пользователь с email '{email}' не найден")
    #     sys.exit(1)

    except Exception as e:
        await session.rollback()
        print(f"Ошибка: {e}")
        sys.exit(1)

    # finally:
    #     session.close()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Использование: python3 promote.py EMAIL ROLE")
        print("Роли: student, council, admin, superadmin")
        sys.exit(1)

    email = sys.argv[1]
    role_u = sys.argv[2]

    print(email, role_u)

    valid_roles = ["student", "council", "admin", "superadmin"]
    if role_u not in valid_roles:
        print(f"Ошибка: роль '{role_u}' не существует")
        sys.exit(1)

    try:
        asyncio.run(give_me_role(email, role_u))
    except Exception as e:
        print(f"Ошибка: {e}")
        sys.exit(1)
