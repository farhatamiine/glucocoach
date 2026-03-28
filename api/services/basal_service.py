from datetime import datetime, timedelta
from typing import List, Optional

from sqlalchemy import desc
from sqlalchemy.orm import Session

from core.logger import get_logger
from db.models.basal_logs import BasalLog
from schemas.basal import BasalCreate, BasalUpdate

logger = get_logger(__name__)


class BasalService:
    def __init__(self, db: Session) -> None:
        self.db = db

    def create_basal(self, payload: BasalCreate, user_id: int) -> BasalLog:
        basal = BasalLog(
            timestamp=payload.get_timestamp(),
            units=payload.units,
            insulin=payload.insulin,
            time=payload.time,
            notes=payload.notes,
            user_id=user_id,
        )
        try:
            self.db.add(basal)
            self.db.commit()
            self.db.refresh(basal)
            logger.info(
                f"Basal saved: {basal.units}u {basal.insulin} at {basal.timestamp}"
            )
            return basal
        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to save basal: {e}")
            raise

    def list_basals(self, user_id: int, limit: int = 20, days: int = 30) -> List[BasalLog]:
        cutoff = datetime.now() - timedelta(days=days)
        return (
            self.db.query(BasalLog)
            .filter(BasalLog.user_id == user_id, BasalLog.timestamp >= cutoff)
            .order_by(desc(BasalLog.timestamp))
            .limit(limit)
            .all()
        )

    def get_basal(self, basal_id: int, user_id: int) -> Optional[BasalLog]:
        return (
            self.db.query(BasalLog)
            .filter(BasalLog.id == basal_id, BasalLog.user_id == user_id)
            .first()
        )

    def update_basal(self, basal_id: int, payload: BasalUpdate, user_id: int) -> BasalLog:
        basal = self.get_basal(basal_id, user_id)
        if not basal:
            raise ValueError("Basal log not found")
        for field, value in payload.model_dump(exclude_none=True).items():
            setattr(basal, field, value)
        self.db.commit()
        self.db.refresh(basal)
        return basal

    def delete_basal(self, basal_id: int, user_id: int) -> None:
        basal = self.get_basal(basal_id, user_id)
        if not basal:
            raise ValueError("Basal log not found")
        self.db.delete(basal)
        self.db.commit()
