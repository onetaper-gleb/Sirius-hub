import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Integer, String, Text

from .database import Base

USER_AVATAR_EMOJI_MAX_LEN = 16
USER_DISPLAY_NAME_MAX_LEN = 30
USER_BIO_MAX_LEN = 200
USER_TELEGRAM_HANDLE_MAX_LEN = 33
USER_GROUP_CODE_MAX_LEN = 20
USER_COMMENT_MAX = 50


def _utc_now_naive() -> datetime:
    """UTC wall time without tzinfo — matches PostgreSQL TIMESTAMP WITHOUT TIME ZONE + asyncpg."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class News(Base):
    __tablename__ = "news"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    title = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    image_url = Column(String, nullable=True)
    author_id = Column(String, nullable=False)
    created_at = Column(DateTime, default=_utc_now_naive)
    is_event = Column(Boolean, nullable=False, default=False)
    event_id = Column(String, nullable=True)


class Events(Base):
    __tablename__ = "events"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    status = Column(String, default="draft")
    news_id = Column(String, nullable=False)
    event_start = Column(String, nullable=False)
    event_end = Column(String, nullable=False)
    location = Column(String, nullable=False)
    max_partic = Column(Integer, nullable=False)
    cur_partic = Column(Integer, nullable=False)
    is_reg_open = Column(Boolean, nullable=False, default=False)


class Registrations(Base):
    __tablename__ = "registrations"
    id = Column(String, primary_key=True, index=True)
    event_id = Column(String, nullable=False)
    user_id = Column(String, nullable=False)
    status = Column(String, default="registration open")
    comment = Column(String(USER_COMMENT_MAX), nullable=True)


class EventStatus(str, enum.Enum):
    draft = "draft"
    moderation = "moderation"
    published = "published"
    finished = "finished"
    canceled = "canceled"
    archived = "archived"


class RegStatus(str, enum.Enum):
    r_open = "registration open"
    pending = "pending"
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
    email = Column(String, unique=True, index=True)
    role = Column(String, default="student")
    created_at = Column(DateTime, default=_utc_now_naive)

    avatar_emoji = Column(String(USER_AVATAR_EMOJI_MAX_LEN), nullable=True)
    display_name = Column(String(USER_DISPLAY_NAME_MAX_LEN), nullable=True)
    group_code = Column(String(USER_GROUP_CODE_MAX_LEN), nullable=True)
    bio = Column(String(USER_BIO_MAX_LEN), nullable=True)
    telegram_handle = Column(String(USER_TELEGRAM_HANDLE_MAX_LEN), nullable=True)


class Topics(Base):
    __tablename__ = "topics"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    title = Column(String(50), nullable=False)
    anon = Column(Boolean, nullable=False, default=False)


class Comments(Base):
    __tablename__ = "comments"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    topic_id = Column(String, nullable=False, index=True)
    user_id = Column(String, nullable=False)
    content = Column(String(200), nullable=False)
    created_at = Column(DateTime, default=_utc_now_naive)
    parent_comment_id = Column(String, nullable=True)
