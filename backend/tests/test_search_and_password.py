import asyncio

import httpx
from fastapi import FastAPI
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from auth.auth_routes import router as auth_router
from database.database import Base, get_db
from database.models import News, Topics, UserRole
from forum.forum_routes import forum_router
from news.news_routes import router as news_router


async def run_scenario(check):
    engine = create_async_engine("sqlite+aiosqlite://", poolclass=StaticPool)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    app = FastAPI()
    for router in (auth_router, news_router, forum_router):
        app.include_router(router)

    async def override_db():
        async with session_factory() as db:
            yield db

    app.dependency_overrides[get_db] = override_db
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as client:
            await check(client, session_factory)
    finally:
        await engine.dispose()


async def register_user(client, email="anna@example.com", password="old-password-123"):
    response = await client.post(
        "/auth/register", json={"email": email, "password": password}
    )
    assert response.status_code == 201, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_news_and_forum_search_ilike():
    async def check(client, sessions):
        headers = await register_user(client)

        async with sessions() as db:
            db.add_all(
                [
                    News(
                        id="n1",
                        title="Python Hackathon 2026",
                        content="Приглашаем всех студентов на хакатон",
                        author_id="u1",
                    ),
                    News(
                        id="n2",
                        title="Расписание экзаменов",
                        content="Опубликован график сессии по FastAPI",
                        author_id="u1",
                    ),
                    News(
                        id="n3",
                        title="100% скидка в столовой",
                        content="Специальное предложение",
                        author_id="u1",
                    ),
                    Topics(id="t1", title="Подготовка к Python", anon=False),
                    Topics(id="t2", title="Вопросы по общежитию", anon=True),
                ]
            )
            await db.commit()

        # Search news by title (case-insensitive)
        r = await client.get("/news/", params={"search": "python"}, headers=headers)
        assert r.status_code == 200
        assert [item["id"] for item in r.json()] == ["n1"]

        # Search news by content (case-insensitive)
        r = await client.get("/news/", params={"search": "fastapi"}, headers=headers)
        assert r.status_code == 200
        assert [item["id"] for item in r.json()] == ["n2"]

        # Wildcard characters should be escaped, not match all rows
        r = await client.get("/news/", params={"search": "100%"}, headers=headers)
        assert r.status_code == 200
        assert [item["id"] for item in r.json()] == ["n3"]

        # Empty/whitespace search returns all news
        r = await client.get("/news/", params={"search": "   "}, headers=headers)
        assert r.status_code == 200
        assert len(r.json()) == 3

        # Search forum topics by title (case-insensitive)
        r = await client.get(
            "/forum/topics", params={"search": "PYTHON"}, headers=headers
        )
        assert r.status_code == 200
        assert [item["topic_id"] for item in r.json()] == ["t1"]

        # Empty search returns all topics
        r = await client.get("/forum/topics", headers=headers)
        assert r.status_code == 200
        assert len(r.json()) == 2

    asyncio.run(run_scenario(check))


def test_change_password():
    async def check(client, _sessions):
        headers = await register_user(
            client, email="student@example.com", password="old-password-123"
        )

        # Unauthenticated request fails
        unauth = await client.post(
            "/auth/change-password",
            json={
                "old_password": "old-password-123",
                "new_password": "new-password-456",
            },
        )
        assert unauth.status_code == 401

        # Wrong old password fails with 400
        wrong = await client.post(
            "/auth/change-password",
            headers=headers,
            json={
                "old_password": "wrong-password",
                "new_password": "new-password-456",
            },
        )
        assert wrong.status_code == 400

        # Valid password change succeeds
        ok = await client.post(
            "/auth/change-password",
            headers=headers,
            json={
                "old_password": "old-password-123",
                "new_password": "new-password-456",
            },
        )
        assert ok.status_code == 200
        assert ok.json()["status"] == "success"

        # Old password no longer works
        old_login = await client.post(
            "/auth/token",
            data={"username": "student@example.com", "password": "old-password-123"},
        )
        assert old_login.status_code == 401

        # New password works
        new_login = await client.post(
            "/auth/token",
            data={"username": "student@example.com", "password": "new-password-456"},
        )
        assert new_login.status_code == 200
        assert "access_token" in new_login.json()

    asyncio.run(run_scenario(check))
