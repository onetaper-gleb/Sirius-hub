import os

from dotenv import load_dotenv
from sqlalchemy.engine import URL
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import declarative_base

load_dotenv()

DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_NAME = os.getenv("DB_NAME")
DB_HOST = os.getenv("DB_HOST", "db")

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    if DB_USER and DB_PASSWORD and DB_NAME:
        DATABASE_URL = URL.create(
            "postgresql+asyncpg",
            username=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=int(os.getenv("DB_PORT") or 5432),
            database=DB_NAME,
        )
    else:
        DATABASE_URL = "sqlite+aiosqlite:///./test.db"

engine = create_async_engine(DATABASE_URL)

AsyncSessionLocal = async_sessionmaker(
    bind=engine, class_=AsyncSession, expire_on_commit=False, autoflush=True
)

Base = declarative_base()


async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
