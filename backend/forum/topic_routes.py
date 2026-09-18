from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from auth.auth_routes import get_current_user, require_council_role
from database.database import get_db
from database.models import Comments, Topics, User
from utils.logger import set_logger

from .schemas import Comment as CommentScheme
from .schemas import CreateCommentRequest

topic_router = APIRouter(
    prefix="/topic",
    tags=["Comments"],
)

logger = set_logger()


async def _get_db_user(db: AsyncSession, uid: str) -> User | None:
    result = await db.execute(select(User).where(User.id == uid))
    return result.scalar_one_or_none()


async def _get_db_topic(db: AsyncSession, uid: str) -> Topics | None:
    result = await db.execute(select(Topics).where(Topics.id == uid))
    return result.scalar_one_or_none()


async def _get_db_comment(db: AsyncSession, comment_id: str) -> Comments | None:
    result = await db.execute(select(Comments).where(Comments.id == comment_id))
    return result.scalar_one_or_none()


@topic_router.get("/comments", response_model=List[CommentScheme])
async def get_comments(
    topic_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):

    logger.info(f"User requested comments for topic {topic_id}")

    topic = await _get_db_topic(db, topic_id)

    if topic is None:

        logger.warning(
            f"User tried to get comments from a non-existent topic {topic_id}"
        )
        raise HTTPException(status_code=404, detail="Topic does not exist")

    comments_schemas = await db.execute(
        select(Comments)
        .where(Comments.topic_id == topic_id)
        .order_by(Comments.created_at.desc())
    )

    comments_models = comments_schemas.scalars().all()

    comments_schemas = []
    for comment in comments_models:
        comment_author = await _get_db_user(db, comment.user_id)

        reply_to_author = None
        if comment.parent_comment_id:
            parent_comment = await _get_db_comment(db, comment.parent_comment_id)

            if parent_comment:
                parent_author = await _get_db_user(db, parent_comment.user_id)

                if parent_author and not topic.anon:
                    reply_to_author = parent_author.id

        comments_schemas.append(
            {
                "content": comment.content,
                "comment_id": comment.id,
                "author": (
                    "" if topic.anon or comment_author is None else comment_author.id
                ),
                "parent_comment_id": comment.parent_comment_id,
                "reply_to_author": reply_to_author,
            }
        )

    logger.info(f"User successfully received comments for a topic {topic_id}")
    return comments_schemas


@topic_router.post("/comments", response_model=CommentScheme)
async def create_comment(
    request: CreateCommentRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    logger.info(f"User is trying to create a comment in topic {request.topic_id}")

    content = request.content.strip()

    if not 1 < len(content) < 200:

        logger.warning(f"User tried to create an invalid comment")
        raise HTTPException(status_code=400, detail="Comment content is invalid")

    topic = await _get_db_topic(db, request.topic_id)
    if topic is None:

        logger.warning(f"User tried to create a comment for a non-existent topic")
        raise HTTPException(status_code=404, detail="Topic does not exist")

    reply_to_author = None
    if request.parent_comment_id:
        parent_comment = await _get_db_comment(db, request.parent_comment_id)

        if parent_comment is None:

            logger.warning(f"User tried to reply to a non-existent comment")
            raise HTTPException(status_code=404, detail="Parent comment not found")

        if parent_comment.topic_id != request.topic_id:

            logger.warning(f"User tried to reply to a comment from another topic")
            raise HTTPException(
                status_code=400, detail="Can not reply to a comment from another topic"
            )

        parent_author = await _get_db_user(db, parent_comment.user_id)

        if parent_comment and not topic.anon:
            reply_to_author = parent_author.id

    new_comment = Comments(
        content=content,
        topic_id=request.topic_id,
        user_id=user.get("uid"),
        parent_comment_id=request.parent_comment_id,
    )

    db.add(new_comment)
    await db.commit()
    await db.refresh(new_comment)

    author = await _get_db_user(db, new_comment.user_id)

    logger.info(
        f"User successfully created a comment {new_comment.id} in topic {request.topic_id}"
    )

    return {
        "content": new_comment.content,
        "comment_id": new_comment.id,
        "author": "" if topic.anon or author is None else author.id,
        "parent_comment_id": new_comment.parent_comment_id,
        "reply_to_author": reply_to_author,
    }


@topic_router.delete("/comments/{comment_id}")
async def delete_comment(
    comment_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    id_user = user.get("uid")
    logger.info(f"User is trying to delete a comment {comment_id}")

    comment = await _get_db_comment(db, comment_id)

    if comment is None:

        logger.warning(f"User is trying to delete a non-existent comment")
        raise HTTPException(status_code=404, detail="Comment not found")

    if comment.user_id != id_user:
        await require_council_role(db=db, user=user)

    await db.execute(delete(Comments).where(Comments.parent_comment_id == comment_id))

    await db.delete(comment)
    await db.commit()

    logger.info(f"User successfully deleted a comment {comment_id} and its replies")

    return {"message": "Comment deleted successfully"}
