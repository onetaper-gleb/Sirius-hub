import base64
import datetime
import io
from pathlib import Path

import httpx
import pytest
from fastapi import FastAPI
from PIL import Image
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from auth import auth_routes
from auth.security import create_access_token
from database.database import Base, get_db
from database.models import Events, News, OfferNews, Registrations, Topics, User
from forum import forum_router, topic_router
from manage_roles import router as roles_router
from news import news_routes
from newsoffers import offers_routes
from profiles import router as profile_router
from schedule import classrooms_routes


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.fixture
async def api():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    async with sessions() as session:
        session.add_all(
            User(
                id=role,
                email=f"{role}@example.org",
                role=role,
                group_code="saved-group",
                hashed_password="!",
            )
            for role in ("student", "council", "admin")
        )
        session.add(
            User(
                id="other",
                email="other@example.org",
                role="student",
                hashed_password="!",
            )
        )
        await session.commit()

    async def database():
        async with sessions() as session:
            yield session

    app = FastAPI()
    for router in (
        auth_routes.router,
        roles_router,
        news_routes.router,
        offers_routes.router,
        profile_router,
        forum_router,
        topic_router,
        classrooms_routes.router,
    ):
        app.include_router(router)
    app.dependency_overrides[get_db] = database
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as client:
        yield client, sessions, None
    await engine.dispose()


def headers(role="student"):
    return {"Authorization": f"Bearer {create_access_token({"sub": role})}"}


def event_body(**changes):
    return {
        "title": "News title",
        "content": "News content",
        "has_event": True,
        "event_status": "published",
        "event_start": "2026-11-10T10:00:00",
        "event_end": "2026-11-10T12:00:00",
        "location": "Room 1",
        "max_partic": 1,
        "is_reg_open": True,
        **changes,
    }


@pytest.mark.anyio
async def test_self_promotion_removed_and_role_routes_require_real_admin(api):
    client, sessions, _ = api
    assert (
        await client.post("/auth/test-make-me-council", headers=headers())
    ).status_code == 404
    for role in ("student", "council"):
        response = await client.post(
            "/auth/promote-user",
            headers=headers(role),
            json={"uid": "student", "role": "admin"},
        )
        assert response.status_code == 403
        response = await client.post(
            "/roles/test-give_me_role",
            headers=headers(role),
            json={
                "admin_id": "admin",
                "u_email": "student@example.org",
                "u_role": "admin",
            },
        )
        assert response.status_code == 403
    response = await client.post(
        "/roles/test-give_me_role",
        headers=headers("admin"),
        json={
            "admin_id": "student",
            "u_email": "student@example.org",
            "u_role": "council",
        },
    )
    assert response.status_code == 200, response.text
    async with sessions() as session:
        assert (await session.get(User, "student")).role == "council"
    missing = await client.post(
        "/auth/promote-user",
        headers=headers("admin"),
        json={"uid": "missing", "role": "admin"},
    )
    assert missing.status_code == 404


@pytest.mark.anyio
async def test_profile_update_preserves_omitted_group_and_role(api):
    client, sessions, _ = api
    for payload in ({}, {"display_name": "Council"}):
        response = await client.put(
            "/profile/update", headers=headers("council"), json=payload
        )
        assert response.status_code == 200, response.text
    async with sessions() as session:
        user = await session.get(User, "council")
        assert user.group_code == "saved-group"
        assert user.role == "council"
    response = await client.put(
        "/profile/update", headers=headers(), json={"group_code": " "}
    )
    assert response.status_code == 200
    async with sessions() as session:
        assert (await session.get(User, "student")).group_code is None
    too_long = await client.put(
        "/profile/update", headers=headers(), json={"group_code": "a" * 1000}
    )
    assert too_long.status_code == 422


@pytest.mark.anyio
async def test_registrations_have_ids_and_count_only_occupied_places(api):
    client, sessions, _ = api
    news = await client.post("/news/", headers=headers("council"), json=event_body())
    assert news.status_code == 200, news.text
    event_id = news.json()["event_id"]
    first = await client.post(f"/news/events/{event_id}/register", headers=headers())
    assert first.status_code == 200, first.text
    assert first.json()["id"]
    assert first.json()["status"] == "moderation"
    duplicate = await client.post(
        f"/news/events/{event_id}/register", headers=headers()
    )
    assert duplicate.status_code == 400
    waiting = await client.post(
        f"/news/events/{event_id}/register", headers=headers("other")
    )
    assert waiting.status_code == 200, waiting.text
    assert waiting.json()["status"] == "waiting_list"
    response = await client.patch(
        f"/news/events/{event_id}/student",
        headers=headers("council"),
        data={"status": "confirmed"},
    )
    assert response.status_code == 200, response.text
    response = await client.patch(
        f"/news/events/{event_id}/other",
        headers=headers("council"),
        data={"status": "confirmed"},
    )
    assert response.status_code == 403
    async with sessions() as session:
        assert (await session.get(Events, event_id)).cur_partic == 1
        registration = await session.scalar(
            select(Registrations).where(Registrations.user_id == "other")
        )
        assert registration.status == "waiting_list"
    response = await client.get(
        f"/news/events/{event_id}/registrations", headers=headers("council")
    )
    assert response.status_code == 200, response.text
    assert len(response.json()) == 2
    for status in (
        "canceled_by_admin",
        "canceled_by_admin",
        "moderation",
        "confirmed",
        "waiting_list",
    ):
        response = await client.patch(
            f"/news/events/{event_id}/student",
            headers=headers("council"),
            data={"status": status},
        )
        assert response.status_code == 200, response.text
        async with sessions() as session:
            assert (await session.get(Events, event_id)).cur_partic == int(
                status in {"moderation", "confirmed"}
            )
    assert (
        await client.delete(f"/news/events/{event_id}/register", headers=headers())
    ).status_code == 200
    async with sessions() as session:
        assert (await session.get(Events, event_id)).cur_partic == 0


@pytest.mark.anyio
@pytest.mark.parametrize(
    "comment",
    [
        pytest.param(None, id="omitted"),
        pytest.param("", id="empty"),
        pytest.param("a" * 50, id="ascii-50"),
        pytest.param("😀" * 50, id="emoji-50"),
        pytest.param("e\u0301" * 25, id="decomposed-50-codepoints"),
    ],
)
async def test_registration_comment_form_round_trip_at_storage_limit(api, comment):
    client, sessions, _ = api
    news = await client.post("/news/", headers=headers("council"), json=event_body())
    assert news.status_code == 200, news.text
    event_id = news.json()["event_id"]
    response = await client.post(
        f"/news/events/{event_id}/register",
        headers=headers(),
        data={"comment": comment} if comment is not None else None,
    )
    assert response.status_code == 200, response.text
    expected = comment or None
    assert response.json()["comment"] == expected
    async with sessions() as session:
        registration = await session.get(Registrations, response.json()["id"])
        assert registration.comment == expected
        assert (await session.get(Events, event_id)).cur_partic == 1


@pytest.mark.anyio
@pytest.mark.parametrize(
    "comment",
    [
        pytest.param("a" * 51, id="ascii-51"),
        pytest.param("a" * 200, id="ascii-200"),
        pytest.param("a" * 201, id="ascii-201"),
        pytest.param("😀" * 51, id="emoji-51"),
        pytest.param("e\u0301" * 26, id="decomposed-52-codepoints"),
    ],
)
async def test_registration_rejects_long_comment_before_claiming_place(api, comment):
    client, sessions, _ = api
    news = await client.post("/news/", headers=headers("council"), json=event_body())
    assert news.status_code == 200, news.text
    event_id = news.json()["event_id"]
    response = await client.post(
        f"/news/events/{event_id}/register",
        headers=headers(),
        data={"comment": comment},
    )
    assert response.status_code == 422, response.text
    assert response.json()["detail"][0]["loc"] == ["body", "comment"]
    async with sessions() as session:
        assert (await session.get(Events, event_id)).cur_partic == 0
        assert await session.scalar(select(func.count(Registrations.id))) == 0


@pytest.mark.anyio
async def test_event_update_uses_iso_strings_and_does_not_shrink_below_occupancy(api):
    client, sessions, _ = api
    response = await client.post(
        "/news/", headers=headers("council"), json=event_body(max_partic=2)
    )
    assert response.status_code == 200, response.text
    news = response.json()
    for uid in ("student", "other"):
        assert (
            await client.post(
                f"/news/events/{news['event_id']}/register", headers=headers(uid)
            )
        ).status_code == 200
    response = await client.put(
        f"/news/{news['id']}",
        headers=headers("council"),
        json={"has_event": True, "max_partic": 1},
    )
    assert response.status_code == 400
    response = await client.put(
        f"/news/{news['id']}",
        headers=headers("council"),
        json={"has_event": True, "event_start": "2026-11-10T11:00:00"},
    )
    assert response.status_code == 200, response.text
    async with sessions() as session:
        event = await session.get(Events, news["event_id"])
        assert event.event_start == "2026-11-10T11:00:00"
        assert event.max_partic == 2
    invalid = await client.post(
        "/news/",
        headers=headers("council"),
        json=event_body(event_end="2026-11-09T12:00:00"),
    )
    assert invalid.status_code == 400


@pytest.mark.anyio
async def test_offers_use_path_id_and_protect_contacts(api):
    client, sessions, _ = api
    response = await client.post(
        "/offers/offers",
        headers=headers(),
        json={
            "title": "Draft",
            "content": "Private",
            "contacts_author": "private-contact",
        },
    )
    assert response.status_code == 200, response.text
    offer = response.json()
    assert offer["status_mod"] == "draft"
    path = f"/offers/offers/{offer['id']}"
    assert (await client.get(path)).status_code in {401, 403}
    assert (await client.get(path, headers=headers("other"))).status_code == 403
    assert (await client.get(path, headers=headers())).json()[
        "contacts_author"
    ] == "private-contact"
    assert (await client.get(path, headers=headers("council"))).status_code == 200
    assert (
        await client.get("/offers/admin/offers", headers=headers())
    ).status_code == 403
    assert (
        await client.get("/offers/admin/offers", headers=headers("council"))
    ).status_code == 200
    assert (
        await client.get("/offers/admin/offers?limit=-1", headers=headers("admin"))
    ).status_code == 422
    assert (
        await client.get(
            "/offers/offers/missing", params={"news_id": offer["id"]}, headers=headers()
        )
    ).status_code == 404
    assert (await client.delete(path, headers=headers("other"))).status_code == 403
    body = {
        "title": "Changed",
        "content": "Private",
        "contacts_author": "private-contact",
    }
    assert (
        await client.put(path, headers=headers("other"), json=body)
    ).status_code == 403
    assert (await client.put(path, headers=headers(), json=body)).status_code == 200
    assert (await client.delete(path, headers=headers())).status_code == 200


@pytest.mark.anyio
async def test_offer_approval_publishes_children_once_and_preserves_image(
    api, tmp_path, monkeypatch
):
    client, sessions, _ = api
    monkeypatch.chdir(tmp_path)
    picture = io.BytesIO()
    Image.new("RGB", (5, 5)).save(picture, format="PNG")
    body = event_body(
        has_topic=True,
        anon=True,
        contacts_author="private-contact",
        image=base64.b64encode(picture.getvalue()).decode(),
    )
    response = await client.post("/offers/offers", headers=headers(), json=body)
    assert response.status_code == 200, response.text
    offer = response.json()
    path = f"/offers/offers/{offer['id']}"
    assert (
        await client.patch(path + "/submit", headers=headers("other"))
    ).status_code == 403
    assert (await client.patch(path + "/submit", headers=headers())).status_code == 200
    moderation = f"/offers/admin/offers/{offer['id']}/moderate"
    decision = {"offer_id": offer["id"], "action": "approved"}
    assert (
        await client.patch(moderation, headers=headers(), json=decision)
    ).status_code == 403
    response = await client.patch(moderation, headers=headers("council"), json=decision)
    assert response.status_code == 200, response.text
    assert response.json()["status_mod"] == "approved"
    assert (
        await client.patch(moderation, headers=headers("council"), json=decision)
    ).status_code == 400
    async with sessions() as session:
        assert await session.scalar(select(func.count()).select_from(News)) == 1
        news = await session.scalar(select(News))
        event = await session.get(Events, news.event_id)
        assert event.event_start == "2026-11-10T10:00:00"
        assert event.status == "published"
        assert (await session.get(Topics, news.topic_id)).anon is True
        assert news.image_url == offer["image_url"]
    image_file = tmp_path / offer["image_url"].replace("/static/", "uploads/")
    assert image_file.exists()
    assert (await client.delete(path, headers=headers())).status_code == 200
    assert image_file.exists()


@pytest.mark.anyio
async def test_image_deletion_stays_inside_upload_directory(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    uploads = tmp_path / "uploads"
    uploads.mkdir()
    victim = tmp_path / "important.txt"
    victim.write_text("keep")
    for url in (str(victim), "/static/../important.txt", "/static/..\\important.txt"):
        await news_routes.delete_old_image(url)
        assert victim.read_text() == "keep"
    (uploads / "link").symlink_to(victim)
    await news_routes.delete_old_image("/static/link")
    assert victim.read_text() == "keep"
    image = uploads / "sample.webp"
    image.write_text("image")
    await news_routes.delete_old_image("/static/sample.webp")
    assert not image.exists()


@pytest.mark.anyio
async def test_classrooms_validate_dates_and_keep_requested_day(api, monkeypatch):
    client, _, _ = api
    recorded = []

    class FixedDateTime(datetime.datetime):
        @classmethod
        def now(cls):
            return cls(2026, 11, 9, 12)

    monkeypatch.setattr(classrooms_routes, "datetime", FixedDateTime)

    async def classrooms(self, **kwargs):
        recorded.append(kwargs)
        return ["Room 1"]

    monkeypatch.setattr(classrooms_routes.Schedule, "get_free_classrooms", classrooms)
    for query in ("date=invalid", "start_time=25:00", "end_time=10:90"):
        assert (await client.get("/classrooms/free?" + query)).status_code == 422
    assert not recorded
    response = await client.get(
        "/classrooms/free?date=2026-11-10&start_time=10:00&end_time=11:00"
    )
    assert response.status_code == 200, response.text
    assert recorded[-1]["start_date"] == datetime.datetime(2026, 11, 10, 10)
    response = await client.get("/classrooms/free?date=2026-11-10")
    assert response.status_code == 200
    assert recorded[-1]["start_date"].date() == datetime.date(2026, 11, 10)
    assert (
        await client.get("/classrooms/free?start_time=11:00&end_time=10:00")
    ).status_code == 400


@pytest.mark.anyio
async def test_rejected_image_update_does_not_delete_existing_file(
    api, tmp_path, monkeypatch
):
    client, sessions, _ = api
    monkeypatch.chdir(tmp_path)
    path = tmp_path / "uploads" / "existing.webp"
    path.parent.mkdir()
    path.write_text("existing")
    async with sessions() as session:
        item = News(
            title="News",
            content="Body",
            author_id="council",
            image_url="/static/existing.webp",
        )
        session.add(item)
        await session.commit()
        news_id = item.id
    response = await client.put(
        f"/news/{news_id}", headers=headers("council"), json={"image": "bad image"}
    )
    assert response.status_code == 400
    assert path.read_text() == "existing"
    async with sessions() as session:
        assert (await session.get(News, news_id)).image_url == "/static/existing.webp"


@pytest.mark.anyio
async def test_comments_ownership_and_anonymous_reply_does_not_expose_ids(api):
    client, sessions, _ = api
    response = await client.post(
        "/forum/topics",
        headers=headers("council"),
        json={"title": "Anonymous forum", "anon": True},
    )
    assert response.status_code == 200, response.text
    topic_id = response.json()["topic_id"]
    first = await client.post(
        "/topic/comments",
        headers=headers(),
        json={"topic_id": topic_id, "content": "First comment"},
    )
    assert first.status_code == 200, first.text
    comment_id = first.json()["comment_id"]
    second = await client.post(
        "/topic/comments",
        headers=headers("other"),
        json={
            "topic_id": topic_id,
            "content": "Reply comment",
            "parent_comment_id": comment_id,
        },
    )
    assert second.status_code == 200, second.text
    for item in (first.json(), second.json()):
        assert item["author"] == "anon"
        assert item["reply_to_author"] is None
    assert (
        await client.patch(
            f"/topic/comments/{comment_id}",
            headers=headers("other"),
            json={"content": "Stolen edit"},
        )
    ).status_code == 403
    assert (
        await client.delete(f"/topic/comments/{comment_id}", headers=headers("other"))
    ).status_code == 403
    comments = await client.get(
        f"/topic/comments?topic_id={topic_id}", headers=headers()
    )
    assert comments.status_code == 200
    assert all(
        item["author"] == "anon" and item["reply_to_author"] is None
        for item in comments.json()
    )
    public = await client.get("/profile/user/student", headers=headers("other"))
    assert public.status_code == 200
    assert "email" not in public.json()


def test_migrations_upgrade_downgrade_and_upgrade(tmp_path):
    import os
    import sqlite3
    import subprocess
    import sys

    backend = Path(__file__).resolve().parents[1]
    db = tmp_path / "migration.db"
    environment = {**os.environ, "DATABASE_URL": f"sqlite+aiosqlite:///{db}"}
    for arguments in (("upgrade", "head"), ("downgrade", "base"), ("upgrade", "head")):
        result = subprocess.run(
            [
                sys.executable,
                "-m",
                "alembic",
                "-c",
                str(backend / "alembic.ini"),
                *arguments,
            ],
            cwd=backend,
            env=environment,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, result.stdout + result.stderr
    with sqlite3.connect(db) as connection:
        registration_columns = connection.execute(
            "PRAGMA table_info(registrations)"
        ).fetchall()
        assert next(row[2] for row in registration_columns if row[1] == "comment") == (
            "VARCHAR(50)"
        )
        assert Registrations.__table__.c.comment.type.length == 50
        for table, column, expected in (
            ("topics", "title", "VARCHAR(60)"),
            ("offertopics", "title", "VARCHAR(60)"),
            ("comments", "content", "VARCHAR(1024)"),
            ("users", "messenger_handle", "VARCHAR(32)"),
        ):
            columns = connection.execute(f"PRAGMA table_info({table})").fetchall()
            assert next(row[2] for row in columns if row[1] == column) == expected
        assert connection.execute(
            "SELECT version_num FROM alembic_version"
        ).fetchone() == ("821a1b366db6",)
        assert (
            len(connection.execute("PRAGMA foreign_key_list(comments)").fetchall()) == 3
        )


@pytest.mark.anyio
async def test_classroom_availability_uses_actual_overlap_and_requested_week(
    monkeypatch,
):
    from schedule import classrooms_parser

    class FixedDateTime(datetime.datetime):
        @classmethod
        def now(cls):
            return cls(2026, 11, 9, 12)

    monkeypatch.setattr(classrooms_parser, "datetime", FixedDateTime)
    schedule = classrooms_parser.Schedule()
    schedule._Schedule__classrooms = ["occupied", "empty"]
    schedule._Schedule__all_classrooms = {
        "occupied": "Room occupied",
        "empty": "Room empty",
    }
    calls = []

    async def update():
        pass

    async def classroom(number, **kwargs):
        calls.append(kwargs)
        if number == "empty":
            return number
        result = {index: [] for index in range(7)}
        result.update(
            {
                "classroom": number,
                0: [{"numberPair": 99, "startTime": "10:00", "endTime": "12:00"}],
            }
        )
        return result

    monkeypatch.setattr(schedule, "update_classroom_list", update)
    monkeypatch.setattr(schedule, "classroom", classroom)
    free = await schedule.get_free_classrooms(
        start_date=FixedDateTime(2026, 11, 23, 11),
        end_date=FixedDateTime(2026, 11, 23, 13),
    )
    assert free == ["Room empty"]
    assert all(call["week_offset"] == 2 for call in calls)
    free = await schedule.get_free_classrooms(
        start_date=FixedDateTime(2026, 11, 2, 12),
        end_date=FixedDateTime(2026, 11, 2, 13),
    )
    assert free == ["Room empty", "Room occupied"]
    assert all(call["week_offset"] == -1 for call in calls[-2:])


def test_production_app_starts_and_builds_openapi_without_cloud_calls(tmp_path):
    import os
    import subprocess
    import sys

    backend = Path(__file__).resolve().parents[1]
    environment = {
        **os.environ,
        "PYTHONPATH": str(backend),
        "DATABASE_URL": f"sqlite+aiosqlite:///{tmp_path / 'startup.db'}",
    }
    code = """
from fastapi.testclient import TestClient
import main
with TestClient(main.app) as client:
    response = client.get('/openapi.json')
    assert response.status_code == 200
    schema = response.json()
    body = schema['paths']['/news/events/{event_id}/register']['post']['requestBody']
    form = body['content']['application/x-www-form-urlencoded']['schema']
    form_name = form['$ref'].split('/')[-1]
    comment = schema['components']['schemas'][form_name]['properties']['comment']
    assert {'type': 'string', 'maxLength': 50} in comment['anyOf']
    assert {'type': 'null'} in comment['anyOf']
    models = schema['components']['schemas']
    for name, field, minimum, maximum in (
        ('CreateTopicRequest', 'title', 1, 60),
        ('CreateCommentRequest', 'content', 1, 1024),
        ('UpdateCommentRequest', 'content', 1, 1024),
    ):
        prop = models[name]['properties'][field]
        assert (prop['minLength'], prop['maxLength']) == (minimum, maximum)
    for name in ('NewsCreateRequest', 'OfferNewsEventsRequest'):
        assert models[name]['properties']['title']['maxLength'] == 60
    assert {'type': 'string', 'maxLength': 60} in models['NewsUpdateRequest']['properties']['title']['anyOf']
    for name in ('NewsCreateRequest', 'NewsUpdateRequest', 'OfferNewsEventsRequest'):
        assert {'type': 'integer', 'maximum': 2147483647} in models[name]['properties']['max_partic']['anyOf']
    assert client.get('/news/').status_code in (401, 403)
    assert client.post('/auth/test-make-me-council').status_code == 404
"""
    result = subprocess.run(
        [sys.executable, "-c", code],
        cwd=tmp_path,
        env=environment,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_database_url_escapes_credentials_and_honors_explicit_url(tmp_path):
    import os
    import subprocess
    import sys

    backend = Path(__file__).resolve().parents[1]
    environment = {
        **os.environ,
        "PYTHONPATH": str(backend),
        "DATABASE_URL": "",
        "DB_USER": "user@name",
        "DB_PASSWORD": "test-only@:/%pass",
        "DB_NAME": "test-db",
        "DB_HOST": "localhost",
        "DB_PORT": "6543",
    }
    code = """
from database.database import engine
assert engine.url.username == 'user@name'
assert engine.url.password == 'test-only@:/%pass'
assert engine.url.port == 6543
assert not engine.echo
"""
    result = subprocess.run(
        [sys.executable, "-c", code],
        cwd=tmp_path,
        env=environment,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout == ""
    environment["DATABASE_URL"] = "sqlite+aiosqlite:///:memory:"
    result = subprocess.run(
        [
            sys.executable,
            "-c",
            "from database.database import engine; assert engine.url.drivername == 'sqlite+aiosqlite'",
        ],
        cwd=tmp_path,
        env=environment,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout == ""


@pytest.mark.anyio
@pytest.mark.parametrize(
    "start,end,expected_start,expected_end",
    [
        ("10.10.2026", "11.10.2026", "2026-10-10T00:00:00", "2026-10-11T00:00:00"),
        ("31.12.2026", "01.01.2027", "2026-12-31T00:00:00", "2027-01-01T00:00:00"),
        (
            "2026-11-10T10:00:00+03:00",
            "2026-11-10T12:00:00+03:00",
            "2026-11-10T10:00:00+03:00",
            "2026-11-10T12:00:00+03:00",
        ),
    ],
)
async def test_event_details_normalize_stored_legacy_dates(
    api, start, end, expected_start, expected_end
):
    client, sessions, _ = api
    created = await client.post("/news/", headers=headers("council"), json=event_body())
    assert created.status_code == 200, created.text
    event_id = created.json()["event_id"]
    async with sessions() as session:
        event = await session.get(Events, event_id)
        event.event_start = start
        event.event_end = end
        await session.commit()
    response = await client.get(f"/news/events/{event_id}")
    assert response.status_code == 200, response.text
    assert response.json()["event_start"] == expected_start
    assert response.json()["event_end"] == expected_end
    updated = await client.put(
        f"/news/{created.json()['id']}",
        headers=headers("council"),
        json={"has_event": True, "location": "Room 2"},
    )
    assert updated.status_code == 200, updated.text
    async with sessions() as session:
        event = await session.get(Events, event_id)
        assert event.event_start == start
        assert event.event_end == end
        assert event.location == "Room 2"


def test_event_response_rejects_invalid_legacy_dates():
    from pydantic import ValidationError
    from news.schemas import EventResponse

    with pytest.raises(ValidationError):
        EventResponse.model_validate(
            {
                "id": "event",
                "status": "published",
                "news_id": "news",
                "event_start": "31.02.2026",
                "event_end": "01.03.2026",
                "location": "Room 1",
                "max_partic": 1,
                "cur_partic": 0,
                "is_reg_open": True,
            }
        )
