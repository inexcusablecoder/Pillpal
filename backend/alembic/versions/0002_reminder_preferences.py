"""User alarm + phone fields; per-medicine reminder toggle

Revision ID: 0002_reminder
Revises: 0001_initial
Create Date: 2026-04-02
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0002_reminder"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("phone_e164", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column(
            "alarm_reminders_enabled",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
    )
    op.add_column(
        "medicines",
        sa.Column(
            "reminder_enabled",
            sa.Boolean(),
            server_default=sa.text("true"),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("medicines", "reminder_enabled")
    op.drop_column("users", "alarm_reminders_enabled")
    op.drop_column("users", "phone_e164")
