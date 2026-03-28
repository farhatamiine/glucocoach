from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from db.database import Base


class BasalLog(Base):
    __tablename__ = "basal_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    units: Mapped[float] = mapped_column(Float(4), nullable=False)
    insulin: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    time: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    timestamp: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.now(timezone.utc)
    )
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
