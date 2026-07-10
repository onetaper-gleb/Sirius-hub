import datetime
from typing import Optional

from pydantic import BaseModel

from database.models import EventStatus, RegStatus


class NewsResponse(BaseModel):
    id: str
    title: str
    content: str
    image_url: Optional[str] = None
    author_id: str
    created_at: datetime.datetime
    is_event: bool
    event_id: Optional[str] = None

    class Config:
        from_attributes = True


class EventResponse(BaseModel):
    id: str
    status: EventStatus
    news_id: str
    event_start: str
    event_end: str
    location: str
    max_partic: int
    cur_partic: int
    is_reg_open: bool


class RegistrationResponse(BaseModel):
    id: str
    event_id: str
    user_id: str
    status: RegStatus
    comment: str
