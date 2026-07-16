from fastapi import APIRouter
from typing import List, Optional
from .schemas import OfferEventResponse, OfferNewsResponse, OfferNewsEventsRequest, AdminModRequest
import io
import os
import uuid
from typing import List, Optional
import datetime

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from PIL import Image
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from auth.auth_routes import get_current_user, require_council_role
from database.database import get_db
from database.models import News, Events, OfferNews, OfferEvent, OfferTopic, EventStatus, ModerationStatus

from news.news_routes import process_image, delete_old_image, validate_event_data, NotFound


router = APIRouter(
    prefix="/offers",
    tags=["Offers"],
)

async def get_offer_or_404(db: AsyncSession, news_id: str):
    result = await db.execute(select(OfferNews).where(OfferNews.id == news_id))
    offer = result.scalar_one_or_none()
    if not offer:
        raise NotFound(status_code=404, detail="Новость не найдена")
    return offer

async def get_offer_event_or_404(db: AsyncSession, offer_event_id: str):
    result = await db.execute(select(OfferEvent).where(OfferEvent.id == offer_event_id))
    offer_event = result.scalar_one_or_none()
    if not offer_event:
        raise NotFound(status_code=404, detail="Событие предложки не найдено")
    return offer_event

async def get_offer_topic_or_404(db: AsyncSession, offer_topic_id: str):
    result = await db.execute(select(OfferTopic).where(OfferTopic.id == offer_topic_id))
    offer_topic = result.scalar_one_or_none()
    if not offer_topic:
        raise NotFound(status_code=404, detail="Топик предложки не найден")
    return offer_topic

@router.post("/offers", response_model=OfferNewsResponse)
async def create_offer(
    request: OfferNewsEventsRequest,
    image: UploadFile = File(None),
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    image_url = await process_image(image)

    new_offer = OfferNews(
        title=request.title,
        content=request.content,
        image_url=image_url,
        author_id=user.get("uid"),
        contacts_author=request.contacts_author,
        has_event=request.has_event,
        event_id=None,
        has_topic=request.has_topic,
        topic_id=None,
        status_mod=ModerationStatus.moderation.value,
        admin_id=None,
        comment_admin=None
    )

    db.add(new_offer)
    await db.flush()

    if request.has_event:
        await validate_event_data(request, db)
        new_event = OfferEvent(
            status=request.event_status,
            event_start=request.event_start,
            event_end=request.event_end,
            location=request.location,
            max_partic=request.max_partic,
            cur_partic=0,
            is_reg_open=request.is_reg_open,
            news_id=new_offer.id,
        )
        db.add(new_event)
        await db.flush()
        new_offer.event_id = new_event.id
        db.add(new_offer)

    if request.has_topic:
        new_topic = OfferTopic(
            title=request.title,
            anon=request.anon,
            news_id=new_offer.id
        )
        db.add(new_topic)
        await db.flush()
        new_offer.topic_id = new_topic.id
        db.add(new_offer)

    await db.commit()
    await db.refresh(new_offer)
    if request.has_event:
        await db.refresh(new_event)
    if request.has_topic:
        await db.refresh(new_topic)

    return new_offer

    
@router.get("/admin/offers", response_model=List[OfferNewsResponse])
async def get_all_offers(
    skip: int = 0,
    limit: int = 20,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(OfferNews).order_by(OfferNews.created_at.desc()).offset(skip).limit(limit)
    )
    offers_list = result.scalars().all()
    return offers_list

@router.get("/offers/my", response_model=List[OfferNewsResponse])
async def get_my_offers(
    skip: int = 0,
    limit: int = 20,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(OfferNews)
        .where(OfferNews.author_id == user.get("uid"))
        .order_by(OfferNews.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    offers_list = result.scalars().all()
    return offers_list

@router.get("/offers/{offer_id}", response_model=OfferNewsResponse)
async def get_offer(
    news_id: str,
    db: AsyncSession = Depends(get_db),
):
    return await get_offer_or_404(db, news_id)

@router.put("/admin/offers/{offer_id}", response_model=OfferNewsResponse)
async def update_offer():
    pass

@router.put("/offers/{offer_id}", response_model=OfferNewsResponse) # draft only
async def update_my_offer():
    pass

@router.patch("/offers/{offer_id}/submit", response_model=OfferNewsResponse)
async def submit_for_moderation():
    pass

@router.patch("/admin/offers/{offer_id}/moderate", response_model=OfferNewsResponse)
async def moderate_offer():
    pass

@router.delete("/offers/{offer_id}")
async def delete_offer(
    news_id: str,
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    news_item = await get_offer_or_404(db, news_id)
    role = user.get("role", "student")

    if news_item.author_id != user.get("uid") and role in ["student", "council"]:
        raise HTTPException(status_code=403, detail="Нет прав на удаление")

    try:
        if news_item.image_url:
            await delete_old_image(news_item.image_url)
        offer_event = await get_offer_event_or_404(db, news_item.event_id)
        offer_topic = await get_offer_topic_or_404(db, news_item.topic_id)
        if offer_event:
            await db.delete(offer_event)
        if offer_topic:
            await db.delete(offer_topic)

        await db.delete(news_item)
        await db.commit()
        return {"status": "success", "message": "Успешное удаление"}

    except NotFound as e:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при удалении: {str(e)}")

