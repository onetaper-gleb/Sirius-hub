"""add news views_count and news_views

Revision ID: 9c4f1d2e3a4b
Revises: 821a1b366db6
Create Date: 2026-11-23 11:55:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "9c4f1d2e3a4b"
down_revision: Union[str, Sequence[str], None] = "821a1b366db6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "news",
        sa.Column(
            "views_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.create_table(
        "news_views",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("news_id", sa.String(), nullable=False),
        sa.Column("viewer_key", sa.String(), nullable=False),
        sa.ForeignKeyConstraint(["news_id"], ["news.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("news_id", "viewer_key", name="uq_news_views_news_viewer"),
    )
    op.create_index(
        op.f("ix_news_views_news_id"), "news_views", ["news_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_news_views_news_id"), table_name="news_views")
    op.drop_table("news_views")
    op.drop_column("news", "views_count")
