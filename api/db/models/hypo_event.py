from typing import Optional

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from db.database import Base


class HypoEvent(Base):
    __tablename__ = "hypo_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    lowest_value = Column(Float(3), nullable=False)
    started_at = Column(DateTime, nullable=False)
    ended_at = Column(DateTime, nullable=True)
    duration_min = Column(Integer, nullable=True)
    recovery_min = Column(Integer, nullable=True)
    treated_with: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    notes = Column(String, nullable=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
