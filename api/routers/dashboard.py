from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from core.auth import get_current_user
from db.database import get_db
from db.models.basal_logs import BasalLog
from db.models.bolus_log import BolusLog
from db.models.hypo_event import HypoEvent
from db.models.meal_log import MealLog
from db.models.user import User
from schemas.dashboard import DashboardResponse, LastDose

dashboard_router = APIRouter()


@dashboard_router.get("", response_model=DashboardResponse, summary="User dashboard summary")
def get_dashboard(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Aggregated stats for the authenticated user:
    - Insulin totals for today
    - Meal and bolus log counts for today
    - Hypo/basal/bolus counts for the last 7 days
    - Most recent basal and bolus doses
    """
    now = datetime.now(timezone.utc)
    start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    seven_days_ago = now - timedelta(days=7)

    uid = current_user.id

    # --- Today's insulin totals ---
    basal_today = (
        db.query(BasalLog)
        .filter(BasalLog.user_id == uid, BasalLog.timestamp >= start_of_today)
        .all()
    )
    bolus_today = (
        db.query(BolusLog)
        .filter(BolusLog.user_id == uid, BolusLog.timestamp >= start_of_today)
        .all()
    )

    basal_units_today = round(sum(b.units for b in basal_today), 2)
    bolus_units_today = round(sum(b.units for b in bolus_today), 2)

    # --- Meals today ---
    meals_today = (
        db.query(MealLog)
        .filter(MealLog.user_id == uid, MealLog.timestamp >= start_of_today)
        .count()
    )

    # --- Last 7 days counts ---
    hypo_last_7d = (
        db.query(HypoEvent)
        .filter(HypoEvent.user_id == uid, HypoEvent.started_at >= seven_days_ago)
        .count()
    )
    basal_last_7d = (
        db.query(BasalLog)
        .filter(BasalLog.user_id == uid, BasalLog.timestamp >= seven_days_ago)
        .count()
    )
    bolus_last_7d = (
        db.query(BolusLog)
        .filter(BolusLog.user_id == uid, BolusLog.timestamp >= seven_days_ago)
        .count()
    )

    # --- Most recent doses ---
    last_basal_row = (
        db.query(BasalLog)
        .filter(BasalLog.user_id == uid)
        .order_by(BasalLog.timestamp.desc())
        .first()
    )
    last_bolus_row = (
        db.query(BolusLog)
        .filter(BolusLog.user_id == uid)
        .order_by(BolusLog.timestamp.desc())
        .first()
    )

    last_basal = (
        LastDose(units=last_basal_row.units, timestamp=last_basal_row.timestamp, kind="basal")
        if last_basal_row
        else None
    )
    last_bolus = (
        LastDose(units=last_bolus_row.units, timestamp=last_bolus_row.timestamp, kind="bolus")
        if last_bolus_row
        else None
    )

    return DashboardResponse(
        basal_units_today=basal_units_today,
        bolus_units_today=bolus_units_today,
        total_insulin_today=round(basal_units_today + bolus_units_today, 2),
        meals_today=meals_today,
        bolus_logs_today=len(bolus_today),
        hypo_events_last_7d=hypo_last_7d,
        basal_logs_last_7d=basal_last_7d,
        bolus_logs_last_7d=bolus_last_7d,
        last_basal=last_basal,
        last_bolus=last_bolus,
    )
