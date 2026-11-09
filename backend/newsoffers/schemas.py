import datetime
from typing import Optional

from pydantic import BaseModel, Field

from database.constants import COMMENT_MAX, EVENT_CAPACITY_MAX, TITLE_LEN
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
    event_start: datetime.datetime
    event_end: datetime.datetime
    location: str
    max_partic: int
    cur_partic: int
    is_reg_open: bool

    class Config:
        from_attributes = True


class OfferNewsEventsRequest(BaseModel):
    title: str = Field(..., max_length=TITLE_LEN)
    content: str
    has_event: bool = False
    has_topic: bool = False
    event_status: Optional[str] = None
    event_start: Optional[datetime.datetime] = None
    event_end: Optional[datetime.datetime] = None
    location: Optional[str] = None
    max_partic: Optional[int] = Field(default=None, le=EVENT_CAPACITY_MAX)
    is_reg_open: bool = False
    contacts_author: str = Field(min_length=1, max_length=COMMENT_MAX)
    anon: bool = False
    image: Optional[str] = None


class AdminModRequest(BaseModel):
    offer_id: str
    action: ModerationStatus
    comment_admin: Optional[str] = None
