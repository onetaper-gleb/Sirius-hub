import pytest
from sqlalchemy import func, select
from test_api_regressions import anyio_backend, api, headers

from database.models import Comments, Events, News, OfferNews, OfferTopic, Topics, User


@pytest.mark.anyio
@pytest.mark.parametrize(
    "raw,expected",
    [
        ("x" * 32, "x" * 32),
        ("@" + "x" * 32, "x" * 32),
        ("  tg/ @" + "😀" * 32 + "  ", "😀" * 32),
        ("tg/" + "e\u0301" * 16, "e\u0301" * 16),
        ("  ", None),
        ("tg/ @", None),
        ("", None),
        (None, None),
    ],
)
async def test_profile_normalizes_handle_before_length_validation(api, raw, expected):
    client, sessions, _ = api
    response = await client.put(
        "/profile/update", headers=headers(), json={"messenger_handle": raw}
    )
    assert response.status_code == 200, response.text
    assert response.json()["messenger_handle"] == expected
    async with sessions() as session:
        assert (await session.get(User, "student")).messenger_handle == expected


@pytest.mark.anyio
@pytest.mark.parametrize(
    "raw", ["x" * 33, "@" + "😀" * 33, "tg/" + "e\u0301" * 17, 123, [], {}, True]
)
async def test_profile_rejects_invalid_handle_without_partial_update(api, raw):
    client, sessions, _ = api
    response = await client.put(
        "/profile/update",
        headers=headers(),
        json={"display_name": "Changed", "messenger_handle": raw},
    )
    assert response.status_code == 422, response.text
    async with sessions() as session:
        user = await session.get(User, "student")
        assert user.display_name is None
        assert user.messenger_handle is None


@pytest.mark.anyio
@pytest.mark.parametrize("title", ["a", "a" * 60, "😀" * 60, "e\u0301" * 30])
async def test_forum_accepts_inclusive_normalized_title_bounds(api, title):
    client, _, _ = api
    for role in ("council", "admin"):
        response = await client.post(
            "/forum/topics", headers=headers(role), json={"title": " " + title + " "}
        )
        assert response.status_code == 200, response.text
        assert response.json()["title"] == title
    assert (
        await client.post("/forum/topics", headers=headers(), json={"title": title})
    ).status_code == 403


@pytest.mark.anyio
@pytest.mark.parametrize("title", ["", "  ", "a" * 61, "😀" * 61, "e\u0301" * 31])
async def test_forum_rejects_invalid_title_without_insert(api, title):
    client, sessions, _ = api
    response = await client.post(
        "/forum/topics", headers=headers("council"), json={"title": title}
    )
    assert response.status_code == 422, response.text
    async with sessions() as session:
        assert await session.scalar(select(func.count(Topics.id))) == 0


@pytest.mark.anyio
@pytest.mark.parametrize("content", ["a", "a" * 1024, "😀" * 1024, "e\u0301" * 512])
async def test_forum_create_and_patch_accept_bounds_with_ownership(api, content):
    client, sessions, _ = api
    topic = await client.post(
        "/forum/topics", headers=headers("council"), json={"title": "a"}
    )
    response = await client.post(
        "/topic/comments",
        headers=headers(),
        json={"topic_id": topic.json()["topic_id"], "content": " " + content + " "},
    )
    assert response.status_code == 200, response.text
    comment_id = response.json()["comment_id"]
    assert response.json()["content"] == content
    for role in ("other", "council", "admin"):
        assert (
            await client.patch(
                f"/topic/comments/{comment_id}",
                headers=headers(role),
                json={"content": content},
            )
        ).status_code == 403
    response = await client.patch(
        f"/topic/comments/{comment_id}",
        headers=headers(),
        json={"content": " " + content + " "},
    )
    assert response.status_code == 200, response.text
    async with sessions() as session:
        assert (await session.get(Comments, comment_id)).content == content


@pytest.mark.anyio
@pytest.mark.parametrize(
    "content", ["", "  ", "a" * 1025, "😀" * 1025, "e\u0301" * 513]
)
async def test_forum_rejects_invalid_comment_create_and_patch(api, content):
    client, sessions, _ = api
    topic = await client.post(
        "/forum/topics", headers=headers("council"), json={"title": "a"}
    )
    body = {"topic_id": topic.json()["topic_id"], "content": "a"}
    comment = await client.post("/topic/comments", headers=headers(), json=body)
    comment_id = comment.json()["comment_id"]
    assert (
        await client.post(
            "/topic/comments", headers=headers(), json={**body, "content": content}
        )
    ).status_code == 422
    assert (
        await client.patch(
            f"/topic/comments/{comment_id}",
            headers=headers(),
            json={"content": content},
        )
    ).status_code == 422
    async with sessions() as session:
        assert await session.scalar(select(func.count(Comments.id))) == 1
        assert (await session.get(Comments, comment_id)).content == "a"


@pytest.mark.anyio
@pytest.mark.parametrize("title", ["a" * 60, "😀" * 60, "e\u0301" * 30])
async def test_news_offer_title_boundary_create_update_and_approval(api, title):
    client, sessions, _ = api
    body = {"title": title, "content": "Body", "has_topic": True}
    response = await client.post("/news/", headers=headers("council"), json=body)
    assert response.status_code == 200, response.text
    news_id = response.json()["id"]
    response = await client.put(
        f"/news/{news_id}", headers=headers("council"), json={"title": title[::-1]}
    )
    assert response.status_code == 200, response.text
    async with sessions() as session:
        news = await session.get(News, news_id)
        assert (await session.get(Topics, news.topic_id)).title == title[::-1]
    response = await client.post(
        "/offers/offers", headers=headers(), json={**body, "contacts_author": "contact"}
    )
    assert response.status_code == 200, response.text
    offer_id = response.json()["id"]
    for path, role in (
        (f"/offers/offers/{offer_id}", "student"),
        (f"/offers/admin/offers/{offer_id}", "admin"),
    ):
        response = await client.put(
            path, headers=headers(role), json={**body, "contacts_author": "contact"}
        )
        assert response.status_code == 200, response.text
    assert (
        await client.patch(f"/offers/offers/{offer_id}/submit", headers=headers())
    ).status_code == 200
    response = await client.patch(
        f"/offers/admin/offers/{offer_id}/moderate",
        headers=headers("council"),
        json={"offer_id": offer_id, "action": "approved"},
    )
    assert response.status_code == 200, response.text
    async with sessions() as session:
        published = await session.scalar(
            select(News).where(News.author_id == "student")
        )
        assert (await session.get(Topics, published.topic_id)).title == title


@pytest.mark.anyio
@pytest.mark.parametrize("title", ["a" * 61, "😀" * 61, "e\u0301" * 31])
@pytest.mark.parametrize("has_topic", [False, True])
async def test_news_offer_reject_long_submitted_title_before_writes_or_images(
    api, monkeypatch, title, has_topic
):
    client, sessions, _ = api

    async def no_image_processing(_):
        pytest.fail("Title validation must precede image processing")

    monkeypatch.setattr("news.news_routes.process_image", no_image_processing)
    monkeypatch.setattr("newsoffers.offers_routes.process_image", no_image_processing)
    good = {"title": "Original", "content": "Body", "has_topic": has_topic}
    async with sessions() as session:
        news = News(
            title="Original",
            content="Body",
            author_id="council",
            image_url="/static/old.webp",
        )
        offer = OfferNews(
            title="Original",
            content="Body",
            author_id="student",
            contacts_author="contact",
            image_url="/static/old.webp",
        )
        session.add_all([news, offer])
        await session.commit()
        news_id, offer_id = news.id, offer.id
    invalid = {**good, "title": title, "image": "invalid-image"}
    for method, path, role, body in (
        ("post", "/news/", "council", invalid),
        ("put", f"/news/{news_id}", "council", invalid),
        (
            "post",
            "/offers/offers",
            "student",
            {**invalid, "contacts_author": "contact"},
        ),
        (
            "put",
            f"/offers/offers/{offer_id}",
            "student",
            {**invalid, "contacts_author": "contact"},
        ),
        (
            "put",
            f"/offers/admin/offers/{offer_id}",
            "admin",
            {**invalid, "contacts_author": "contact"},
        ),
    ):
        response = await getattr(client, method)(path, headers=headers(role), json=body)
        assert response.status_code == 422, response.text
    async with sessions() as session:
        for model in (News, OfferNews):
            assert await session.scalar(select(func.count(model.id))) == 1
            item = await session.scalar(select(model))
            assert (item.title, item.image_url) == ("Original", "/static/old.webp")
        for model in (Topics, OfferTopic, Events):
            assert await session.scalar(select(func.count(model.id))) == 0


@pytest.mark.anyio
@pytest.mark.parametrize("existing_topic", [False, True])
async def test_news_update_validates_effective_legacy_title_before_any_changes(
    api, monkeypatch, existing_topic
):
    client, sessions, _ = api
    async with sessions() as session:
        news = News(
            title="x" * 61,
            content="Original",
            author_id="council",
            has_topic=existing_topic,
            image_url="/static/old.webp",
        )
        session.add(news)
        await session.flush()
        if existing_topic:
            topic = Topics(title="old", news_id=news.id)
            session.add(topic)
            await session.flush()
            news.topic_id = topic.id
        await session.commit()
        news_id = news.id

    async def no_image_processing(_):
        pytest.fail("Effective title must be validated before image processing")

    monkeypatch.setattr("news.news_routes.process_image", no_image_processing)
    body = {"has_topic": True, "content": "Changed", "image": "invalid-image"}
    if existing_topic:
        body.pop("has_topic")
    response = await client.put(
        f"/news/{news_id}", headers=headers("council"), json=body
    )
    assert response.status_code == 400, response.text
    async with sessions() as session:
        news = await session.get(News, news_id)
        assert (news.content, news.has_topic, news.image_url) == (
            "Original",
            existing_topic,
            "/static/old.webp",
        )
        assert await session.scalar(select(func.count(Topics.id))) == int(
            existing_topic
        )
    response = await client.put(
        f"/news/{news_id}",
        headers=headers("council"),
        json={"has_topic": True, "title": "x" * 60},
    )
    assert response.status_code == 200, response.text
    response = await client.put(
        f"/news/{news_id}", headers=headers("council"), json={"has_topic": False}
    )
    assert response.status_code == 200, response.text
    async with sessions() as session:
        assert await session.scalar(select(func.count(Topics.id))) == 0


@pytest.mark.anyio
@pytest.mark.parametrize("bad_source", ["offer", "topic"])
async def test_approval_rejects_legacy_long_title_without_partial_publication(
    api, bad_source
):
    client, sessions, _ = api
    async with sessions() as session:
        offer = OfferNews(
            title="x" * (61 if bad_source == "offer" else 60),
            content="Body",
            author_id="student",
            contacts_author="contact",
            has_topic=True,
            status_mod="moderation",
            image_url="/static/old.webp",
        )
        session.add(offer)
        await session.flush()
        topic = OfferTopic(
            title="x" * (61 if bad_source == "topic" else 60), news_id=offer.id
        )
        session.add(topic)
        await session.flush()
        offer.topic_id = topic.id
        await session.commit()
        offer_id = offer.id
    path = f"/offers/admin/offers/{offer_id}/moderate"
    decision = {"offer_id": offer_id, "action": "approved", "comment_admin": "Changed"}
    assert (
        await client.patch(path, headers=headers(), json=decision)
    ).status_code == 403
    response = await client.patch(path, headers=headers("council"), json=decision)
    assert response.status_code == 400, response.text
    async with sessions() as session:
        offer = await session.get(OfferNews, offer_id)
        assert (
            offer.status_mod,
            offer.admin_id,
            offer.comment_admin,
            offer.image_url,
        ) == ("moderation", None, None, "/static/old.webp")
        for model in (News, Topics, Events):
            assert await session.scalar(select(func.count(model.id))) == 0
        assert await session.scalar(select(func.count(OfferTopic.id))) == 1


@pytest.mark.anyio
@pytest.mark.parametrize("capacity", [1, 2147483647])
async def test_capacity_storage_bounds_across_news_and_offer_writes(api, capacity):
    from test_api_regressions import event_body

    from database.models import OfferEvent

    client, sessions, _ = api
    body = event_body(max_partic=capacity)
    news = await client.post("/news/", headers=headers("council"), json=body)
    assert news.status_code == 200, news.text
    news_id = news.json()["id"]
    response = await client.put(
        f"/news/{news_id}", headers=headers("council"), json=body
    )
    assert response.status_code == 200, response.text
    offer_body = {**body, "contacts_author": "contact"}
    offer = await client.post("/offers/offers", headers=headers(), json=offer_body)
    assert offer.status_code == 200, offer.text
    offer_id = offer.json()["id"]
    for path, role in (
        (f"/offers/offers/{offer_id}", "student"),
        (f"/offers/admin/offers/{offer_id}", "admin"),
    ):
        response = await client.put(path, headers=headers(role), json=offer_body)
        assert response.status_code == 200, response.text
    async with sessions() as session:
        assert (await session.scalar(select(Events))).max_partic == capacity
        assert (await session.scalar(select(OfferEvent))).max_partic == capacity
    assert (
        await client.patch(f"/offers/offers/{offer_id}/submit", headers=headers())
    ).status_code == 200
    response = await client.patch(
        f"/offers/admin/offers/{offer_id}/moderate",
        headers=headers("council"),
        json={"offer_id": offer_id, "action": "approved"},
    )
    assert response.status_code == 200, response.text
    async with sessions() as session:
        assert all(
            event.max_partic == capacity
            for event in (await session.scalars(select(Events))).all()
        )


@pytest.mark.anyio
async def test_capacity_overflow_rejected_before_images_or_changes(api, monkeypatch):
    from test_api_regressions import event_body

    from database.models import OfferEvent

    client, sessions, _ = api
    news = await client.post("/news/", headers=headers("council"), json=event_body())
    offer = await client.post(
        "/offers/offers",
        headers=headers(),
        json={**event_body(), "contacts_author": "contact"},
    )
    assert news.status_code == offer.status_code == 200
    news_id, offer_id = news.json()["id"], offer.json()["id"]

    async def no_image_processing(_):
        pytest.fail("Capacity validation must precede image processing")

    monkeypatch.setattr("news.news_routes.process_image", no_image_processing)
    monkeypatch.setattr("newsoffers.offers_routes.process_image", no_image_processing)
    body = event_body(max_partic=2147483648, title="Changed", image="invalid")
    for method, path, role, payload in (
        ("post", "/news/", "council", body),
        ("put", f"/news/{news_id}", "council", body),
        ("post", "/offers/offers", "student", {**body, "contacts_author": "contact"}),
        (
            "put",
            f"/offers/offers/{offer_id}",
            "student",
            {**body, "contacts_author": "contact"},
        ),
        (
            "put",
            f"/offers/admin/offers/{offer_id}",
            "admin",
            {**body, "contacts_author": "contact"},
        ),
    ):
        response = await getattr(client, method)(
            path, headers=headers(role), json=payload
        )
        assert response.status_code == 422, response.text
        assert response.json()["detail"][0]["loc"] == ["body", "max_partic"]
    async with sessions() as session:
        for model in (News, OfferNews):
            assert await session.scalar(select(func.count(model.id))) == 1
            assert (await session.scalar(select(model))).title == "News title"
        for model in (Events, OfferEvent):
            assert await session.scalar(select(func.count(model.id))) == 1
            assert (await session.scalar(select(model))).max_partic == 1


@pytest.mark.anyio
async def test_legacy_offer_capacity_rejected_before_publication(api):
    from test_api_regressions import event_body

    from database.models import OfferEvent

    client, sessions, _ = api
    response = await client.post(
        "/offers/offers",
        headers=headers(),
        json={**event_body(), "contacts_author": "contact"},
    )
    assert response.status_code == 200, response.text
    offer_id = response.json()["id"]
    assert (
        await client.patch(f"/offers/offers/{offer_id}/submit", headers=headers())
    ).status_code == 200
    async with sessions() as session:
        offer = await session.get(OfferNews, offer_id)
        event = await session.get(OfferEvent, offer.event_id)
        event.max_partic = 2147483648
        await session.commit()
    response = await client.patch(
        f"/offers/admin/offers/{offer_id}/moderate",
        headers=headers("council"),
        json={"offer_id": offer_id, "action": "approved", "comment_admin": "Changed"},
    )
    assert response.status_code == 400, response.text
    async with sessions() as session:
        offer = await session.get(OfferNews, offer_id)
        assert (offer.status_mod, offer.admin_id, offer.comment_admin) == (
            "moderation",
            None,
            None,
        )
        for model in (News, Events, Topics):
            assert await session.scalar(select(func.count(model.id))) == 0


@pytest.mark.anyio
@pytest.mark.parametrize("capacity", [0, -1])
async def test_capacity_lower_bound_still_rejected(api, capacity):
    from test_api_regressions import event_body

    client, _, _ = api
    for path, role, body in (
        ("/news/", "council", event_body(max_partic=capacity)),
        (
            "/offers/offers",
            "student",
            {**event_body(max_partic=capacity), "contacts_author": "contact"},
        ),
    ):
        response = await client.post(path, headers=headers(role), json=body)
        assert response.status_code == 400, response.text
