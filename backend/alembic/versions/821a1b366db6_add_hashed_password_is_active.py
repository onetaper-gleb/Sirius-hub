"""Add password authentication without changing existing user identities."""

import sqlalchemy as sa

from alembic import op

revision = "821a1b366db6"
down_revision = "5a1e237bc965"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("users") as batch_op:
        batch_op.add_column(
            sa.Column(
                "hashed_password", sa.String(), nullable=False, server_default="!"
            )
        )
        batch_op.add_column(
            sa.Column(
                "is_active", sa.Boolean(), nullable=False, server_default=sa.true()
            )
        )
    op.execute("UPDATE users SET role = 'student' WHERE role IS NULL")
    with op.batch_alter_table("users") as batch_op:
        batch_op.alter_column("hashed_password", server_default=None)
        batch_op.alter_column("is_active", server_default=None)
        batch_op.alter_column("role", existing_type=sa.String(), nullable=False)
    op.create_index(
        "ix_users_email_lower", "users", [sa.text("lower(email)")], unique=True
    )


def downgrade() -> None:
    op.drop_index("ix_users_email_lower", table_name="users")
    with op.batch_alter_table("users") as batch_op:
        batch_op.alter_column("role", existing_type=sa.String(), nullable=True)
        batch_op.drop_column("is_active")
        batch_op.drop_column("hashed_password")
