from typing import Any, Dict

from fastapi import APIRouter, Depends, HTTPException, Query

from core.auth import get_current_user
from core.dependencies import get_glucose_service
from db.models.user import User
from schemas.glucose import GlucoseFullReport
from services.glucose_service import GlucoseService
from utils.glucose import calculate_bmi

glucose_router = APIRouter()


@glucose_router.get("/report", response_model=GlucoseFullReport)
def get_report(
    days: str = Query(default="4", description="Number of past days to look back"),
    current_user: User = Depends(get_current_user),
    service: GlucoseService = Depends(get_glucose_service),
):
    """
    Generates a full report including stats, variability, patterns, and dawn phenomenon analysis.
    """
    try:
        return service.get_full_report(days=days)
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))


@glucose_router.post("/analyse")
def analyse(current_user: User = Depends(get_current_user)) -> Dict[str, Any]:
    """
    Analyzes user-specific data like BMI.
    """
    return {
        "user": current_user.email,
        "bmi": calculate_bmi(current_user),
        "glucose_unit": current_user.glucose_unit,
    }
