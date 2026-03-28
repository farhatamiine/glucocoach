from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from db.database import Base


class BolusLog(Base):
    __tablename__ = "bolus_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    units: Mapped[float] = mapped_column(Float(2), nullable=False)
    meal_type: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    glucose_at_injection: Mapped[Optional[float]] = mapped_column(Float(2), nullable=True)
    bolus_type: Mapped[str] = mapped_column(String(50), default="manual", nullable=False)
    inject_to_meal_min: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    timestamp: Mapped[datetime] = mapped_column(DateTime, default=datetime.now(timezone.utc))
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
