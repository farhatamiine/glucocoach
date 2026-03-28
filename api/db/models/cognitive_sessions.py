from sqlalchemy import Column, DateTime, Float, Integer, String

from db.database import Base


class CognitiveSession(Base):
    __tablename__ = "cognitive_sessions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    started_at = Column(DateTime, nullable=False)
    ended_at = Column(DateTime, nullable=True)
    duration_min = Column(Integer, nullable=True)
    glucose_start = Column(Float(4), nullable=True)
    glucose_end = Column(Float(4), nullable=True)
    delta = Column(Float(4), nullable=True)
    water_ml = Column(Integer, nullable=True)
    tag = Column(String, nullable=True)  # stable/cortisol_spike/hypo
