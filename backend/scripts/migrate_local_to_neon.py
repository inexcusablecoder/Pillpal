"""
Copy all rows from a local/source Postgres into the target DB (Neon) from backend/.env.

Usage (from the backend/ directory):

  $env:SOURCE_DATABASE_URL="postgresql://USER:PASSWORD@127.0.0.1:5432/PillPal"
  py scripts/migrate_local_to_neon.py

Password with @ in it must be URL-encoded (%40). Truncates target tables first (Neon).
"""

from __future__ import annotations

import os
import sys

# backend/ on path
_BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _BACKEND not in sys.path:
    sys.path.insert(0, _BACKEND)
os.chdir(_BACKEND)

import psycopg2
from psycopg2.extras import execute_batch

from app.core.config import settings


def _connect(url: str):
    return psycopg2.connect(url)


def main() -> None:
    source_url = os.environ.get("SOURCE_DATABASE_URL", "").strip()
    if not source_url:
        print(
            "Set SOURCE_DATABASE_URL to your local Postgres, e.g.\n"
            '  $env:SOURCE_DATABASE_URL="postgresql://postgres:YOURPASS@127.0.0.1:5432/PillPal"',
            file=sys.stderr,
        )
        sys.exit(1)

    target_url = settings.database_url
    if not target_url.startswith("postgresql://"):
        print("Target DATABASE_URL in .env must use postgresql://", file=sys.stderr)
        sys.exit(1)

    print("Source (local):", source_url.split("@", 1)[-1])
    print("Target (cloud):", target_url.split("@", 1)[-1])

    src = _connect(source_url)
    dst = _connect(target_url)
    try:
        with dst.cursor() as c:
            c.execute("TRUNCATE dose_logs, medicines, users CASCADE;")
        dst.commit()
        print("Truncated target tables (dose_logs, medicines, users).")

        tables = [
            (
                "users",
                "id, email, password_hash, display_name, created_at",
            ),
            (
                "medicines",
                "id, user_id, name, dosage, scheduled_time, frequency, active, pill_count, created_at",
            ),
            (
                "dose_logs",
                "id, user_id, medicine_id, scheduled_date, scheduled_time, status, taken_at, created_at",
            ),
        ]

        with src.cursor() as sc, dst.cursor() as dc:
            for table, cols in tables:
                sc.execute(f"SELECT {cols} FROM {table}")
                rows = sc.fetchall()
                placeholders = ", ".join(["%s"] * len(cols.split(", ")))
                sql = f"INSERT INTO {table} ({cols}) VALUES ({placeholders})"
                execute_batch(dc, sql, rows, page_size=500)
                print(f"  Copied {len(rows)} rows -> {table}")

        dst.commit()
        print("Done. You can log in on the API using the same email/password as on local.")
    finally:
        src.close()
        dst.close()


if __name__ == "__main__":
    main()
