import os
import sys
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

def fix():
    if not DATABASE_URL:
        print("DATABASE_URL NOT FOUND")
        return

    print(f"CONNECTING TO: {DATABASE_URL[:30]}...")
    engine = create_engine(DATABASE_URL)
    
    with engine.connect() as conn:
        print("CHECKING EXISTING COLUMNS...")
        res = conn.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'call_schedules'"))
        existing = [r[0] for r in res]
        print(f"EXISTING: {existing}")
        
        cols = [
            ("call_type", "TEXT DEFAULT 'audio'"),
            ("start_date", "TEXT"),
            ("end_date", "TEXT"),
            ("audio_url", "TEXT"),
            ("message", "TEXT")
        ]
        
        for name, dtype in cols:
            if name not in existing:
                print(f"ADDING COLUMN: {name} ({dtype})...")
                try:
                    conn.execute(text(f"ALTER TABLE call_schedules ADD COLUMN {name} {dtype}"))
                    print(f"SUCCESS: {name}")
                except Exception as e:
                    print(f"FAILED: {name} - {e}")
            else:
                print(f"INFO: {name} already exists.")
        
        conn.commit()

if __name__ == "__main__":
    fix()
