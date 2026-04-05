"""medicines.label_image_key for bottle/label photo

Revision ID: 0004_label_img
Revises: 0003_ref_meds
Create Date: 2026-04-04
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0004_label_img"
down_revision: Union[str, None] = "0003_ref_meds"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "medicines",
        sa.Column("label_image_key", sa.String(length=512), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("medicines", "label_image_key")
