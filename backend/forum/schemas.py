from pydantic import BaseModel
from typing import Optional

class Topic(BaseModel):
    title: str | None
    topic_id: str | None
    responses_count: int = 0
    anon: bool = False


class Topics(BaseModel):
    topics: list[Topic]


class CreateTopicRequest(BaseModel):
    title: str
    anon: bool = False


class CreateCommentRequest(BaseModel):
    content: str
    topic_id: str
    parent_comment_id: Optional[str] = None


class Comment(BaseModel):
    content: str | None
    comment_id: str | None
    author: str | None = "anon"
    parent_comment_id: Optional[str] = None
    reply_to_author: Optional[str] = None