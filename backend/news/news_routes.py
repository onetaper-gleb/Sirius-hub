
import io
import os
import uuid
from typing import List

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from PIL import Image
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from auth.auth_routes import get_current_user, require_council_role
from database.database import get_db
from database.models import News, RegStatus, EventStatus

from .schemas import NewsResponse, EventResponse, RegistrationResponse

router = APIRouter(
    prefix="/news",
    tags=["News"],
)

MAX_FILE_SIZE = 4 * 1024 * 1024


@router.post("/", response_model=NewsResponse)
async def create_news(

    title: str = Form(...),
    content: str = Form(...),
    is_event: bool = Form(default=False),
    image: UploadFile = File(None),
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    image_url = None

    if image:
        contents = await image.read()

        if len(contents) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=400, detail="Размер файла не должен превышать 2 МБ"
            )

        try:
            img = Image.open(io.BytesIO(contents))

            if img.mode in ("RGBA", "P"):
                img = img.convert("RGB")

            img.thumbnail((800, 800))

            file_name = f"{uuid.uuid4()}.webp"
            file_path = f"uploads/{file_name}"

            img.save(file_path, format="WEBP", quality=75)

            image_url = f"/static/{file_name}"

        except Exception as e:
            raise HTTPException(
                status_code=400, detail="Неверный формат изображения или файл поврежден"
            )

    new_news = News(
        title=title, content=content, image_url=image_url, author_id=user.get("uid")
    )

    db.add(new_news)
    await db.commit()
    await db.refresh(new_news)

    return new_news

@router.put("/{news_id}", response_model=NewsResponse)
async def update_news():
    pass

@router.get("/{news_id}", response_model=NewsResponse)
async def get_news():
    pass

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

    if news_item.image_url:
        file_name = news_item.image_url.replace("/static/", "")
        file_path = f"uploads/{file_name}"

        if os.path.exists(file_path):
            os.remove(file_path)

    try:
        await db.delete(news_item)
        await db.commit()
        return {"status": "success", "message": "Новость и изображение успешно удалены"}
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при удалении: {str(e)}")

@router.get("/", response_model=List[NewsResponse])
async def get_all_news(
    user: dict = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(News).order_by(News.created_at.desc()))
    news_list = result.scalars().all()
    return news_list

@router.patch("/events/{event_id}")
async def update_event_status():
    pass


@router.post("/events/{event_id}/register", response_model=RegistrationResponse)
async def create_reg():
    pass

@router.delete("/events/{event_id}/register")
async def delete_reg():
    pass

@router.get("/events/{event_id}", response_model=List[RegistrationResponse])
async def get_all_part():
    pass

@router.patch("/events/{event_id}{user_id}")
async def update_part_status():
    pass


