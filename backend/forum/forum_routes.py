from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from auth.auth_routes import get_current_user, require_council_role
from database.database import get_db
from database.models import Comments, Topics

from .schemas import CreateTopicRequest
from .schemas import Topic as TopicScheme

forum_router = APIRouter(
    prefix="/forum",
    tags=["forum"],
)


@forum_router.get("/topics", response_model=List[TopicScheme])
async def get_topics(
    user: dict = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Topics, func.count(Comments.id).label("comment_count"))
        .outerjoin(Comments, Comments.topic_id == Topics.id)
        .group_by(Topics.id)
    )
    rows = result.all()

    return [
        {
            "title": topic.title,
            "topic_id": topic.id,
            "responses_count": count,
            "anon": topic.anon,
        }
        for topic, count in rows
    ]


@forum_router.post("/topics", response_model=TopicScheme)
async def create_topic(
    request: CreateTopicRequest,
    user: dict = Depends(require_council_role),
    db: AsyncSession = Depends(get_db),
):
    title = request.title.strip()
    if not 1 < len(title) < 50:
        raise HTTPException(status_code=400, detail="Title is invalid")
    new_topic = Topics(title=title, anon=request.anon)
    db.add(new_topic)
    await db.commit()
    await db.refresh(new_topic)

    return {
        "title": new_topic.title,
        "topic_id": new_topic.id,
        "responses_count": 0,
        "anon": new_topic.anon,
    }
