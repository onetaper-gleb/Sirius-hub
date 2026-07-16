import io
import os
import uuid
from typing import List, Optional
from PIL import Image

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from auth.auth_routes import get_current_user, require_council_role
from database.database import get_db
from database.models import Events, EventStatus, News, Registrations, RegStatus, Topics

from .schemas import (
    EventResponse,
    NewsEventsRequest,
    NewsResponse,
    RegistrationResponse,
)

router = APIRouter(
    prefix="/news",
    tags=["News"],
)

MAX_FILE_SIZE = 4 * 1024 * 1024

class NotFound(Exception):
    pass

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
    if not image_url:
        return

    old_file_path = image_url.replace("/static/", "uploads/")
    if os.path.exists(old_file_path):
        os.remove(old_file_path)


async def get_news_or_404(db: AsyncSession, news_id: str):
    result = await db.execute(select(News).where(News.id == news_id))
    news = result.scalar_one_or_none()
    if not news:
        raise NotFound(status_code=404, detail="Новость не найдена")
    return news


async def get_event_or_404(db: AsyncSession, event_id: str):
    result = await db.execute(select(Events).where(Events.id == event_id))
    event = result.scalar_one_or_none()
    if not event:
        raise NotFound(status_code=404, detail="Событие не найдено")
    return event


async def get_registration_or_404(db: AsyncSession, reg_id: str):
    result = await db.execute(select(Registrations).where(Registrations.id == reg_id))
    reg = result.scalar_one_or_none()
    if not reg:
        raise NotFound(status_code=404, detail="Событие не найдено")
    return reg

async def get_topic_or_404(db: AsyncSession, topic_id: str):
    result = await db.execute(select(Topics).where(Topics.id == topic_id))
    topic = result.scalar_one_or_none()
    if not topic:
        raise NotFound(status_code=404, detail="Топик не найден")
    return topic


def validate_event_status(status: str):
    if status not in [s.value for s in EventStatus]:
        valid_values = ", ".join([s.value for s in EventStatus])
        raise HTTPException(
            status_code=400, detail=f"Недопустимый статус. Доступные: {valid_values}"
        )


def validate_registration_status(status: str):
    if status not in [s.value for s in RegStatus]:
        valid_values = ", ".join([s.value for s in RegStatus])
        raise HTTPException(
            400, f"Недопустимый статус: {status}, доступные: {valid_values}"
        )


async def validate_event_data(request: NewsEventsRequest, db: AsyncSession):
    if not all(
        [
            request.event_status,
            request.event_start,
            request.event_end,
            request.location,
            request.max_partic,
        ]
    ):
        await db.rollback()
        raise HTTPException(
            status_code=400,
            detail="Для создания события обязательны все поля: event_status, event_start, event_end, location, max_partic",
        )

    validate_event_status(request.event_status)

    if request.max_partic < 1:
        await db.rollback()
        raise HTTPException(status_code=400, detail="max_partic должно быть больше 0")


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
        is_event=request.has_event,
        event_id=None,
        is_topic=request.has_topic,
        topic_id=None,
    )

    db.add(new_news)
    await db.flush()

    if request.has_event:
        await validate_event_data(request, db)
        new_event = Events(
            status=request.event_status,
            event_start=request.event_start,
            event_end=request.event_end,
            location=request.location,
            max_partic=request.max_partic,
            cur_partic=0,
            is_reg_open=request.is_reg_open,
            news_id=new_news.id,
        )
        db.add(new_event)
        await db.flush()
        new_news.event_id = new_event.id
        db.add(new_news)

    if request.has_topic:
        new_topic = Topics(
            title=request.title,
            anon=request.anon
        )
        db.add(new_topic)
        await db.flush()
        new_news.topic_id = new_topic.id
        db.add(new_news)

    await db.commit()
    await db.refresh(new_news)
    if request.has_event:
        await db.refresh(new_event)
    if request.has_topic:
        await db.refresh(new_topic)

    return new_news


@router.put("/{news_id}", response_model=NewsResponse)
async def update_news(
    news_id: str,
    request: NewsEventsRequest,
    image: UploadFile = File(None),
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    news = await get_news_or_404(db, news_id)
    role = user.get("role", "student")

    if news.author_id != user.get("uid") and role in ["student", "council"]:
        raise HTTPException(status_code=403, detail="Нет прав на редактирование")

    if image:
        await delete_old_image(news.image_url)
        news.image_url = await process_image(image)

    if request.title is not None:
        news.title = request.title
    if request.content is not None:
        news.content = request.content
    if request.has_event is not None:
        news.has_event = request.has_event
    if request.has_topic is not None:
        news.has_topic = request.has_topic

    if news.has_event:
        result = await db.execute(select(Events).where(Events.news_id == news.id))
        event = result.scalar_one_or_none()
        if not event:
            await validate_event_data(request, db)

            new_event = Events(
                status=request.event_status,
                event_start=request.event_start,
                event_end=request.event_end,
                location=request.location,
                max_partic=request.max_partic,
                cur_partic=0,
                is_reg_open=request.is_reg_open or False,
                news_id=news.id,
            )
            db.add(new_event)
            await db.flush()
            news.event_id = new_event.id

        else:
            if request.event_status is not None:
                validate_event_status(request.event_status)
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

    elif request.has_event is False and news.event_id:
        event = await get_event_or_404(db, news.event_id)
        if event:
            await db.delete(event)
            news.event_id = None

    if news.has_topic:
        result = await db.execute(select(Topics).where(Topics.news_id == news.id))
        topic = result.scalar_one_or_none()
        if not topic:

            new_topic = Topics(
                title=request.title,
                anon=request.anon,
                news_id=news.id,
            )
            db.add(new_topic)
            await db.flush()
            news.topic_id = new_topic.id

        else:
            if request.title is not None:
                topic.title = request.title
            if request.anon is not None:
                topic.anon = request.anon

    elif request.has_topic is False and news.topic_id:
        topic = await get_topic_or_404(db, news.topic_id)
        if topic:
            await db.delete(topic)
            news.topic_id = None

    await db.commit()
    await db.refresh(news)

    return news


@router.get("/{news_id}", response_model=NewsResponse)
async def get_news(
    news_id: str,
    db: AsyncSession = Depends(get_db),
):
    return await get_news_or_404(db, news_id)


@router.delete("/{news_id}")
async def delete_news(
    news_id: str,
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    news_item = await get_news_or_404(db, news_id)
    role = user.get("role", "student")

    if news_item.author_id != user.get("uid") and role in ["student", "council"]:
        raise HTTPException(status_code=403, detail="Нет прав на удаление")

    try:
        if news_item.image_url:
            await delete_old_image(news_item.image_url)
        event = await get_event_or_404(db, news_item.event_id)
        topic = await get_topic_or_404(db, news_item.topic_id)
        if event:
            await db.delete(event)
        if topic:
            await db.delete(topic)

        await db.delete(news_item)
        await db.commit()
        return {"status": "success", "message": "Успешное удаление"}

    except NotFound as e:
        await db.rollback()
        raise

    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при удалении: {str(e)}")


@router.get("/", response_model=List[NewsResponse])
async def get_all_news(
    skip: int = 0,
    limit: int = 20,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(News).order_by(News.created_at.desc()).offset(skip).limit(limit)
    )
    news_list = result.scalars().all()
    return news_list


@router.patch("/events/{event_id}", response_model=EventResponse)
async def update_event_status(
    event_id: str,
    status: str = Form(...),
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    event = await get_event_or_404(db, event_id)
    news = await get_news_or_404(db, event.news_id)
    role = user.get("role", "student")

    if news.author_id != user.get("uid") and role in ["student", "council"]:
        raise HTTPException(
            status_code=403, detail="Нет прав на изменение статуса события"
        )

    validate_event_status(status)

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
    event = await get_event_or_404(db, event_id)
    if not event.is_reg_open:
        raise HTTPException(status_code=400, detail="Регистрация на событие закрыта")

    result = await db.execute(
        select(Registrations).where(
            Registrations.event_id == event_id, Registrations.user_id == user.get("uid")
        )
    )
    existing_reg = result.scalar_one_or_none()
    if existing_reg:
        raise HTTPException(
            status_code=400, detail="Вы уже зарегистрированы на это событие"
        )

    if event.cur_partic >= event.max_partic:
        status = RegStatus.waiting_list
    else:
        status = RegStatus.pending
        event.cur_partic += 1

    new_registration = Registrations(
        event_id=event_id, user_id=user.get("uid"), status=status.value, comment=comment
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
            Registrations.event_id == event_id, Registrations.user_id == user.get("uid")
        )
    )
    registration = result.scalar_one_or_none()
    if not registration:
        raise HTTPException(status_code=404, detail="Регистрация не найдена")

    event = await get_event_or_404(db, event_id)
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
    event = await get_event_or_404(db, event_id)
    role = user.get("role", "student")

    if role in ["student", "council"]:
        raise HTTPException(status_code=403, detail="Нет прав на просмотр")

    result = await db.execute(
        select(Registrations)
        .where(Registrations.event_id == event_id)
        .order_by(Registrations.created_at.asc())
    )
    registrations = result.scalars().all()

    return registrations


@router.patch("/events/{event_id}/{user_id}", response_model=RegistrationResponse)
async def update_part_status(
    event_id: str,
    user_id: str,
    status: str = Form(...),
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    event = await get_event_or_404(db, event_id)
    news = await get_news_or_404(db, event.news_id)
    role = user.get("role", "student")

    if news.author_id != user.get("uid") and role in ["student", "council"]:
        raise HTTPException(
            status_code=403,
            detail="Только автор события может менять статусы участников",
        )
    if not news:
        raise HTTPException(status_code=404, detail="Новость не найдена")

    result = await db.execute(
        select(Registrations).where(
            Registrations.event_id == event_id, Registrations.user_id == user_id
        )
    )
    registration = result.scalar_one_or_none()

    if not registration:
        raise HTTPException(status_code=404, detail="Регистрация не найдена")

    validate_registration_status(status)

    old_status = registration.status
    registration.status = status

    if old_status != RegStatus.confimed.value and status == RegStatus.confimed.value:
        if event.cur_partic < event.max_partic:
            event.cur_partic += 1
        else:
            await db.rollback()
            raise HTTPException(
                status_code=403, detail="Превышено максимальное количество участников"
            )
    elif old_status == RegStatus.confimed.value and status != RegStatus.confimed.value:
        event.cur_partic -= 1

    await db.commit()
    await db.refresh(registration)
    await db.refresh(event)

    return registration
