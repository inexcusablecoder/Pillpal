import os
import json
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

def check():
    if not DATABASE_URL:
        print("❌ DATABASE_URL not found")
        return
    
    engine = create_engine(DATABASE_URL)
    with engine.connect() as conn:
        res = conn.execute(text("SELECT * FROM call_schedules ORDER BY id DESC LIMIT 10"))
        data = [dict(r._mapping) for r in res]
        print(json.dumps(data, indent=2))

if __name__ == "__main__":
    check()
