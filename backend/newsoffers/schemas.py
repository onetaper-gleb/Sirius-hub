import datetime
from typing import Optional

from pydantic import BaseModel

from database.models import EventStatus, ModerationStatus


class OfferNewsResponse(BaseModel):
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
    admin_id: Optional[str] = None
    comment_admin: Optional[str] = None
    status_mod: ModerationStatus
    contacts_author: str

    class Config:
        from_attributes = True


class OfferEventResponse(BaseModel):
    id: str
    status: EventStatus
    news_id: str
    event_start: str
    event_end: str
    location: str
    max_partic: int
    cur_partic: int
    is_reg_open: bool

    class Config:
        from_attributes = True


class OfferNewsEventsRequest(BaseModel):
    title: str
    content: str
    has_event: bool = False
    has_topic: bool = False
    event_status: Optional[str] = None
    event_start: Optional[str] = None
    event_end: Optional[str] = None
    location: Optional[str] = None
    max_partic: Optional[int] = None
    is_reg_open: bool = False
    contacts_author: str


class AdminModRequest(BaseModel):
    offer_id: str
    action: ModerationStatus
    comment_admin: Optional[str] = None
