from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class LastDose(BaseModel):
    units: float
    timestamp: datetime
    kind: str  # "basal" or "bolus"


class DashboardResponse(BaseModel):
    # Insulin today
    basal_units_today: float
    bolus_units_today: float
    total_insulin_today: float

    # Logs today
    meals_today: int
    bolus_logs_today: int

    # Last 7 days
    hypo_events_last_7d: int
    basal_logs_last_7d: int
    bolus_logs_last_7d: int

    # Most recent doses
    last_basal: Optional[LastDose]
    last_bolus: Optional[LastDose]
