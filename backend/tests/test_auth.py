import asyncio
import os
from datetime import datetime, timedelta, timezone

os.environ.setdefault("JWT_SECRET_KEY", "test-only-secret-key-at-least-32-bytes")

import httpx
import jwt
import pytest
from fastapi import FastAPI
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from auth.auth_routes import router as auth_router
from auth.security import ALGORITHM, SECRET_KEY, create_access_token, get_password_hash
from database.database import Base, get_db
from database.models import User
from forum.forum_routes import forum_router
from manage_roles.manageroles_routes import router as roles_router
from profiles.routes import router as profile_router


async def run_scenario(check):
    engine = create_async_engine("sqlite+aiosqlite://", poolclass=StaticPool)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    app = FastAPI()
    for router in (auth_router, roles_router, profile_router, forum_router):
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


async def register(client, email="student@example.com", password="long-password-🔐"):
    response = await client.post(
        "/auth/register", json={"email": email, "password": password}
    )
    assert response.status_code == 201, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_registration_login_and_existing_profile_consumers():
    async def check(client, sessions):
        headers = await register(client, " Student@Example.com ")
        me = await client.get("/auth/me", headers=headers)
        assert me.status_code == 200
        assert me.json()["role"] == "student"
        assert me.json()["email"] == "student@example.com"
        assert "hashed_password" not in me.json()
        for endpoint in ("/profile/me", "/forum/topics"):
            response = await client.get(endpoint, headers=headers)
            assert response.status_code == 200, response.text
            assert "hashed_password" not in response.text
        profile = await client.put(
            "/profile/update", headers=headers, json={"display_name": "Student"}
        )
        assert profile.status_code == 200
        assert profile.json()["display_name"] == "Student"
        public = await client.get(f"/profile/user/{me.json()['id']}", headers=headers)
        assert public.status_code == 200
        assert "email" not in public.json()
        login = await client.post(
            "/auth/token",
            data={"username": "STUDENT@example.com", "password": "long-password-🔐"},
        )
        assert login.status_code == 200
        duplicate = await client.post(
            "/auth/register",
            json={"email": "STUDENT@example.com", "password": "different-password"},
        )
        assert duplicate.status_code == 409
        async with sessions() as db:
            user = await db.scalar(select(User))
            assert user.hashed_password.startswith("$argon2")
            assert "long-password" not in user.hashed_password

    asyncio.run(run_scenario(check))


def test_role_changes_need_admin_and_use_current_database_role():
    async def check(client, sessions):
        headers = await register(client)
        uid = (await client.get("/auth/me", headers=headers)).json()["id"]
        for role in ("student", "council"):
            async with sessions() as db:
                user = await db.get(User, uid)
                user.role = role
                await db.commit()
            response = await client.post(
                "/auth/promote-user",
                headers=headers,
                json={"uid": uid, "role": "admin"},
            )
            assert response.status_code == 403
            response = await client.post(
                "/roles/test-give_me_role",
                headers=headers,
                json={
                    "admin_id": "forged-admin",
                    "u_email": "student@example.com",
                    "u_role": "admin",
                },
            )
            assert response.status_code == 403
        assert (
            await client.post("/auth/test-make-me-council", headers=headers)
        ).status_code == 404
        async with sessions() as db:
            user = await db.get(User, uid)
            user.role = "admin"
            await db.commit()
        assert (
            await client.post(
                "/auth/promote-user",
                headers=headers,
                json={"uid": "missing", "role": "council"},
            )
        ).status_code == 404
        assert (
            await client.post(
                "/auth/promote-user",
                headers=headers,
                json={"uid": uid, "role": "student"},
            )
        ).status_code == 200
        assert (
            await client.post(
                "/auth/promote-user",
                headers=headers,
                json={"uid": uid, "role": "admin"},
            )
        ).status_code == 403

    asyncio.run(run_scenario(check))


def test_invalid_tokens_inactive_and_migrated_accounts_fail_closed():
    async def check(client, sessions):
        headers = await register(client)
        uid = (await client.get("/auth/me", headers=headers)).json()["id"]
        tokens = [
            "not-a-token",
            create_access_token({"sub": uid}, timedelta(seconds=-1)),
            create_access_token({"sub": "missing"}),
            jwt.encode({"sub": uid}, SECRET_KEY, algorithm=ALGORITHM),
            create_access_token({"sub": 42}),
            jwt.encode(
                {"sub": uid, "exp": datetime.now(timezone.utc) + timedelta(hours=1)},
                "wrong-secret-with-at-least-32-bytes",
                algorithm=ALGORITHM,
            ),
        ]
        for token in tokens:
            response = await client.get(
                "/auth/me", headers={"Authorization": f"Bearer {token}"}
            )
            assert response.status_code == 401, response.text
        async with sessions() as db:
            user = await db.get(User, uid)
            user.is_active = False
            await db.commit()
        assert (await client.get("/auth/me", headers=headers)).status_code == 403
        assert (
            await client.post(
                "/auth/token",
                data={
                    "username": "student@example.com",
                    "password": "long-password-🔐",
                },
            )
        ).status_code == 403
        async with sessions() as db:
            user = await db.get(User, uid)
            user.is_active = True
            user.hashed_password = "!"
            await db.commit()
        response = await client.post(
            "/auth/token",
            data={"username": "student@example.com", "password": "anything"},
        )
        assert response.status_code == 401
        assert (
            await client.post(
                "/auth/token",
                data={"username": "missing@example.com", "password": "anything"},
            )
        ).status_code == 401

    asyncio.run(run_scenario(check))


def test_unicode_passwords_do_not_truncate_and_registration_cannot_set_role():
    async def check(client, sessions):
        password = "🔐" * 32
        headers = await register(client, password=password)
        response = await client.post(
            "/auth/token",
            data={"username": "student@example.com", "password": password + "x"},
        )
        assert response.status_code == 401
        response = await client.post(
            "/auth/register",
            json={
                "email": "other@example.com",
                "password": "valid-password",
                "role": "admin",
            },
        )
        assert response.status_code == 201
        other_headers = {"Authorization": f"Bearer {response.json()['access_token']}"}
        assert (await client.get("/auth/me", headers=other_headers)).json()[
            "role"
        ] == "student"
        response = await client.post(
            "/auth/register", json={"email": "long@example.com", "password": "x" * 65}
        )
        assert response.status_code == 422

    asyncio.run(run_scenario(check))
