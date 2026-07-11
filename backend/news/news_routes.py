
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
from database.models import News, Events, Registrations, RegStatus, EventStatus

from .schemas import NewsResponse, EventResponse, RegistrationResponse, NewsEventsRequest

router = APIRouter(
    prefix="/news",
    tags=["News"],
)

MAX_FILE_SIZE = 4 * 1024 * 1024

# utils/image_utils.py
import io
import os
import uuid
from PIL import Image
from fastapi import HTTPException, UploadFile

MAX_FILE_SIZE = 2 * 1024 * 1024  # 2 MB

async def process_image(image: UploadFile | None):
    if not image:
        return None
    contents = await image.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(400, "Размер файла не должен превышать 2 МБ")
    
    try:
        img = Image.open(io.BytesIO(contents))
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")
        
        img.thumbnail((800, 800))
        
        file_name = f"{uuid.uuid4()}.webp"
        file_path = f"uploads/{file_name}"
        img.save(file_path, format="WEBP", quality=75)
        
        return f"/static/{file_name}"
    
    except Exception:
        raise HTTPException(400, "Неверный формат изображения или файл поврежден")


async def delete_old_image(image_url: str | None) -> None:
    """Удаляет старое изображение с диска"""
    if not image_url:
        return
    
    old_file_path = image_url.replace("/static/", "uploads/")
    if os.path.exists(old_file_path):
        os.remove(old_file_path)

@router.post("/", response_model=NewsResponse)
async def create_news(

    request: NewsEventsRequest,
    image: UploadFile = File(None),
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    image_url = await process_image(image)

    new_news = News(
        title=request.title, 
        content=request.content, 
        image_url=image_url, 
        author_id=user.get("uid"), 
        is_event=request.is_event,
        event_id=None
    )

    db.add(new_news)
    await db.flush()

    if request.is_event:
        if not all([request.event_status, request.event_start, request.event_end, request.location, request.max_partic]):
            await db.rollback()
            raise HTTPException(
                status_code=400, 
                detail="Для события обязательны: event_status, event_start, event_end, location, max_partic"
            )
        if request.event_status not in [s.value for s in EventStatus]:
            await db.rollback()
            valid_values = ', '.join([s.value for s in EventStatus])
            raise HTTPException(400, f"Недопустимый статус: {request.event_status}, доступные: {valid_values}")
        
        if request.max_partic is not None and request.max_partic < 1:
            await db.rollback()
            raise HTTPException(
                status_code=400, 
                detail="max_partic должно быть больше 0"
            )
        
        new_event = Events(
            status=request.event_status, 
            event_start=request.event_start, 
            event_end=request.event_end, 
            location=request.location, 
            max_partic=request.max_partic, 
            cur_partic=0, 
            is_reg_open=request.is_reg_open,
            news_id=new_news.id
        )

        db.add(new_event)
        await db.flush()
        new_news.event_id = new_event.id
        db.add(new_news)

    await db.commit()
    await db.refresh(new_news)
    if request.is_event:
        await db.refresh(new_event)

    return new_news

@router.put("/{news_id}", response_model=NewsResponse)
async def update_news(
    news_id: str,
    request: NewsEventsRequest,
    image: UploadFile = File(None),
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(News).where(News.id == news_id))
    news = result.scalar_one_or_none()
    if not news:
        raise HTTPException(status_code=404, detail="Новость не найдена")
    if news.author_id != user.get("uid"):
        raise HTTPException(status_code=403, detail="Нет прав на редактирование")
    
    if image:
        await delete_old_image(news.image_url)
        news.image_url = await process_image(image)

    if request.title is not None:
        news.title = request.title
    if request.content is not None:
        news.content = request.content
    if request.is_event is not None:
        news.is_event = request.is_event

    if news.is_event:
        result = await db.execute(select(Events).where(Events.news_id == news.id))
        event = result.scalar_one_or_none()
        if not event:
            if not all([request.event_status, request.event_start, request.event_end, request.location, request.max_partic]):
                await db.rollback()
                raise HTTPException(400, "Для создания события обязательны все поля")
            if request.event_status not in [s.value for s in EventStatus]:
                await db.rollback()
                valid = ', '.join([s.value for s in EventStatus])
                raise HTTPException(400, f"Недопустимый статус. Доступные: {valid}")
            if request.max_partic < 1:
                await db.rollback()
                raise HTTPException(400, "max_partic должно быть больше 0")
            
            new_event = Events(
                status=request.event_status,
                event_start=request.event_start,
                event_end=request.event_end,
                location=request.location,
                max_partic=request.max_partic,
                cur_partic=0,
                is_reg_open=request.is_reg_open or False,
                news_id=news.id
            )
            db.add(new_event)
            await db.flush()
            news.event_id = new_event.id

        else:
            if request.event_status is not None:
                if request.event_status not in [s.value for s in EventStatus]:
                    await db.rollback()
                    valid = ', '.join([s.value for s in EventStatus])
                    raise HTTPException(400, f"Недопустимый статус. Доступные: {valid}")
                event.status = request.event_status
            
            if request.event_start is not None:
                event.event_start = request.event_start
            if request.event_end is not None:
                event.event_end = request.event_end
            if request.location is not None:
                event.location = request.location
            if request.max_partic is not None:
                if request.max_partic < 1:
                    await db.rollback()
                    raise HTTPException(400, "max_partic должно быть больше 0")
                event.max_partic = request.max_partic
            if request.is_reg_open is not None:
                event.is_reg_open = request.is_reg_open

    elif request.is_event is False and news.event_id:
        result = await db.execute(select(Events).where(Events.id == news.event_id))
        event = result.scalar_one_or_none()
        if event:
            await db.delete(event)
            news.event_id = None
    
    await db.commit()
    await db.refresh(news)
    
    return news

            
@router.get("/{news_id}", response_model=NewsResponse)
async def get_news(
    news_id: str,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(News).where(News.id == news_id))
    news = result.scalar_one_or_none()
    if not news:
        raise HTTPException(status_code=404, detail="Новость не найдена")
    return news

@router.delete("/{news_id}")
async def delete_news(
    news_id: str,
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(News).where(News.id == news_id))
    news_item = result.scalar_one_or_none()

    if not news_item:
        raise HTTPException(status_code=404, detail="Новость не найдена")
    if news_item.author_id != user.get("uid"):
        raise HTTPException(status_code=403, detail="Нет прав на удаление")

    try:
        if news_item.image_url:
            await delete_old_image(news_item.image_url)
        if news_item.event_id:
            result = await db.execute(select(Events).where(Events.id == news_item.event_id))
            event = result.scalar_one_or_none()
            if event:
                await db.delete(event)

        await db.delete(news_item)
        await db.commit()
        return {"status": "success", "message": "Успешное удаление"}
    
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при удалении: {str(e)}")

@router.get("/", response_model=List[NewsResponse])
async def get_all_news(
    skip: int = 0,
    limit: int = 20,
    user: dict = Depends(get_current_user), 
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(News).order_by(News.created_at.desc()).offset(skip).limit(limit))
    news_list = result.scalars().all()
    return news_list

@router.patch("/events/{event_id}", response_model=EventResponse)
async def update_event_status(
    event_id: str,
    status: str = Form(...),
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Events).where(Events.id == event_id))
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="Событие не найдено")
    result = await db.execute(select(News).where(News.id == event.news_id))
    news = result.scalar_one_or_none()
    if not news:
        raise HTTPException(status_code=404, detail="Связанная новость не найдена")
    if news.author_id != user.get("uid"):
        raise HTTPException(status_code=403, detail="Нет прав на изменение статуса события")
    
    if status not in [s.value for s in EventStatus]:
        valid_values = ', '.join([s.value for s in EventStatus])
        raise HTTPException(status_code=400, detail=f"Недопустимый статус. Доступные: {valid_values}")
    
    event.status = status
    await db.commit()
    await db.refresh(event)
    
    return event


@router.post("/events/{event_id}/register", response_model=RegistrationResponse)
async def create_reg(
    event_id: str,
    comment: Optional[str] = Form(default=None),
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Events).where(Events.id == event_id))
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="Событие не найдено")
    if not event.is_reg_open:
        raise HTTPException(status_code=400, detail="Регистрация на событие закрыта")
    
    result = await db.execute(
        select(Registrations).where(
            Registrations.event_id == event_id,
            Registrations.user_id == user.get("uid")
        )
    )
    existing_reg = result.scalar_one_or_none()
    if existing_reg:
        raise HTTPException(status_code=400, detail="Вы уже зарегистрированы на это событие")
    
    if event.cur_partic >= event.max_partic:
        status = RegStatus.waiting_list
    else:
        status = RegStatus.pending
        event.cur_partic += 1
    
    new_registration = Registrations(
        event_id=event_id,
        user_id=user.get("uid"),
        status=status.value,
        comment=comment
    )
    
    db.add(new_registration)
    await db.commit()
    await db.refresh(new_registration)
    await db.refresh(event)
    
    return new_registration


@router.delete("/events/{event_id}/register")
async def delete_reg(
    event_id: str,
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Registrations).where(
            Registrations.event_id == event_id,
            Registrations.user_id == user.get("uid")
        )
    )
    registration = result.scalar_one_or_none()
    if not registration:
        raise HTTPException(status_code=404, detail="Регистрация не найдена")
    result = await db.execute(select(Events).where(Events.id == event_id))
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="Событие не найдено")
    await db.delete(registration)

    if registration.status != RegStatus.waiting_list.value:
        event.cur_partic -= 1
    
    await db.commit()
    return {"status": "success", "message": "Регистрация успешно отменена"}


@router.get("/events/{event_id}", response_model=List[RegistrationResponse])
async def get_all_part(
     event_id: str,
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Events).where(Events.id == event_id))
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="Событие не найдено")
    
    result = await db.execute(
        select(Registrations)
        .where(Registrations.event_id == event_id)
        .order_by(Registrations.created_at.asc())
    )
    registrations = result.scalars().all()
    
    return registrations

@router.patch("/events/{event_id}{user_id}", response_model=RegistrationResponse)
async def update_part_status(
    event_id: str,
    user_id: str,
    status: str = Form(...),
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Events).where(Events.id == event_id))
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="Событие не найдено")
    
    result = await db.execute(select(News).where(News.id == event.news_id))
    news = result.scalar_one_or_none()
    
    if not news or news.author_id != user.get("uid"):
        raise HTTPException(status_code=403, detail="Только автор события может менять статусы участников")

    result = await db.execute(
        select(Registrations).where(
            Registrations.event_id == event_id,
            Registrations.user_id == user_id
        )
    )
    registration = result.scalar_one_or_none()
    
    if not registration:
        raise HTTPException(status_code=404, detail="Регистрация не найдена")
    
    if status not in [s.value for s in RegStatus]:
        valid_values = ', '.join([s.value for s in RegStatus])
        raise HTTPException(status_code=400, detail=f"Недопустимый статус. Доступные: {valid_values}")
    
    old_status = registration.status
    registration.status = status
    if old_status == RegStatus.waiting_list.value and status != RegStatus.waiting_list.value:
        if event.cur_partic < event.max_partic:
            event.cur_partic += 1
    elif old_status != RegStatus.waiting_list.value and status == RegStatus.waiting_list.value:
        event.cur_partic -= 1
    elif status in [RegStatus.canceled_by_admin.value, RegStatus.canceled_by_user.value]:
        if old_status != RegStatus.waiting_list.value:
            event.cur_partic -= 1
    
    await db.commit()
    await db.refresh(registration)
    await db.refresh(event)
    
    return registration