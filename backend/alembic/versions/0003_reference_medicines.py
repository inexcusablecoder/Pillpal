"""reference_medicines table + seed curated dropdown list

Revision ID: 0003_ref_meds
Revises: 0002_reminder
Create Date: 2026-04-03
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0003_ref_meds"
down_revision: Union[str, None] = "0002_reminder"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Same list as Flutter CommonMedicines + API catalog
_REF_NAMES: list[str] = [
    "Aceclofenac",
    "Acyclovir",
    "Amoxicillin",
    "Artemether",
    "Aspirin",
    "Augmentin",
    "Azax",
    "Azithromycin",
    "Aztreonam",
    "Brufen",
    "Calpol",
    "Cefixime",
    "Cefotaxime",
    "Ceftriaxone",
    "Cetirizine",
    "Chloramphenicol",
    "Chloroquine",
    "Ciprofloxacin",
    "Clarithromycin",
    "Combiflam",
    "Crocin",
    "Diclofenac",
    "Dolo 650",
    "Domperidone",
    "Doxycycline",
    "Ibuprofen",
    "Indomethacin",
    "Ketorolac",
    "Levofloxacin",
    "Linezolid",
    "Loratadine",
    "Lumefantrine",
    "Mefenamic",
    "Mefloquine",
    "Metronidazole",
    "Monocef",
    "Naproxen",
    "ORS",
    "Ondansetron",
    "Oseltamivir",
    "Pantoprazole",
    "Paracetamol",
    "Piroxicam",
    "Primaquine",
    "Quinine",
    "Remdesivir",
    "Taxim-O",
    "Valacyclovir",
    "Voveran",
    "Zinc supplements",
]


def upgrade() -> None:
    op.create_table(
        "reference_medicines",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_reference_medicines_name", "reference_medicines", ["name"], unique=True)

    ref = sa.table(
        "reference_medicines",
        sa.column("name", sa.String(length=255)),
        sa.column("sort_order", sa.Integer),
    )
    rows = [{"name": n, "sort_order": i} for i, n in enumerate(_REF_NAMES)]
    op.bulk_insert(ref, rows)


def downgrade() -> None:
    op.drop_index("ix_reference_medicines_name", table_name="reference_medicines")
    op.drop_table("reference_medicines")
