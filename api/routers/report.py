import os
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import FileResponse

from core.auth import get_current_user
from core.dependencies import get_monthly_report_service
from db.models.user import User
from schemas.report import MonthlyReportResponse
from services.report_service import REPORTS_DIR, MonthlyReportService

reports_router = APIRouter()


@reports_router.post(
    "/monthly",
    response_model=MonthlyReportResponse,
    summary="Generate full monthly diabetes report (JSON + PDF)",
)
async def generate_monthly_report(
    days: int = Query(default=30, ge=7, le=90, description="Lookback period in days"),
    current_user=Depends(get_current_user),
    service: MonthlyReportService = Depends(get_monthly_report_service),
):
    """
    Generates a comprehensive monthly diabetes management report including:
    - Weekly glucose trends (TIR, GMI, CV week by week)
    - Basal insulin assessment (consistency, dosing)
    - Bolus patterns (meal types, correction frequency)
    - Hypo analysis (frequency, timing, nocturnal risk)
    - AI clinical analysis powered by Claude
    - PDF download URL
    """
    try:
        return await service.generate_monthly_report(user_id=current_user.id, days=days)
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@reports_router.get(
    "/download/{report_date}",
    summary="Download PDF report",
    response_class=FileResponse,
)
def download_report(
    report_date: date,
    current_user: User = Depends(get_current_user),
):
    """Download the generated PDF report for a given date."""
    path = os.path.join(REPORTS_DIR, f"glucoapi_report_{current_user.id}_{report_date.isoformat()}.pdf")
    if not os.path.exists(path):
        raise HTTPException(
            status_code=404, detail="Report not found. Generate it first."
        )
    return FileResponse(
        path=path,
        media_type="application/pdf",
        filename=f"glucoapi_report_{report_date}.pdf",
    )
