from collections import defaultdict
from datetime import datetime, timedelta
from typing import Any, Dict, List

from sqlalchemy.orm import Session

from db.models.meal_log import MealLog
from schemas.meal_log import MealCreate


class MealService:
    def __init__(self, db: Session):
        self.db = db

    def create_meal(self, payload: MealCreate, user_id: int) -> MealLog:
        meal = MealLog(user_id=user_id, **payload.model_dump())
        self.db.add(meal)
        self.db.commit()
        self.db.refresh(meal)
        return meal

    def update_peak(self, meal_id: int, glucose_peak: float, user_id: int) -> MealLog:
        meal = (
            self.db.query(MealLog)
            .filter(MealLog.id == meal_id, MealLog.user_id == user_id)
            .first()
        )
        if not meal:
            raise ValueError("Meal not found")
        meal.glucose_peak = glucose_peak
        # Auto-calculate result from delta
        if meal.glucose_before:
            delta = glucose_peak - meal.glucose_before
            # delta is in mg/dL
            meal.result = "spike" if delta > 70 else "low" if delta < -18 else "stable"
        self.db.commit()
        self.db.refresh(meal)
        return meal

    def list_meals(
        self, user_id: int, limit: int = 20, days: int = 30
    ) -> List[MealLog]:
        cutoff = datetime.now() - timedelta(days=days)
        return (
            self.db.query(MealLog)
            .filter(MealLog.user_id == user_id, MealLog.timestamp >= cutoff)
            .order_by(MealLog.timestamp.desc())
            .limit(limit)
            .all()
        )

    def get_meal(self, meal_id: int, user_id: int) -> MealLog | None:
        return (
            self.db.query(MealLog)
            .filter(MealLog.id == meal_id, MealLog.user_id == user_id)
            .first()
        )

    def delete_meal(self, meal_id: int, user_id: int) -> None:
        meal = self.get_meal(meal_id, user_id)
        if not meal:
            raise ValueError("Meal not found")
        self.db.delete(meal)
        self.db.commit()

    def get_correlation(self, user_id: int, days: int = 14) -> List[Dict[str, Any]]:
        """
        Returns average glucose spike per meal type.
        This is the GlucoCoach key insight feature.
        """
        cutoff = datetime.now() - timedelta(days=days)
        records = (
            self.db.query(MealLog)
            .filter(
                MealLog.user_id == user_id,
                MealLog.timestamp >= cutoff,
                MealLog.glucose_before.isnot(None),
                MealLog.glucose_peak.isnot(None),
            )
            .all()
        )

        by_type: defaultdict[str, List[float]] = defaultdict(list)
        for r in records:
            if r.glucose_peak is not None and r.glucose_before is not None:
                by_type[r.meal_type].append(r.glucose_peak - r.glucose_before)

        return [
            {
                "meal_type": k,
                "avg_spike": round(sum(v) / len(v), 1),
                "sample_count": len(v),
            }
            for k, v in by_type.items()
        ]
