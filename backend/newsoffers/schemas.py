from pydantic import BaseModel
from typing import Optional
import datetime
from database.models import EventStatus, ModerationAction

class OfferNewsResponse(BaseModel):
    id: str
    title: str
    content: str
    image_url: Optional[str] = None
    author_id: str
    created_at: datetime.datetime
    is_event: bool
    event_id: Optional[str] = None
    admin_id: Optional[str] = None
    comment_admin: Optional[str] = None
    status_mod: Optional[str] = None
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

class OfferNewsEventsRequest(BaseModel):
    title: str
    content: str
    is_event: bool = False
    event_status: Optional[str] = None
    event_start: Optional[str] = None
    event_end: Optional[str] = None
    location: Optional[str] = None
    max_partic: Optional[int] = None
    is_reg_open: bool = False
    contacts_author: str

class AdminModRequest(BaseModel):
    offer_id: str
    action: ModerationAction
    comment_admin: Optional[str] = None
    