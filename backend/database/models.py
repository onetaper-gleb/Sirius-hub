import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Integer, String, Text
from sqlalchemy.orm import relationship, foreign

from .database import Base

from database.constants import *


def _utc_now_naive() -> datetime:
    """UTC wall time without tzinfo — matches PostgreSQL TIMESTAMP WITHOUT TIME ZONE + asyncpg."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class News(Base):
    __tablename__ = "news"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    title = Column(String(TITLE_LEN), nullable=False)
    content = Column(Text(CONTENT_LEN), nullable=False)
    image_url = Column(String, nullable=True)
    author_id = Column(String, nullable=False)
    created_at = Column(DateTime, default=_utc_now_naive)
    has_event = Column(Boolean, nullable=False, default=False)
    event_id = Column(String, nullable=True)
    has_topic = Column(Boolean, nullable=False, default=False)
    topic_id = Column(String, nullable=True)


class Events(Base):
    __tablename__ = "events"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    status = Column(String, default="draft")
    news_id = Column(String, nullable=False)
    event_start = Column(String, nullable=False)
    event_end = Column(String, nullable=False)
    location = Column(String(EVENT_LOCATION_LEN), nullable=False)
    max_partic = Column(Integer, nullable=False)
    cur_partic = Column(Integer, nullable=False)
    is_reg_open = Column(Boolean, nullable=False, default=False)


class Registrations(Base):
    __tablename__ = "registrations"
    id = Column(String, primary_key=True, index=True)
    event_id = Column(String, nullable=False)
    user_id = Column(String, nullable=False)
    status = Column(String, default="registration open")
    comment = Column(String(COMMENT_MAX), nullable=True)


class OfferNews(Base):
    __tablename__ = "offernews"
    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    title = Column(String(TITLE_LEN), nullable=False)
    content = Column(Text(CONTENT_LEN), nullable=False)
    image_url = Column(String, nullable=True)
    author_id = Column(String, nullable=False)
    contacts_author = Column(String(COMMENT_MAX), nullable=False)
    has_event = Column(Boolean, default=False)
    event_id = Column(String, nullable=True)
    has_topic = Column(Boolean, default=False)
    topic_id = Column(String, nullable=True)
    status_mod = Column(String, default="draft")
    admin_id = Column(String, nullable=True)
    comment_admin = Column(Text(COMMENT_MAX), nullable=True)
    created_at = Column(DateTime, default=_utc_now_naive)


class OfferEvent(Base):
    __tablename__ = "offerevent"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    event_status = Column(String, default="draft")
    news_id = Column(String, nullable=False)
    event_start = Column(String, nullable=False)
    event_end = Column(String, nullable=False)
    location = Column(String(EVENT_LOCATION_LEN), nullable=False)
    max_partic = Column(Integer, nullable=False)
    cur_partic = Column(Integer, nullable=False)
    is_reg_open = Column(Boolean, nullable=False, default=False)


class OfferTopic(Base):
    __tablename__ = "offertopics"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    title = Column(String(TITLE_LEN), nullable=False)
    anon = Column(Boolean, nullable=False, default=False)
    news_id = Column(String, nullable=True)


class ModerationStatus(str, enum.Enum):
    draft = "draft"
    moderation = "moderation"
    approved = "approved"
    rejected = "rejected"
    revision = "revision"
    archived = "archived"
    published = "published"


class EventStatus(str, enum.Enum):
    draft = "draft"
    moderation = "moderation"
    published = "published"
    finished = "finished"
    canceled = "canceled"
    archived = "archived"


class RegStatus(str, enum.Enum):
    r_open = "registration open"
    moderation = "moderation"
    confimed = "confimed"
    waiting_list = "waiting_list"
    canceled_by_user = "canceled_by_user"
    canceled_by_admin = "canceled_by_admin"
    r_closed = "registration closed"


class UserRole(str, enum.Enum):
    student = "student"
    council = "council"
    admin = "admin"


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, index=True)
    email = Column(String(USER_EMAIL_LEN), unique=True, index=True)
    role = Column(String, default="student")
    created_at = Column(DateTime, default=_utc_now_naive)

    avatar_emoji = Column(String(USER_AVATAR_EMOJI_MAX_LEN), nullable=True)
    display_name = Column(String(USER_DISPLAY_NAME_MAX_LEN), nullable=True)
    group_code = Column(String(USER_GROUP_CODE_MAX_LEN), nullable=True)
    bio = Column(String(USER_BIO_MAX_LEN), nullable=True)
    messenger_handle = Column(String(USER_MESSENGER_HANDLE_MAX_LEN), nullable=True)


class Topics(Base):
    __tablename__ = "topics"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    title = Column(String(TITLE_LEN), nullable=False)
    anon = Column(Boolean, nullable=False, default=False)
    news_id = Column(String, nullable=True)


class Comments(Base):
    __tablename__ = "comments"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    topic_id = Column(String, nullable=False, index=True)
    user_id = Column(String, nullable=False)
    content = Column(String(USER_COMMENT_MAX_LEN), nullable=False)
    created_at = Column(DateTime, default=_utc_now_naive)
    parent_comment_id = Column(String, nullable=True)

    author = relationship(
        "User",
        primaryjoin=lambda: foreign(Comments.user_id) == User.id,
        foreign_keys=lambda: [Comments.user_id],
        viewonly=True,
    )

    parent_comment = relationship(
        "Comments",
        primaryjoin=lambda: foreign(Comments.parent_comment_id) == Comments.id,
        foreign_keys=lambda: [Comments.parent_comment_id],
        remote_side=lambda: [Comments.id],
        uselist=False,
        viewonly=True,
    )
