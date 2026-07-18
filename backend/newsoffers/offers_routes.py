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

from auth.auth_routes import get_current_user, require_role
from database.database import get_db
from database.models import News, Events, OfferNews, OfferEvent, OfferTopic, EventStatus, ModerationStatus

from news.news_routes import process_image, delete_old_image, validate_event_data, validate_event_status, NotFound, create_news


router = APIRouter(
    prefix="/offers",
    tags=["Offers"],
)

async def update_offer(
    offer: OfferNews,
    request: OfferNewsEventsRequest,
    image: UploadFile = File(None),
    db: AsyncSession = None
):
    if image:
        await delete_old_image(offer.image_url)
        offer.image_url = await process_image(image)

    if request.title is not None:
        offer.title = request.title
    if request.content is not None:
        offer.content = request.content
    if request.contacts_author is not None:
        offer.contacts_author = request.contacts_author
    if request.has_event is not None:
        offer.has_event = request.has_event
    if request.has_topic is not None:
        offer.has_topic = request.has_topic
        
    if request.has_event:
        if offer.event_id:
            offer_event = await get_offer_event_or_404(db, offer.event_id)
            if request.event_status is not None:
                validate_event_status(request.event_status)
                offer_event.status = request.event_status
            if request.event_start is not None:
                offer_event.event_start = request.event_start
            if request.event_end is not None:
                offer_event.event_end = request.event_end
            if request.location is not None:
                offer_event.location = request.location
            if request.max_partic is not None:
                if request.max_partic < 1:
                    await db.rollback()
                    raise HTTPException(400, "max_partic должно быть больше 0")
                offer_event.max_partic = request.max_partic
            if request.is_reg_open is not None:
                offer_event.is_reg_open = request.is_reg_open

        else:
            await validate_event_data(request, db)

            new_event = OfferEvent(
                status=request.event_status,
                event_start=request.event_start,
                event_end=request.event_end,
                location=request.location,
                max_partic=request.max_partic,
                cur_partic=0,
                is_reg_open=request.is_reg_open or False,
                news_id=offer.id,
            )
            db.add(new_event)
            await db.flush()
            offer.event_id = new_event.id

    elif request.has_event is False and offer.event_id:
        offer_event = await get_offer_event_or_404(db, offer.event_id)
        if offer_event:
            await db.delete(offer_event)
            offer.event_id = None


    if request.has_topic:
        if offer.topic_id:
            offer_topic = await get_offer_topic_or_404(db, offer.topic_id)
            if request.title is not None:
                offer_topic.title = request.title
            if request.anon is not None:
                offer_topic.anon = request.anon

        else:
            new_topic = OfferTopic(
                title=request.title,
                anon=request.anon,
                news_id=offer.id,
            )
            db.add(new_topic)
            await db.flush()
            offer.topic_id = new_topic.id

    elif request.has_topic is False and offer.topic_id:
        offer_topic = await get_offer_topic_or_404(db, offer.topic_id)
        await db.delete(offer_topic)
        offer.topic_id = None
        

async def get_offer_or_404(db: AsyncSession, news_id: str):
    result = await db.execute(select(OfferNews).where(OfferNews.id == news_id))
    offer = result.scalar_one_or_none()
    if not offer:
        raise NotFound(status_code=404, detail="Новость предложки не найдена")
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
    user: dict = Depends(require_role),
    db: AsyncSession = Depends(get_db),
):
    image_url = await process_image(image)
    if not request.contacts_author:
        raise HTTPException(
            status_code=400, 
            detail="Контакты автора не могут быть пустыми"
        )
    
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
async def update_offer(
    news_id: str,
    request: OfferNewsEventsRequest,
    image: UploadFile = File(None),
    user: dict = Depends(require_role),
    db: AsyncSession = Depends(get_db),

):
    offer = await get_offer_or_404(db, news_id)
    role = user.get("role", "student")
    aid = user.get("uid")

    if role in ["student", "council"]: 
        raise HTTPException(status_code=403, detail="Нет прав на редактирование")
    
    await update_offer(offer, request, image, db)

    await db.commit()
    await db.refresh(offer)

    return offer

@router.put("/offers/{offer_id}", response_model=OfferNewsResponse) # draft only
async def update_my_offer(
    news_id: str,
    request: OfferNewsEventsRequest,
    image: UploadFile = File(None),
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    offer = await get_offer_or_404(db, news_id)

    if offer.author_id != user.get("uid"):
        raise HTTPException(status_code=403, detail="Нет прав на редактирование")
    
    if offer.status_mod != ModerationStatus.draft.value:
        raise HTTPException(
            status_code=400, 
            detail="Редактирование возможно только в статусе 'черновик'"
        )
    
    await update_offer(offer, request, image, db)

    await db.commit()
    await db.refresh(offer)
    return offer


@router.patch("/offers/{offer_id}/submit", response_model=OfferNewsResponse)
async def submit_for_moderation(
    news_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    offer = await get_offer_or_404(db, news_id)
    if offer.author_id != user.get("uid"):
        raise HTTPException(status_code=403, detail="Нет прав на отправку")
    
    if offer.status_mod != ModerationStatus.draft.value:
        raise HTTPException(
            status_code=400,
            detail=f"Отправка на модерацию возможна только в статусе 'черновик'"
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
    user: dict = Depends(require_role),
    db: AsyncSession = Depends(get_db),
):
    offer = await get_offer_or_404(db, offer_id)
    if request.comment_admin is not None:
        offer.comment_admin = request.comment_admin
    
    offer.admin_id = user.get("uid")

    if offer.status_mod not in [ModerationStatus.moderation.value, ModerationStatus.revision.value]:
        raise HTTPException(
            status_code=400,
            detail=f"Модерация возможна только для статусов 'moderation' или 'revision'. Текущий статус: {offer.status_mod}"
        )

    if request.action == ModerationStatus.approved:
        try:
            new_news = await create_news(offer, db)

            if offer.event_id:
                offer_event = await get_offer_event_or_404(db, offer.event_id)
                await db.delete(offer_event)
            if offer.topic_id:
                offer_topic = await get_offer_topic_or_404(db, offer.topic_id)
                await db.delete(offer_topic)
            if offer.image_url:
                await delete_old_image(offer.image_url)
            await db.delete(offer)

            offer.status_mod = ModerationStatus.approved.value
            await db.commit()
            await db.refresh(offer)
            return new_news
    
        except HTTPException as e:
            await db.rollback()
            raise e
        except Exception as e:
            await db.rollback()
            raise HTTPException(
                status_code=500,
                detail=f"Ошибка при создании новости из предложки: {str(e)}"
            )


    elif request.action == ModerationStatus.rejected:
        offer.status_mod = ModerationStatus.rejected.value
        await db.commit()
        await db.refresh(offer)
        return offer
    
    elif request.action == ModerationStatus.revision:
        offer.status_mod = ModerationStatus.revision.value
        await db.commit()
        await db.refresh(offer)
        return offer
    
    elif request.action == ModerationStatus.archived:
        offer.status_mod = ModerationStatus.archived.value
        await db.commit()
        await db.refresh(offer)
        return offer
        
    else:
        raise HTTPException(
            status_code=400,
            detail=f"Недопустимое действие модерации: {request.action}"
        )


@router.delete("/offers/{offer_id}")
async def delete_offer(
    news_id: str,
    user: dict = Depends(require_role),
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

