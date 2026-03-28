from datetime import datetime
from typing import List

from sqlalchemy import desc
from sqlalchemy.orm import Session

from core.logger import get_logger
from db.models.hypo_event import HypoEvent
from schemas.hypo import HypoCreate, HypoUpdate
from services.glucose_service import GlucoseService

logger = get_logger(__name__)


class HypoService:
    def __init__(self, db: Session, glucose_service: GlucoseService) -> None:
        self.db = db
        self.glucose_service = glucose_service

    def create_hypo(self, payload: HypoCreate, user_id: int) -> HypoEvent:
        # auto-detect ended_at if not provided
        ended_at = payload.ended_at
        if ended_at is None:
            ended_at = self.detect_hypo_end(payload.started_at)

        # auto-calc duration if we have both times
        duration_min = payload.duration_min
        if ended_at and duration_min is None:
            delta = ended_at - payload.started_at
            duration_min = max(0, int(delta.total_seconds() / 60))

        hypo = HypoEvent(
            lowest_value=payload.lowest_value,
            started_at=payload.started_at,
            ended_at=ended_at,
            duration_min=duration_min,
            recovery_min=payload.recovery_min,
            treated_with=payload.treated_with,
            notes=payload.notes,
            user_id=user_id,
        )
        try:
            self.db.add(hypo)
            self.db.commit()
            self.db.refresh(hypo)
            logger.info(
                f"Hypo logged: {hypo.lowest_value} mg/dL, duration: {hypo.duration_min} min"
            )
            return hypo
        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to save hypo: {e}")
            raise

    def get_hypo(self, hypo_id: int, user_id: int) -> HypoEvent | None:
        return (
            self.db.query(HypoEvent)
            .filter(HypoEvent.id == hypo_id, HypoEvent.user_id == user_id)
            .first()
        )

    def update_hypo(self, hypo_id: int, payload: HypoUpdate, user_id: int) -> HypoEvent:
        hypo = self.get_hypo(hypo_id, user_id)
        if not hypo:
            raise ValueError("Hypo event not found")
        for field, value in payload.model_dump(exclude_none=True).items():
            setattr(hypo, field, value)
        self.db.commit()
        self.db.refresh(hypo)
        return hypo

    def delete_hypo(self, hypo_id: int, user_id: int) -> None:
        hypo = self.get_hypo(hypo_id, user_id)
        if not hypo:
            raise ValueError("Hypo event not found")
        self.db.delete(hypo)
        self.db.commit()

    def list_hypos(self, user_id: int, limit: int = 20) -> List[HypoEvent]:
        return (
            self.db.query(HypoEvent)
            .filter(HypoEvent.user_id == user_id)
            .order_by(desc(HypoEvent.started_at))
            .limit(limit)
            .all()
        )

    def detect_hypo_end(self, started_at: datetime) -> datetime | None:
        """
        Scans Nightscout readings after started_at to find
        the first reading where sgv >= 80 (safe recovery threshold).
        Returns that timestamp or None if still ongoing.
        """
        try:
            records = self.glucose_service.fetch_nightscout_data(days="1")
        except Exception as e:
            logger.warning(
                f"Could not fetch Nightscout data for hypo end detection: {e}"
            )
            return None

        # filter to readings AFTER hypo started, sorted oldest first
        after = sorted(
            [
                r
                for r in records
                if datetime.fromisoformat(r["dateString"]) > started_at
            ],
            key=lambda r: r["dateString"],
        )

        for r in after:
            if int(r["sgv"]) >= 80:
                return datetime.fromisoformat(r["dateString"])

        return None  # still ongoing
