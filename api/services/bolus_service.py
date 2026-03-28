from datetime import datetime, timedelta
from typing import List, Optional

from sqlalchemy import desc
from sqlalchemy.orm import Session

from core.logger import get_logger
from db.models.bolus_log import BolusLog
from schemas.bolus import BolusCreate, BolusUpdate
from services.glucose_service import GlucoseService

logger = get_logger(__name__)


class BolusService:
    def __init__(self, db: Session, glucose_service: GlucoseService) -> None:
        self.db = db
        self.glucose_service = glucose_service

    def create_bolus(self, payload: BolusCreate, user_id: int) -> BolusLog:
        """Persist a bolus event to the database."""

        if payload.glucose_at_injection is None:
            try:
                glucose = self.glucose_service.get_current()["sgv"]
            except Exception:
                glucose = None
        else:
            glucose = payload.glucose_at_injection

        bolus = BolusLog(
            timestamp=payload.get_timestamp(),
            units=payload.units,
            bolus_type=payload.bolus_type,
            meal_type=payload.meal_type,
            glucose_at_injection=glucose,
            inject_to_meal_min=payload.inject_to_meal_min,
            notes=payload.notes,
            user_id=user_id,
        )
        try:
            self.db.add(bolus)
            self.db.commit()
            self.db.refresh(bolus)
            logger.info(
                f"Bolus saved: {bolus.units}u {bolus.bolus_type} at {bolus.timestamp}"
            )
            return bolus
        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to save bolus: {e}")
            raise

    def list_boluses(self, user_id: int, limit: int = 20, days: int = 30) -> List[BolusLog]:
        cutoff = datetime.now() - timedelta(days=days)
        return (
            self.db.query(BolusLog)
            .filter(BolusLog.user_id == user_id, BolusLog.timestamp >= cutoff)
            .order_by(desc(BolusLog.timestamp))
            .limit(limit)
            .all()
        )

    def get_bolus(self, bolus_id: int, user_id: int) -> Optional[BolusLog]:
        return (
            self.db.query(BolusLog)
            .filter(BolusLog.id == bolus_id, BolusLog.user_id == user_id)
            .first()
        )

    def update_bolus(self, bolus_id: int, payload: BolusUpdate, user_id: int) -> BolusLog:
        bolus = self.get_bolus(bolus_id, user_id)
        if not bolus:
            raise ValueError("Bolus log not found")
        for field, value in payload.model_dump(exclude_none=True).items():
            setattr(bolus, field, value)
        self.db.commit()
        self.db.refresh(bolus)
        return bolus

    def delete_bolus(self, bolus_id: int, user_id: int) -> None:
        bolus = self.get_bolus(bolus_id, user_id)
        if not bolus:
            raise ValueError("Bolus log not found")
        self.db.delete(bolus)
        self.db.commit()
