from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from db.database import Base


class MealLog(Base):
    __tablename__ = "meal_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    meal_type: Mapped[str] = mapped_column(String, nullable=False)
    carbs_g: Mapped[Optional[float]] = mapped_column(Float(3), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    glucose_before: Mapped[Optional[float]] = mapped_column(Float(3), nullable=True)
    glucose_peak: Mapped[Optional[float]] = mapped_column(Float(3), nullable=True)
    result: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    timestamp: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.now(timezone.utc)
    )
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id"), nullable=False
    )
