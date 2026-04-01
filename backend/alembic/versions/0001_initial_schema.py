"""Initial schema: users, medicines, dose_logs

Revision ID: 0001_initial
Revises:
Create Date: 2026-04-01
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    dose_status_type = postgresql.ENUM("pending", "taken", "missed", name="dose_status", create_type=True)
    dose_status_type.create(op.get_bind(), checkfirst=True)
    # Reuse existing type in the column so SQL render / DDL does not emit CREATE TYPE twice.
    dose_status_col = postgresql.ENUM(
        "pending", "taken", "missed", name="dose_status", create_type=False
    )

    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("display_name", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "medicines",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("dosage", sa.String(length=255), nullable=False),
        sa.Column("scheduled_time", sa.Time(), nullable=False),
        sa.Column("frequency", sa.String(length=32), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("pill_count", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_medicines_user_id", "medicines", ["user_id"])

    op.create_table(
        "dose_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("medicine_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("scheduled_date", sa.Date(), nullable=False),
        sa.Column("scheduled_time", sa.Time(), nullable=False),
        sa.Column("status", dose_status_col, nullable=False),
        sa.Column("taken_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["medicine_id"], ["medicines.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("medicine_id", "scheduled_date", name="uq_dose_medicine_date"),
    )
    op.create_index("ix_dose_logs_user_id", "dose_logs", ["user_id"])
    op.create_index("ix_dose_logs_medicine_id", "dose_logs", ["medicine_id"])
    op.create_index("ix_dose_logs_scheduled_date", "dose_logs", ["scheduled_date"])
    op.create_index("ix_dose_logs_user_scheduled", "dose_logs", ["user_id", "scheduled_date"])


def downgrade() -> None:
    op.drop_index("ix_dose_logs_user_scheduled", table_name="dose_logs")
    op.drop_index("ix_dose_logs_scheduled_date", table_name="dose_logs")
    op.drop_index("ix_dose_logs_medicine_id", table_name="dose_logs")
    op.drop_index("ix_dose_logs_user_id", table_name="dose_logs")
    op.drop_table("dose_logs")

    op.drop_index("ix_medicines_user_id", table_name="medicines")
    op.drop_table("medicines")

    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")

    dose_status = postgresql.ENUM("pending", "taken", "missed", name="dose_status")
    dose_status.drop(op.get_bind(), checkfirst=True)
