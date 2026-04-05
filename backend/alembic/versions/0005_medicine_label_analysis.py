"""medicines.label_analysis_text for Cohere vision summary

Revision ID: 0005_label_analysis
Revises: 0004_label_img
Create Date: 2026-04-04
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0005_label_analysis"
down_revision: Union[str, None] = "0004_label_img"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "medicines",
        sa.Column("label_analysis_text", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("medicines", "label_analysis_text")
