import datetime
import io
import os
import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from PIL import Image
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from auth.auth_routes import get_current_user, require_council_role
from database.database import get_db
from database.models import News

router = APIRouter(
    prefix="/news",
    tags=["News"],
)


class NewsResponse(BaseModel):
    id: str
    title: str
    content: str
    image_url: Optional[str] = None
    author_id: str
    created_at: datetime.datetime

    class Config:
        from_attributes = True


MAX_FILE_SIZE = 4 * 1024 * 1024


@router.post("/", response_model=NewsResponse)
async def create_news(
    title: str = Form(...),
    content: str = Form(...),
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


@router.get("/", response_model=List[NewsResponse])
async def get_all_news(
    user: dict = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(News).order_by(News.created_at.desc()))
    news_list = result.scalars().all()
    return news_list


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
