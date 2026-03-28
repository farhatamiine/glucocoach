from datetime import date
from typing import List, Optional

from pydantic import BaseModel, Field

# ── Weekly breakdown ───────────────────────────────────────────────────────


class WeeklyGlucoseTrend(BaseModel):
    week: int = Field(..., description="Week number (1-4)")
    tir: float
    tar: float
    tbr: float
    avg_glucose: float
    gmi: float
    cv: float


# ── Basal assessment ───────────────────────────────────────────────────────


class BasalAssessment(BaseModel):
    total_injections: int
    avg_units: float
    most_used_insulin: Optional[str]
    morning_count: int
    night_count: int
    consistency_flag: str  # CONSISTENT | IRREGULAR


# ── Bolus patterns ─────────────────────────────────────────────────────────


class BolusPatternsReport(BaseModel):
    total_boluses: int
    avg_units: float
    meal_boluses: int
    correction_boluses: int
    manual_boluses: int
    most_common_meal_type: Optional[str]
    avg_glucose_at_injection: Optional[float]


# ── Hypo analysis ──────────────────────────────────────────────────────────


class HypoAnalysis(BaseModel):
    total_events: int
    avg_lowest_value: Optional[float]
    avg_duration_min: Optional[float]
    most_common_hour: Optional[int]  # hour of day hypos most often start
    most_common_treatment: Optional[str]
    nocturnal_count: int  # 00:00-06:00
    daytime_count: int  # 06:00-00:00


# ── Full monthly report ────────────────────────────────────────────────────


class MonthlyReportResponse(BaseModel):
    generated_at: date
    period_days: int

    # glucose
    overall_tir: float
    overall_tar: float
    overall_tbr: float
    overall_avg_glucose: float
    overall_gmi: float
    overall_cv: float
    variability_flag: str
    weekly_trends: List[WeeklyGlucoseTrend]

    # treatments
    basal: BasalAssessment
    bolus: BolusPatternsReport
    hypo: HypoAnalysis

    # AI
    ai_analysis: str
    pdf_url: Optional[str] = Field(
        default=None, description="Download URL for PDF report"
    )
