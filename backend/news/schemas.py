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
    has_event: bool
    event_id: Optional[str] = None
    has_topic: bool
    topic_id: Optional[str] = None

    class Config:
        from_attributes = True


class EventResponse(BaseModel):
    id: str
    status: EventStatus
    news_id: str
    event_start: datetime.datetime
    event_end: datetime.datetime
    location: str
    max_partic: int
    cur_partic: int
    is_reg_open: bool

    class Config:
        from_attributes = True


class RegistrationResponse(BaseModel):
    id: str
    event_id: str
    user_id: str
    status: RegStatus
    comment: Optional[str] = None

    class Config:
        from_attributes = True


class NewsCreateRequest(BaseModel):
    title: str
    content: str
    has_event: bool = False
    has_topic: bool = False

    event_status: Optional[str] = None
    event_start: Optional[datetime.datetime] = None
    event_end: Optional[datetime.datetime] = None
    location: Optional[str] = None
    max_partic: Optional[int] = None
    is_reg_open: bool = False

    anon: Optional[bool] = None
    image: Optional[str] = None

class NewsUpdateRequest(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    has_event: Optional[bool] = None
    has_topic: Optional[bool] = None

    event_status: Optional[str] = None
    event_start: Optional[datetime.datetime] = None
    event_end: Optional[datetime.datetime] = None
    location: Optional[str] = None
    max_partic: Optional[int] = None
    is_reg_open: Optional[bool] = None

    anon: Optional[bool] = None
    image: Optional[str] = None    
