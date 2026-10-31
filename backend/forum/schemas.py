from typing import Optional

from pydantic import BaseModel, Field

from database.constants import MIN_LEN, TITLE_LEN, USER_COMMENT_MAX_LEN


class Topic(BaseModel):
    title: str | None
    topic_id: str | None
    responses_count: int = 0
    anon: bool = False


class Topics(BaseModel):
    topics: list[Topic]


class CreateTopicRequest(BaseModel):
    title: str = Field(..., min_length=MIN_LEN, max_length=TITLE_LEN)
    anon: bool = False


class CreateCommentRequest(BaseModel):
    content: str = Field(..., min_length=MIN_LEN, max_length=USER_COMMENT_MAX_LEN)
    topic_id: str
    parent_comment_id: Optional[str] = None


class UpdateCommentRequest(BaseModel):
    content: str = Field(..., min_length=MIN_LEN, max_length=USER_COMMENT_MAX_LEN)


class Comment(BaseModel):
    content: str | None
    comment_id: str | None
    author: str | None = "anon"
    parent_comment_id: Optional[str] = None
    reply_to_author: Optional[str] = None
