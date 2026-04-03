import os
import json
from sqlalchemy import create_engine, Column, Integer, String, text
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")
Base = declarative_base()

class CallSchedule(Base):
    __tablename__ = "call_schedules"
    id = Column(Integer, primary_key=True)
    phone = Column(String)
    times = Column(String)
    message = Column(String)
    audio_url = Column(String)
    call_type = Column(String)
    start_date = Column(String)
    end_date = Column(String)

def test():
    engine = create_engine(DATABASE_URL)
    Session = sessionmaker(bind=engine)
    db = Session()
    
    print("Testing INSERT without emojis...")
    try:
        new_call = CallSchedule(
            phone="+917020443880",
            times="08:00",
            message="Test message",
            call_type="text",
            start_date="2026-04-03",
            end_date="2026-04-04"
        )
        db.add(new_call)
        db.commit()
        print("INSERT SUCCESSFUL!")
        db.delete(new_call)
        db.commit()
    except Exception as e:
        print("INSERT FAILED:")
        print(str(e))
    finally:
        db.close()

if __name__ == "__main__":
    test()
