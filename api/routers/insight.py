from fastapi import APIRouter, Depends, HTTPException

from core.auth import get_current_user
from core.dependencies import get_insights_service
from schemas.insight import WeeklyInsightRequest, WeeklyInsightResponse
from services.insight_service import InsightsService

insights_router = APIRouter()


@insights_router.post(
    "/analyse",
    response_model=WeeklyInsightResponse,
    summary="Generate AI-powered weekly glucose insight",
)
async def analyse(
    payload: WeeklyInsightRequest = WeeklyInsightRequest(),
    current_user=Depends(get_current_user),
    service: InsightsService = Depends(get_insights_service),
):
    """
    Generates a weekly AI insight using Claude.

    - Automatically caches result in DB — only calls API once per day
    - Sends only aggregated metrics (not raw CGM data) to minimise token cost
    - Returns `cached: true` with no API cost if called multiple times today
    """
    try:
        result = await service.get_weekly_insight(user_id=current_user.id, days=payload.days)
        return WeeklyInsightResponse(**result)
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
