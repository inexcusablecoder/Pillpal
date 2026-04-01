"""Usage: set DATABASE_URL, then py scripts/verify_tables.py"""
import os
import sys

import psycopg2

url = os.environ.get("DATABASE_URL")
if not url:
    sys.exit("Set DATABASE_URL")
conn = psycopg2.connect(url)
cur = conn.cursor()
cur.execute(
    "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY 1"
)
print("Tables:", [r[0] for r in cur.fetchall()])
cur.execute("SELECT version_num FROM alembic_version")
print("Alembic:", cur.fetchone())
conn.close()
