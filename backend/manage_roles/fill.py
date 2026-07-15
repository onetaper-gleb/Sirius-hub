import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import select
from database.models import User as DBUser
from database.models import Base
from dotenv import load_dotenv
import asyncio
import os
from datetime import datetime, timezone

from firebase_admin import auth
import firebase_admin
from firebase_admin import credentials
import json
import base64

load_dotenv()

DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    if DB_USER and DB_PASSWORD and DB_NAME:
        DATABASE_URL = f"postgresql+asyncpg://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}"
    else:
        DATABASE_URL = os.getenv("DATABASE_URL", "sqlite+aiosqlite:///./test.db")

print(f'DATABASE_URL: {DATABASE_URL}')
engine = create_async_engine(DATABASE_URL, echo=True)
SessionLocal = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

def utc_now_naive():
    return datetime.now(timezone.utc).replace(tzinfo=None)

async def create_tables():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("Таблицы созданы успешно!")

def init_firebase():
    if firebase_admin._apps:
        print("Firebase уже инициализирован")
        return firebase_admin.get_app()
    
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

async def create_firebase_users_and_db():
    try:
        app = init_firebase()
    except Exception as e:
        print(f"Ошибка инициализации Firebase: {e}")
        print("⏭Пропускаем создание пользователей в Firebase")
        return []
    
    firebase_and_db_users = [
        {
            "email": "test-student@gmail.com",
            "password": "Test123!@#",
            "display_name": "Test Student",
            "role": "student",
            "avatar_emoji": "👨‍🎓",
            "group_code": "G001",
            "bio": "Test student bio",
            "telegram_handle": "@test_student"
        },
        {
            "email": "test-council@gmail.com",
            "password": "Test123!@#",
            "display_name": "Test Council",
            "role": "council",
            "avatar_emoji": "👨‍💼",
            "group_code": "G002",
            "bio": "Test council member bio",
            "telegram_handle": "@test_council"
        },
        {
            "email": "test-admin@gmail.com",
            "password": "Test123!@#",
            "display_name": "Test Admin",
            "role": "admin",
            "avatar_emoji": "👨‍💻",
            "group_code": "G003",
            "bio": "Test admin bio",
            "telegram_handle": "@test_admin"
        },
        {
            "email": "test-superadmin@gmail.com",
            "password": "Test123!@#",
            "display_name": "Test Super Admin",
            "role": "admin",
            "avatar_emoji": "👑",
            "group_code": "G004",
            "bio": "Test super admin bio",
            "telegram_handle": "@test_admin"
        },
        {
            "email": "new-email1@gmail.com",
            "password": "Test123!@#",
            "display_name": "New User 1",
            "role": "student",
            "avatar_emoji": "👤",
            "group_code": "G005",
            "bio": "New user 1 bio",
            "telegram_handle": "@new_user1"
        },
        {
            "email": "new-email2@gmail.com",
            "password": "Test123!@#",
            "display_name": "New User 2",
            "role": "student",
            "avatar_emoji": "👤",
            "group_code": "G006",
            "bio": "New user 2 bio",
            "telegram_handle": "@new_user2"
        }
    ]
    
    created_count = 0
    updated_count = 0
    skipped_count = 0
    
    print("\nСоздание пользователей в Firebase и БД...")
    
    async with SessionLocal() as session:
        for user_data in firebase_and_db_users:
            firebase_uid = None
            
            # Работа с Firebase
            try:
                try:
                    user = auth.get_user_by_email(user_data["email"])
                    firebase_uid = user.uid
                    print(f"Пользователь {user_data['email']} уже существует в Firebase")
                    
                    auth.update_user(
                        user.uid,
                        password=user_data["password"],
                        display_name=user_data["display_name"],
                        email_verified=True
                    )
                    updated_count += 1
                    print(f"Обновлены данные")
                    
                except auth.UserNotFoundError:
                    user = auth.create_user(
                        email=user_data["email"],
                        password=user_data["password"],
                        display_name=user_data["display_name"],
                        email_verified=True
                    )
                    firebase_uid = user.uid
                    created_count += 1
                    print(f"Создан пользователь в Firebase: {user_data['email']} (UID: {user.uid})")
                
            except Exception as e:
                print(f"Ошибка при создании в Firebase {user_data['email']}: {e}")
                skipped_count += 1
                continue
            
            # Работа с БД
            if firebase_uid:
                stmt = select(DBUser).where(DBUser.email == user_data["email"])
                result = await session.execute(stmt)
                existing_user = result.scalar_one_or_none()
                
                if existing_user:
                    print(f"Пользователь {user_data['email']} уже существует в БД")
                    continue
                
                user = DBUser(
                    id=firebase_uid,
                    email=user_data["email"],
                    role=user_data["role"],
                    display_name=user_data.get("display_name"),
                    avatar_emoji=user_data.get("avatar_emoji"),
                    group_code=user_data.get("group_code"),
                    bio=user_data.get("bio"),
                    telegram_handle=user_data.get("telegram_handle"),
                    created_at=utc_now_naive()
                )
                session.add(user)
                print(f"Добавлен пользователь в БД: {user_data['email']} с ролью {user_data['role']}")
        
        await session.commit()
        print(f"\nБД: Данные успешно добавлены!")
    
    if created_count > 0:
        print(f"Создано новых пользователей в Firebase: {created_count}")
    if updated_count > 0:
        print(f"Обновлено существующих пользователей: {updated_count}")
    if skipped_count > 0:
        print(f"Пропущено пользователей: {skipped_count}")
    print(f"Всего обработано: {created_count + updated_count + skipped_count}\n")
    
    return firebase_and_db_users

async def show_users():
    async with SessionLocal() as session:
        stmt = select(DBUser)
        result = await session.execute(stmt)
        users = result.scalars().all()
        
        print("\nТекущие пользователи в БД")
        print("-" * 80)
        print(f"{'Email':<35} {'Роль':<12} {'Display Name':<20}")
        print("-" * 80)
        for user in users:
            display = user.display_name or "N/A"
            print(f"{user.email:<35} {user.role:<12} {display:<20}")
        print("-" * 80)
        print(f"Всего пользователей: {len(users)}\n")

async def main():
    await create_tables()

    await create_firebase_users_and_db()
    
    await show_users()
    
    print("\nТеперь вы можете тестировать ваш скрипт:")
    print("  python promote.py new-email1@gmail.com admin")
    print("  python promote.py test-student@gmail.com admin")
    print("  python promote.py fake@gmail.com admin")
    print("\n📝 Примеры:")
    print("  python promote.py new-email1@gmail.com admin")
    print("  python promote.py test-student@gmail.com council")

    print("\nДля входа в Firebase используйте:")
    print("  Email: test-student@gmail.com")
    print("  Пароль: Test123!@#")

if __name__ == "__main__":
    asyncio.run(main())