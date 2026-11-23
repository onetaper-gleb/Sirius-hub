import asyncio

import httpx
from fastapi import FastAPI
from sqlalchemy import update
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from auth.auth_routes import router as auth_router
from database.database import Base, get_db
from database.models import News, User, UserRole
from news.news_routes import router as news_router
from profiles.routes import router as profile_router


async def run_scenario(check):
    engine = create_async_engine("sqlite+aiosqlite://", poolclass=StaticPool)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    app = FastAPI()
    for router in (auth_router, profile_router, news_router):
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


async def register_user(client, email, password="password-123"):
    response = await client.post(
        "/auth/register", json={"email": email, "password": password}
    )
    assert response.status_code == 201, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_study_groups_crud():
    async def check(client, sessions):
        student_headers = await register_user(client, "student@example.com")
        council_headers = await register_user(client, "council@example.com")

        async with sessions() as db:
            await db.execute(
                update(User)
                .where(User.email == "council@example.com")
                .values(role=UserRole.council.value)
            )
            await db.commit()

        # Student cannot create or update groups
        forbidden = await client.post(
            "/profile/groups",
            headers=student_headers,
            json={"name": "ИОП-ИТ-24/1"},
        )
        assert forbidden.status_code == 403

        # Council creates groups
        created = await client.post(
            "/profile/groups",
            headers=council_headers,
            json={"name": " ИОП-ИТ-24/1 "},
        )
        assert created.status_code == 201, created.text
        group_id = created.json()["id"]
        assert created.json()["name"] == "ИОП-ИТ-24/1"

        # Duplicate group name returns 409
        dup = await client.post(
            "/profile/groups",
            headers=council_headers,
            json={"name": "ИОП-ИТ-24/1"},
        )
        assert dup.status_code == 409

        # Create second group and test PATCH
        second = await client.post(
            "/profile/groups",
            headers=council_headers,
            json={"name": "ИОП-ИТ-24/2"},
        )
        assert second.status_code == 201

        updated = await client.patch(
            f"/profile/groups/{group_id}",
            headers=council_headers,
            json={"name": "ИОП-ИТ-24/3"},
        )
        assert updated.status_code == 200
        assert updated.json()["name"] == "ИОП-ИТ-24/3"

        # Duplicate name on PATCH returns 409
        dup_patch = await client.patch(
            f"/profile/groups/{group_id}",
            headers=council_headers,
            json={"name": "ИОП-ИТ-24/2"},
        )
        assert dup_patch.status_code == 409

        # Non-existent group returns 404
        missing = await client.patch(
            "/profile/groups/non-existent",
            headers=council_headers,
            json={"name": "ИОП-ИТ-24/9"},
        )
        assert missing.status_code == 404

        # GET returns all groups
        listed = await client.get("/profile/groups")
        assert listed.status_code == 200
        assert {g["name"] for g in listed.json()} == {"ИОП-ИТ-24/3", "ИОП-ИТ-24/2"}

    asyncio.run(run_scenario(check))


def test_news_views_counter_with_dedup():
    async def check(client, sessions):
        user1_headers = await register_user(client, "user1@example.com")
        user2_headers = await register_user(client, "user2@example.com")

        async with sessions() as db:
            db.add(
                News(
                    id="news-1",
                    title="Заголовок",
                    content="Текст новости",
                    author_id="author-1",
                )
            )
            await db.commit()

        # Initial views_count is 0
        initial = await client.get("/news/news-1", headers=user1_headers)
        assert initial.status_code == 200
        assert initial.json()["views_count"] == 0

        # First view by user1 increments counter
        view1 = await client.post("/news/news-1/view", headers=user1_headers)
        assert view1.status_code == 200
        assert view1.json() == {
            "news_id": "news-1",
            "views_count": 1,
            "incremented": True,
        }

        # Repeated view by user1 does NOT increment counter
        view1_again = await client.post("/news/news-1/view", headers=user1_headers)
        assert view1_again.status_code == 200
        assert view1_again.json() == {
            "news_id": "news-1",
            "views_count": 1,
            "incremented": False,
        }

        # View by user2 increments counter to 2
        view2 = await client.post("/news/news-1/view", headers=user2_headers)
        assert view2.status_code == 200
        assert view2.json() == {
            "news_id": "news-1",
            "views_count": 2,
            "incremented": True,
        }

        # Non-existent news returns 404
        missing = await client.post("/news/missing-id/view", headers=user1_headers)
        assert missing.status_code == 404

    asyncio.run(run_scenario(check))
