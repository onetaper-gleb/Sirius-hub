import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth.auth_routes import get_current_user, require_admin_role, require_council_role
from database.database import get_db
from database.models import (
    Events,
    ModerationStatus,
    News,
    OfferEvent,
    OfferNews,
    OfferTopic,
    Topics,
)
from news.news_routes import (
    NotFound,
    delete_old_image,
    process_image,
    validate_event_data,
)

from .schemas import AdminModRequest, OfferNewsEventsRequest, OfferNewsResponse

router = APIRouter(prefix="/offers", tags=["Offers"])


async def get_offer_or_404(db: AsyncSession, offer_id: str, for_update=False):
    stmt = select(OfferNews).where(OfferNews.id == offer_id)
    if for_update:
        stmt = stmt.with_for_update()
    result = await db.execute(stmt)
    offer = result.scalar_one_or_none()
    if offer is None:
        raise NotFound(detail="Новость предложки не найдена")
    return offer


async def get_offer_event_or_404(db: AsyncSession, event_id: str, for_update=False):
    stmt = select(OfferEvent).where(OfferEvent.id == event_id)
    if for_update:
        stmt = stmt.with_for_update()
    result = await db.execute(stmt)
    event = result.scalar_one_or_none()
    if event is None:
        raise NotFound(detail="Событие предложки не найдено")
    return event


async def get_offer_topic_or_404(db: AsyncSession, topic_id: str, for_update=False):
    stmt = select(OfferTopic).where(OfferTopic.id == topic_id)
    if for_update:
        stmt = stmt.with_for_update()
    result = await db.execute(stmt)
    topic = result.scalar_one_or_none()
    if topic is None:
        raise NotFound(detail="Топик предложки не найден")
    return topic


async def update_offer(offer, request, db):
    if request.has_event:
        validate_event_data(request)
    old_image_url = None
    if request.image:
        new_image_url = await process_image(request.image)
        old_image_url = offer.image_url
        offer.image_url = new_image_url
    offer.title = request.title
    offer.content = request.content
    offer.contacts_author = request.contacts_author
    offer.has_event = request.has_event
    offer.has_topic = request.has_topic
    if request.has_event:
        if offer.event_id:
            event = await get_offer_event_or_404(db, offer.event_id, for_update=True)
        else:
            event = OfferEvent(news_id=offer.id, cur_partic=0)
            db.add(event)
        event.event_status = request.event_status
        event.event_start = request.event_start.isoformat()
        event.event_end = request.event_end.isoformat()
        event.location = request.location
        event.max_partic = request.max_partic
        event.is_reg_open = request.is_reg_open
        await db.flush()
        offer.event_id = event.id
    elif offer.event_id:
        event = await get_offer_event_or_404(db, offer.event_id, for_update=True)
        await db.delete(event)
        offer.event_id = None
    if request.has_topic:
        if offer.topic_id:
            topic = await get_offer_topic_or_404(db, offer.topic_id, for_update=True)
        else:
            topic = OfferTopic(news_id=offer.id)
            db.add(topic)
        topic.title = request.title
        topic.anon = request.anon
        await db.flush()
        offer.topic_id = topic.id
    elif offer.topic_id:
        topic = await get_offer_topic_or_404(db, offer.topic_id, for_update=True)
        await db.delete(topic)
        offer.topic_id = None
    return old_image_url


@router.post("/offers", response_model=OfferNewsResponse)
async def create_offer(
    request: OfferNewsEventsRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    offer = OfferNews(author_id=user["uid"], status_mod=ModerationStatus.draft.value)
    db.add(offer)
    offer.id = str(uuid.uuid4())
    await update_offer(offer, request, db)
    await db.commit()
    await db.refresh(offer)
    return offer


@router.get("/admin/offers", response_model=List[OfferNewsResponse])
async def get_all_offers(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(OfferNews)
        .order_by(OfferNews.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/offers/my", response_model=List[OfferNewsResponse])
async def get_my_offers(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(OfferNews)
        .where(OfferNews.author_id == user["uid"])
        .order_by(OfferNews.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/offers/{offer_id}", response_model=OfferNewsResponse)
async def get_offer(
    offer_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    offer = await get_offer_or_404(db, offer_id)
    if offer.author_id != user["uid"]:
        await require_council_role(user=user)
    return offer


@router.put("/admin/offers/{offer_id}", response_model=OfferNewsResponse)
async def update_offer_admin(
    offer_id: str,
    request: OfferNewsEventsRequest,
    user: dict = Depends(require_admin_role),
    db: AsyncSession = Depends(get_db),
):
    offer = await get_offer_or_404(db, offer_id, for_update=True)
    if offer.status_mod in {
        ModerationStatus.approved.value,
        ModerationStatus.published.value,
    }:
        raise HTTPException(400, "Опубликованную предложку нельзя редактировать")
    old_image_url = await update_offer(offer, request, db)
    await db.commit()
    await delete_old_image(old_image_url)
    await db.refresh(offer)
    return offer


@router.put("/offers/{offer_id}", response_model=OfferNewsResponse)
async def update_my_offer(
    offer_id: str,
    request: OfferNewsEventsRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    offer = await get_offer_or_404(db, offer_id, for_update=True)
    if offer.author_id != user["uid"]:
        raise HTTPException(403, "Нет прав на редактирование")
    if offer.status_mod not in {
        ModerationStatus.draft.value,
        ModerationStatus.revision.value,
    }:
        raise HTTPException(
            400, "Редактирование возможно только для черновика или доработки"
        )
    old_image_url = await update_offer(offer, request, db)
    await db.commit()
    await delete_old_image(old_image_url)
    await db.refresh(offer)
    return offer


@router.patch("/offers/{offer_id}/submit", response_model=OfferNewsResponse)
async def submit_for_moderation(
    offer_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    offer = await get_offer_or_404(db, offer_id, for_update=True)
    if offer.author_id != user["uid"]:
        raise HTTPException(403, "Нет прав на отправку")
    if offer.status_mod not in {
        ModerationStatus.draft.value,
        ModerationStatus.revision.value,
    }:
        raise HTTPException(
            400, "На модерацию можно отправить только черновик или доработку"
        )
    offer.status_mod = ModerationStatus.moderation.value
    offer.admin_id = None
    offer.comment_admin = None
    await db.commit()
    await db.refresh(offer)
    return offer


@router.patch("/admin/offers/{offer_id}/moderate", response_model=OfferNewsResponse)
async def moderate_offer(
    offer_id: str,
    request: AdminModRequest,
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    offer = await get_offer_or_404(db, offer_id, for_update=True)
    if offer.status_mod != ModerationStatus.moderation.value:
        raise HTTPException(400, "Модерация возможна только в статусе moderation")
    if request.action not in {
        ModerationStatus.approved,
        ModerationStatus.rejected,
        ModerationStatus.revision,
        ModerationStatus.archived,
    }:
        raise HTTPException(400, "Недопустимое действие модерации")
    if request.action == ModerationStatus.approved:
        news = News(
            title=offer.title,
            content=offer.content,
            image_url=offer.image_url,
            author_id=offer.author_id,
            has_event=offer.has_event,
            has_topic=offer.has_topic,
        )
        db.add(news)
        await db.flush()
        if offer.has_event:
            source = await get_offer_event_or_404(db, offer.event_id)
            event = Events(
                status=source.event_status,
                news_id=news.id,
                event_start=source.event_start,
                event_end=source.event_end,
                location=source.location,
                max_partic=source.max_partic,
                cur_partic=0,
                is_reg_open=source.is_reg_open,
            )
            db.add(event)
            await db.flush()
            news.event_id = event.id
        if offer.has_topic:
            source = await get_offer_topic_or_404(db, offer.topic_id)
            topic = Topics(title=source.title, anon=source.anon, news_id=news.id)
            db.add(topic)
            await db.flush()
            news.topic_id = topic.id
    offer.status_mod = request.action.value
    offer.admin_id = user["uid"]
    offer.comment_admin = request.comment_admin
    await db.commit()
    await db.refresh(offer)
    return offer


@router.delete("/offers/{offer_id}")
async def delete_offer(
    offer_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    offer = await get_offer_or_404(db, offer_id, for_update=True)
    if offer.author_id != user["uid"]:
        await require_admin_role(user=user)
    if offer.event_id:
        await db.delete(
            await get_offer_event_or_404(db, offer.event_id, for_update=True)
        )
    if offer.topic_id:
        await db.delete(
            await get_offer_topic_or_404(db, offer.topic_id, for_update=True)
        )
    image_url = offer.image_url
    shared_image = offer.status_mod in {
        ModerationStatus.approved.value,
        ModerationStatus.published.value,
    }
    await db.delete(offer)
    await db.commit()
    if not shared_image:
        await delete_old_image(image_url)
    return {"status": "success", "message": "Успешное удаление"}
