"""call_schedules.schedule_timezone for reminder calls in user local time

Revision ID: 0006_call_tz
Revises: 0005_label_analysis
Create Date: 2026-04-03
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0006_call_tz"
down_revision: Union[str, None] = "0005_label_analysis"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "call_schedules",
        sa.Column("schedule_timezone", sa.String(length=64), nullable=False, server_default="Asia/Kolkata"),
    )
    op.alter_column("call_schedules", "schedule_timezone", server_default=None)


def downgrade() -> None:
    op.drop_column("call_schedules", "schedule_timezone")
