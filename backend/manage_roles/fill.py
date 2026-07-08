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
import uuid

from firebase_admin import auth

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

async def fill_test_data():
    async with SessionLocal() as session:
        test_users = [
            {
                "email": "test-student@gmail.com",
                "role": "student",
                "display_name": "Test Student",
                "avatar_emoji": "👨‍🎓",
                "group_code": "G001",
                "bio": "Test student bio",
                "telegram_handle": "@test_student"
            },
            {
                "email": "test-council@gmail.com",
                "role": "council",
                "display_name": "Test Council",
                "avatar_emoji": "👨‍💼",
                "group_code": "G002",
                "bio": "Test council member bio",
                "telegram_handle": "@test_council"
            },
            {
                "email": "test-admin@gmail.com",
                "role": "admin",
                "display_name": "Test Admin",
                "avatar_emoji": "👨‍💻",
                "group_code": "G003",
                "bio": "Test admin bio",
                "telegram_handle": "@test_admin"
            },
            {
                "email": "test-superadmin@gmail.com",
                "role": "superadmin",
                "display_name": "Test Super Admin",
                "avatar_emoji": "👑",
                "group_code": "G004",
                "bio": "Test super admin bio",
                "telegram_handle": "@test_superadmin"
            },
            {
                "email": "new-email1@gmail.com",
                "role": "student",
                "display_name": "New User 1",
                "avatar_emoji": "👤",
                "group_code": "G005",
                "bio": "New user 1 bio",
                "telegram_handle": "@new_user1"
            },
            {
                "email": "new-email2@gmail.com",
                "role": "student",
                "display_name": "New User 2",
                "avatar_emoji": "👤",
                "group_code": "G006",
                "bio": "New user 2 bio",
                "telegram_handle": "@new_user2"
            }
        ]
        
        for user_data in test_users:
            stmt = select(DBUser).where(DBUser.email == user_data["email"])
            result = await session.execute(stmt)
            existing_user = result.scalar_one_or_none()
            
            if existing_user:
                print(f"Пользователь {user_data['email']} уже существует")
                continue
            
            user = DBUser(
                id=str(uuid.uuid4()),
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
            print(f"Добавлен пользователь: {user_data['email']} с ролью {user_data['role']}")
        
        await session.commit()
        print(f"\nТестовые данные успешно добавлены!")

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

    await fill_test_data()
    
    await show_users()
    
    print("\nТеперь вы можете тестировать ваш скрипт:")
    print("  python promote.py new-email1@gmail.com admin")
    print("  python promote.py test-student@gmail.com superadmin")
    print("  python promote.py fake@gmail.com admin")
    print("\n📝 Примеры:")
    print("  python promote.py new-email1@gmail.com admin")
    print("  python promote.py test-student@gmail.com council")

if __name__ == "__main__":
    asyncio.run(main())