from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from core.config import get_settings

settings = get_settings()

engine = create_engine(url=settings.database_url)

SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)


class Base(DeclarativeBase):
    pass


def create_tables():
    print("✅ Creating tables")
    import db.models.basal_logs
    import db.models.bolus_log
    import db.models.cognitive_sessions
    import db.models.hypo_event
    import db.models.meal_log
    import db.models.summary
    import db.models.user

    Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def check_connection():
    try:
        with engine.connect() as conn:
            print(f"✅ Database connected successfully {conn}")
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
