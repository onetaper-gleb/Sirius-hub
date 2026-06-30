from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from auth.auth_routes import get_current_user
from database.database import get_db
from database.models import Comments, Topics, User

from .schemas import Comment as CommentScheme
from .schemas import CreateCommentRequest

topic_router = APIRouter(
    prefix="/topic",
    tags=["comments inside topic"],
)


async def _get_db_user(db: AsyncSession, uid: str) -> User | None:
    result = await db.execute(select(User).where(User.id == uid))
    return result.scalar_one_or_none()


async def _get_db_topic(db: AsyncSession, uid: str) -> Topics | None:
    result = await db.execute(select(Topics).where(Topics.id == uid))
    return result.scalar_one_or_none()


@topic_router.get("/comments", response_model=List[CommentScheme])
async def get_comments(
    topic_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    comments_schemas = await db.execute(
        select(Comments)
        .where(Comments.topic_id == topic_id)
        .order_by(Comments.created_at.desc())
    )
    comments_models = comments_schemas.scalars().all()

    comments_schemas = []
    topic = await _get_db_topic(db, topic_id)
    for comment in comments_models:
        comment_author = await _get_db_user(db, comment.user_id)
        comments_schemas.append(
            {
                "content": comment.content,
                "comment_id": comment.id,
                "author": (
                    "" if topic.anon or comment_author is None else comment_author.id
                ),
            }
        )

    return comments_schemas


@topic_router.post("/comments", response_model=CommentScheme)
async def create_comment(
    request: CreateCommentRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    content = request.content.strip()
    if not 1 < len(content) < 200:
        raise HTTPException(status_code=400, detail="Comment content is invalid")

    topic = await _get_db_topic(db, request.topic_id)
    if topic is None:
        raise HTTPException(status_code=400, detail="Topic does not exist")

    new_comment = Comments(
        content=content, topic_id=request.topic_id, user_id=user.get("uid")
    )
    db.add(new_comment)
    await db.commit()
    await db.refresh(new_comment)

    author = await _get_db_user(db, new_comment.user_id)

    return {
        "content": new_comment.content,
        "comment_id": new_comment.id,
        "author": "" if topic.anon or author is None else author.id,
    }
