from typing import Optional

from pydantic import BaseModel, Field, field_validator

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

    @field_validator("title", mode="before")
    @classmethod
    def strip_title(cls, value):
        return value.strip() if isinstance(value, str) else value


class CreateCommentRequest(BaseModel):
    content: str = Field(..., min_length=MIN_LEN, max_length=USER_COMMENT_MAX_LEN)
    topic_id: str
    parent_comment_id: Optional[str] = None

    @field_validator("content", mode="before")
    @classmethod
    def strip_content(cls, value):
        return value.strip() if isinstance(value, str) else value


class UpdateCommentRequest(BaseModel):
    content: str = Field(..., min_length=MIN_LEN, max_length=USER_COMMENT_MAX_LEN)

    @field_validator("content", mode="before")
    @classmethod
    def strip_content(cls, value):
        return value.strip() if isinstance(value, str) else value


class Comment(BaseModel):
    content: str | None
    comment_id: str | None
    author: str | None = "anon"
    parent_comment_id: Optional[str] = None
    reply_to_author: Optional[str] = None
