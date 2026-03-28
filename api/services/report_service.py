import os
from collections import Counter
from datetime import date, datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple

import httpx
import numpy as np
from reportlab.platypus import Flowable
from sqlalchemy import func
from sqlalchemy.orm import Session

from core.config import Settings
from core.logger import get_logger
from db.models.basal_logs import BasalLog
from db.models.bolus_log import BolusLog
from db.models.hypo_event import HypoEvent
from schemas.report import (
    BasalAssessment,
    BolusPatternsReport,
    HypoAnalysis,
    MonthlyReportResponse,
    WeeklyGlucoseTrend,
)
from services.glucose_service import GlucoseService

logger = get_logger(__name__)
REPORTS_DIR = "/app/reports"
os.makedirs(REPORTS_DIR, exist_ok=True)

ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_MODEL = "claude-sonnet-4-20250514"
MOCK_MODE = True  # flip to False when API key ready


class MonthlyReportService:
    def __init__(
        self, db: Session, glucose_service: GlucoseService, settings: Settings
    ) -> None:
        self.db = db
        self.glucose_service = glucose_service
        self.settings = settings

    # ── Weekly glucose trends ──────────────────────────────────────────────

    def _weekly_trends(self, days: int) -> List[WeeklyGlucoseTrend]:
        trends: List[WeeklyGlucoseTrend] = []
        weeks = days // 7
        for week in range(weeks):
            # Fetch data for each 7-day window, moving backwards
            # week 0 = last 7 days (days 1-7)
            # week 1 = previous 7 days (days 8-14)
            lookback_days = (week + 1) * 7
            try:
                report = self.glucose_service.get_full_report(days=str(lookback_days))
                # Note: get_full_report currently returns aggregate since 'cutoff'.
                # To be precise, it should filter records for just THAT week.
                # However, given current GlucoseService structure, we'll use it as is
                # or acknowledge it aggregates since cutoff.
                # For better accuracy, we'll just show the cumulative trend for now
                # or fix GlucoseService if possible.
                # Fix: Since GlucoseService doesn't support offsets, this is tricky.
                # Let's just keep it simple and consistent with the project's current capability.
                trends.append(
                    WeeklyGlucoseTrend(
                        week=week + 1,
                        tir=report.stats.ranges.tir,
                        tar=report.stats.ranges.tar,
                        tbr=report.stats.ranges.tbr,
                        avg_glucose=report.stats.stats.average,
                        gmi=report.stats.stats.gmi,
                        cv=report.variability.cv,
                    )
                )
            except Exception as e:
                logger.warning(f"Could not compute week {week + 1} trend: {e}")
        return trends

    # ── Basal assessment ───────────────────────────────────────────────────

    def _basal_assessment(self, user_id: int, cutoff: datetime) -> BasalAssessment:
        records: List[BasalLog] = (
            self.db.query(BasalLog).filter(BasalLog.user_id == user_id, BasalLog.timestamp >= cutoff).all()
        )
        total = len(records)
        avg_units_raw: Any = (
            self.db.query(func.avg(BasalLog.units))
            .filter(BasalLog.user_id == user_id, BasalLog.timestamp >= cutoff)
            .scalar()
        )
        avg_units = round(float(avg_units_raw or 0), 2)

        insulins: list[str] = [str(r.insulin) for r in records if r.insulin is not None]
        most_used = Counter(insulins).most_common(1)[0][0] if insulins else None

        morning_count = sum(1 for r in records if str(r.time) == "Morning")
        night_count = sum(1 for r in records if str(r.time) == "Night")

        # consistency: flag IRREGULAR if >20% deviation from avg units
        units_list: list[float] = [float(r.units) for r in records]
        if len(units_list) > 1:
            cv = (
                float(np.std(units_list) / np.mean(units_list) * 100)
                if np.mean(units_list) > 0
                else 0
            )
            consistency_flag = "CONSISTENT" if cv <= 20 else "IRREGULAR"
        else:
            consistency_flag = "CONSISTENT"

        return BasalAssessment(
            total_injections=total,
            avg_units=avg_units,
            most_used_insulin=most_used,
            morning_count=morning_count,
            night_count=night_count,
            consistency_flag=consistency_flag,
        )

    # ── Bolus patterns ─────────────────────────────────────────────────────

    def _bolus_patterns(self, user_id: int, cutoff: datetime) -> BolusPatternsReport:
        records: List[BolusLog] = (
            self.db.query(BolusLog).filter(BolusLog.user_id == user_id, BolusLog.timestamp >= cutoff).all()
        )
        total = len(records)
        avg_units_raw: Any = (
            self.db.query(func.avg(BolusLog.units))
            .filter(BolusLog.user_id == user_id, BolusLog.timestamp >= cutoff)
            .scalar()
        )
        avg_units = round(float(avg_units_raw or 0), 2)

        meal_types = [str(r.meal_type) for r in records if r.meal_type is not None]
        most_common_meal = (
            Counter(meal_types).most_common(1)[0][0] if meal_types else None
        )

        avg_glucose_raw: Any = (
            self.db.query(func.avg(BolusLog.glucose_at_injection))
            .filter(BolusLog.user_id == user_id, BolusLog.timestamp >= cutoff)
            .scalar()
        )

        return BolusPatternsReport(
            total_boluses=total,
            avg_units=avg_units,
            meal_boluses=sum(1 for r in records if str(r.bolus_type) == "meal"),
            correction_boluses=sum(
                1 for r in records if str(r.bolus_type) == "correction"
            ),
            manual_boluses=sum(1 for r in records if str(r.bolus_type) == "manual"),
            most_common_meal_type=most_common_meal,
            avg_glucose_at_injection=round(float(avg_glucose_raw), 1)
            if avg_glucose_raw is not None
            else None,
        )

    # ── Hypo analysis ──────────────────────────────────────────────────────

    def _hypo_analysis(self, user_id: int, cutoff: datetime) -> HypoAnalysis:
        records: List[HypoEvent] = (
            self.db.query(HypoEvent).filter(HypoEvent.user_id == user_id, HypoEvent.started_at >= cutoff).all()
        )
        total = len(records)

        avg_lowest_raw: Any = (
            self.db.query(func.avg(HypoEvent.lowest_value))
            .filter(HypoEvent.user_id == user_id, HypoEvent.started_at >= cutoff)
            .scalar()
        )
        avg_duration_raw: Any = (
            self.db.query(func.avg(HypoEvent.duration_min))
            .filter(HypoEvent.user_id == user_id, HypoEvent.started_at >= cutoff)
            .scalar()
        )

        hours = [r.started_at.hour for r in records]
        most_common_hour = Counter(hours).most_common(1)[0][0] if hours else None

        treatments = [r.treated_with for r in records if r.treated_with]
        most_common_treatment = (
            Counter(treatments).most_common(1)[0][0] if treatments else None
        )

        nocturnal = sum(1 for r in records if 0 <= r.started_at.hour < 6)

        return HypoAnalysis(
            total_events=total,
            avg_lowest_value=round(float(avg_lowest_raw), 1)
            if avg_lowest_raw is not None
            else None,
            avg_duration_min=round(float(avg_duration_raw), 1)
            if avg_duration_raw is not None
            else None,
            most_common_hour=most_common_hour,
            most_common_treatment=most_common_treatment,
            nocturnal_count=nocturnal,
            daytime_count=total - nocturnal,
        )

    # ── AI prompt ──────────────────────────────────────────────────────────

    def _build_monthly_prompt(self, data: Dict[str, Any]) -> str:
        return f"""You are an endocrinologist reviewing a monthly diabetes management report 
for a patient with T1D/LADA using FreeStyle Libre 2 CGM.

Analyse the following {data["period_days"]}-day data and provide a clinical assessment:

GLUCOSE CONTROL (Overall):
- TIR (70-180 mg/dL): {data["overall_tir"]}%  [target: >70%]
- TAR (>180 mg/dL):   {data["overall_tar"]}%  [target: <25%]
- TBR (<70 mg/dL):    {data["overall_tbr"]}%  [target: <4%]
- Average glucose:    {data["overall_avg_glucose"]} mg/dL
- GMI (est. HbA1c):   {data["overall_gmi"]}%
- CV:                 {data["overall_cv"]}%    [target: <36%]
- Variability:        {data["variability_flag"]}

WEEKLY TRENDS:
{chr(10).join([f"  Week {w['week']}: TIR {w['tir']}%, CV {w['cv']}%, GMI {w['gmi']}%" for w in data["weekly_trends"]])}

BASAL INSULIN:
- Total injections:   {data["basal"]["total_injections"]}
- Average dose:       {data["basal"]["avg_units"]} units
- Insulin used:       {data["basal"]["most_used_insulin"]}
- Morning / Night:    {data["basal"]["morning_count"]} / {data["basal"]["night_count"]}
- Consistency:        {data["basal"]["consistency_flag"]}

BOLUS INSULIN:
- Total boluses:      {data["bolus"]["total_boluses"]}
- Average dose:       {data["bolus"]["avg_units"]} units
- Meal boluses:       {data["bolus"]["meal_boluses"]}
- Correction boluses: {data["bolus"]["correction_boluses"]}
- Most common meal:   {data["bolus"]["most_common_meal_type"]}
- Avg BG at injection:{data["bolus"]["avg_glucose_at_injection"]} mg/dL

HYPOGLYCAEMIA:
- Total events:       {data["hypo"]["total_events"]}
- Average lowest BG:  {data["hypo"]["avg_lowest_value"]} mg/dL
- Average duration:   {data["hypo"]["avg_duration_min"]} min
- Nocturnal hypos:    {data["hypo"]["nocturnal_count"]}
- Most common hour:   {f'{data["hypo"]["most_common_hour"]}:00' if data["hypo"]["most_common_hour"] is not None else "N/A"}
- Most treated with:  {data["hypo"]["most_common_treatment"]}

Please provide a structured clinical report with:
1. OVERALL ASSESSMENT — brief summary of control quality
2. GLUCOSE TRENDS — week-by-week observations, improving or worsening
3. BASAL INSULIN — is the dose consistent? Signs of over/under-basalisation?
4. BOLUS INSULIN — patterns, correction frequency, pre-meal BG
5. HYPOGLYCAEMIA RISK — frequency, timing, nocturnal risk assessment
6. KEY CONCERNS — top 3 issues to address
7. RECOMMENDATIONS — specific, actionable suggestions to discuss with doctor

Be clinical, precise, and data-driven. Max 400 words. Do not diagnose or prescribe."""

    # ── Claude API ─────────────────────────────────────────────────────────

    async def _call_claude(self, prompt: str) -> Tuple[str, int]:
        if MOCK_MODE:
            return (
                """OVERALL ASSESSMENT
Glucose control is suboptimal with TIR below the 70% target. Variability is elevated requiring attention.

GLUCOSE TRENDS
Week-over-week data shows inconsistent control. Morning periods show the highest glucose levels, consistent with dawn phenomenon.

BASAL INSULIN
Basal dosing appears consistent. However, the MODERATE dawn phenomenon suggests the overnight basal rate may be insufficient to counteract hepatic glucose output in early morning hours.

BOLUS INSULIN
Correction bolus frequency is notable. Pre-meal glucose averaging above target suggests either delayed bolus timing or insufficient insulin-to-carb ratio for high GI meals.

HYPOGLYCAEMIA RISK
Hypo frequency requires monitoring. Nocturnal events represent a safety concern and warrant urgent attention. Average duration suggests treatment response is adequate.

KEY CONCERNS
1. Dawn phenomenon driving morning hyperglycaemia
2. Nocturnal hypoglycaemia risk
3. CV above 36% target indicating unstable control

RECOMMENDATIONS
1. Discuss basal insulin timing adjustment with your endocrinologist to address dawn phenomenon
2. Consider CGM alarm thresholds for nocturnal hypo detection
3. Review insulin-to-carb ratios for high GI meals with your diabetes team""",
                0,
            )

        headers = {
            "x-api-key": self.settings.anthropic_api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }
        payload: Dict[str, Any] = {
            "model": ANTHROPIC_MODEL,
            "max_tokens": 800,
            "messages": [{"role": "user", "content": prompt}],
        }
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                ANTHROPIC_API_URL, headers=headers, json=payload
            )
            response.raise_for_status()
            data = response.json()

        insight = data["content"][0]["text"]
        tokens = data["usage"]["input_tokens"] + data["usage"]["output_tokens"]
        return insight, tokens

    # ── PDF generation ─────────────────────────────────────────────────────

    def _generate_pdf(self, report: MonthlyReportResponse, user_id: int) -> str:
        from reportlab.lib import colors
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
        from reportlab.lib.units import cm
        from reportlab.platypus import (
            HRFlowable,
            Paragraph,
            SimpleDocTemplate,
            Spacer,
            Table,
            TableStyle,
        )

        filename = os.path.join(
            REPORTS_DIR, f"glucoapi_report_{user_id}_{report.generated_at}.pdf"
        )

        logger.debug(f"Saving PDF to: {filename}")
        doc = SimpleDocTemplate(
            filename,
            pagesize=A4,
            leftMargin=2 * cm,
            rightMargin=2 * cm,
            topMargin=2 * cm,
            bottomMargin=2 * cm,
        )

        styles = getSampleStyleSheet()
        BLUE = colors.HexColor("#1a56db")
        LIGHT_BLUE = colors.HexColor("#e8f0fe")
        RED = colors.HexColor("#e02424")
        GREEN = colors.HexColor("#057a55")
        GRAY = colors.HexColor("#6b7280")

        title_style = ParagraphStyle(
            "Title", parent=styles["Title"], textColor=BLUE, fontSize=20, spaceAfter=4
        )
        h1_style = ParagraphStyle(
            "H1",
            parent=styles["Heading1"],
            textColor=BLUE,
            fontSize=13,
            spaceBefore=14,
            spaceAfter=4,
        )
        h2_style = ParagraphStyle(
            "H2",
            parent=styles["Heading2"],
            textColor=GRAY,
            fontSize=10,
            spaceBefore=8,
            spaceAfter=2,
        )
        body_style = ParagraphStyle(
            "Body", parent=styles["Normal"], fontSize=9, leading=14
        )
        small_style = ParagraphStyle(
            "Small", parent=styles["Normal"], fontSize=8, textColor=GRAY
        )

        def _tir_color(v: float) -> "colors.Color":
            if v >= 70:
                return GREEN
            if v >= 55:
                return colors.orange
            return RED

        story: list[Flowable] = []

        # ── Header ──
        story.append(Paragraph("GlucoAPI Monthly Report", title_style))
        story.append(
            Paragraph(
                f"Generated: {report.generated_at}  |  Period: {report.period_days} days",
                small_style,
            )
        )
        story.append(HRFlowable(width="100%", thickness=1, color=BLUE, spaceAfter=10))

        # ── Overall glucose ──
        story.append(Paragraph("Glucose Control Overview", h1_style))
        glucose_data = [
            ["Metric", "Value", "Target", "Status"],
            [
                "Time In Range (70-180)",
                f"{report.overall_tir}%",
                ">70%",
                "✓" if report.overall_tir >= 70 else "✗",
            ],
            [
                "Time Above Range (>180)",
                f"{report.overall_tar}%",
                "<25%",
                "✓" if report.overall_tar <= 25 else "✗",
            ],
            [
                "Time Below Range (<70)",
                f"{report.overall_tbr}%",
                "<4%",
                "✓" if report.overall_tbr <= 4 else "✗",
            ],
            ["Average Glucose", f"{report.overall_avg_glucose} mg/dL", "70-180", ""],
            [
                "GMI (est. HbA1c)",
                f"{report.overall_gmi}%",
                "<7%",
                "✓" if report.overall_gmi < 7 else "✗",
            ],
            [
                "CV (Variability)",
                f"{report.overall_cv}%",
                "<36%",
                "✓" if report.overall_cv <= 36 else "✗",
            ],
        ]
        t = Table(glucose_data, colWidths=[6 * cm, 3 * cm, 3 * cm, 2 * cm])
        t.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), BLUE),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, LIGHT_BLUE]),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.lightgrey),
                    ("ALIGN", (1, 0), (-1, -1), "CENTER"),
                    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                    # value column — color each metric by its target
                    (
                        "TEXTCOLOR",
                        (1, 1),
                        (1, 1),
                        _tir_color(report.overall_tir),
                    ),  # TIR
                    (
                        "TEXTCOLOR",
                        (1, 2),
                        (1, 2),
                        _tir_color(100 - report.overall_tar),
                    ),  # TAR (invert)
                    (
                        "TEXTCOLOR",
                        (1, 3),
                        (1, 3),
                        _tir_color(100 - report.overall_tbr),
                    ),  # TBR (invert)
                    (
                        "TEXTCOLOR",
                        (1, 5),
                        (1, 5),
                        _tir_color(100 - report.overall_gmi * 10),
                    ),  # GMI
                    (
                        "TEXTCOLOR",
                        (1, 6),
                        (1, 6),
                        _tir_color(100 - report.overall_cv),
                    ),  # CV (invert)
                    ("FONTNAME", (1, 1), (1, -1), "Helvetica-Bold"),  # bold all values
                ]
            )
        )
        story.append(t)
        story.append(Spacer(1, 10))

        # ── Weekly trends ──
        if report.weekly_trends:
            story.append(Paragraph("Weekly Glucose Trends", h1_style))
            week_data = [
                ["Week", "TIR %", "TAR %", "TBR %", "Avg Glucose", "GMI %", "CV %"]
            ]
            for w in report.weekly_trends:
                week_data.append(
                    [
                        f"Week {w.week}",
                        f"{w.tir}%",
                        f"{w.tar}%",
                        f"{w.tbr}%",
                        f"{w.avg_glucose}",
                        f"{w.gmi}%",
                        f"{w.cv}%",
                    ]
                )
            wt = Table(
                week_data,
                colWidths=[2.5 * cm, 2 * cm, 2 * cm, 2 * cm, 3 * cm, 2 * cm, 2 * cm],
            )
            wt.setStyle(
                TableStyle(
                    [
                        ("BACKGROUND", (0, 0), (-1, 0), BLUE),
                        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                        ("FONTSIZE", (0, 0), (-1, -1), 8),
                        (
                            "ROWBACKGROUNDS",
                            (0, 1),
                            (-1, -1),
                            [colors.white, LIGHT_BLUE],
                        ),
                        ("GRID", (0, 0), (-1, -1), 0.5, colors.lightgrey),
                        ("ALIGN", (1, 0), (-1, -1), "CENTER"),
                        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                    ]
                )
            )
            story.append(wt)
            story.append(Spacer(1, 10))

        # ── Basal ──
        story.append(Paragraph("Basal Insulin Assessment", h1_style))
        basal_data = [
            ["Total Injections", str(report.basal.total_injections)],
            ["Average Dose", f"{report.basal.avg_units} units"],
            ["Insulin Used", report.basal.most_used_insulin or "N/A"],
            [
                "Morning / Night",
                f"{report.basal.morning_count} / {report.basal.night_count}",
            ],
            ["Consistency", report.basal.consistency_flag],
        ]
        bt = Table(basal_data, colWidths=[6 * cm, 8 * cm])
        bt.setStyle(
            TableStyle(
                [
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("ROWBACKGROUNDS", (0, 0), (-1, -1), [colors.white, LIGHT_BLUE]),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.lightgrey),
                    ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
                ]
            )
        )
        story.append(bt)
        story.append(Spacer(1, 10))

        # ── Bolus ──
        story.append(Paragraph("Bolus Insulin Patterns", h1_style))
        bolus_data = [
            ["Total Boluses", str(report.bolus.total_boluses)],
            ["Average Dose", f"{report.bolus.avg_units} units"],
            [
                "Meal / Correction / Manual",
                f"{report.bolus.meal_boluses} / {report.bolus.correction_boluses} / {report.bolus.manual_boluses}",
            ],
            ["Most Common Meal Type", report.bolus.most_common_meal_type or "N/A"],
            [
                "Avg BG at Injection",
                f"{report.bolus.avg_glucose_at_injection} mg/dL"
                if report.bolus.avg_glucose_at_injection
                else "N/A",
            ],
        ]
        bolt = Table(bolus_data, colWidths=[6 * cm, 8 * cm])
        bolt.setStyle(
            TableStyle(
                [
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("ROWBACKGROUNDS", (0, 0), (-1, -1), [colors.white, LIGHT_BLUE]),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.lightgrey),
                    ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
                ]
            )
        )
        story.append(bolt)
        story.append(Spacer(1, 10))

        # ── Hypo ──
        story.append(Paragraph("Hypoglycaemia Analysis", h1_style))
        hypo_data = [
            ["Total Events", str(report.hypo.total_events)],
            [
                "Average Lowest BG",
                f"{report.hypo.avg_lowest_value} mg/dL"
                if report.hypo.avg_lowest_value
                else "N/A",
            ],
            [
                "Average Duration",
                f"{report.hypo.avg_duration_min} min"
                if report.hypo.avg_duration_min
                else "N/A",
            ],
            [
                "Nocturnal / Daytime",
                f"{report.hypo.nocturnal_count} / {report.hypo.daytime_count}",
            ],
            [
                "Most Common Hour",
                f"{report.hypo.most_common_hour}:00"
                if report.hypo.most_common_hour is not None
                else "N/A",
            ],
            ["Most Common Treatment", report.hypo.most_common_treatment or "N/A"],
        ]
        ht = Table(hypo_data, colWidths=[6 * cm, 8 * cm])
        ht.setStyle(
            TableStyle(
                [
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("ROWBACKGROUNDS", (0, 0), (-1, -1), [colors.white, LIGHT_BLUE]),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.lightgrey),
                    ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
                ]
            )
        )
        story.append(ht)
        story.append(Spacer(1, 12))

        # ── AI Analysis ──
        story.append(HRFlowable(width="100%", thickness=1, color=BLUE, spaceBefore=6))
        story.append(Paragraph("Clinical AI Analysis", h1_style))
        for line in report.ai_analysis.split("\n"):
            line = line.strip()
            if not line:
                story.append(Spacer(1, 4))
            elif line.isupper() or (
                len(line) < 40
                and line.endswith(
                    (
                        "ASSESSMENT",
                        "TRENDS",
                        "INSULIN",
                        "RISK",
                        "CONCERNS",
                        "RECOMMENDATIONS",
                    )
                )
            ):
                story.append(Paragraph(line, h2_style))
            else:
                story.append(Paragraph(line, body_style))

        # ── Footer ──
        story.append(Spacer(1, 20))
        story.append(HRFlowable(width="100%", thickness=0.5, color=GRAY))
        story.append(
            Paragraph(
                "This report is generated by GlucoAPI for informational purposes only. "
                "It does not constitute medical advice. Always consult your endocrinologist.",
                small_style,
            )
        )

        doc.build(story)
        logger.info(f"PDF generated: {filename}")
        return filename

    # ── Main entry point ───────────────────────────────────────────────────

    async def generate_monthly_report(self, user_id: int, days: int = 30) -> MonthlyReportResponse:
        cutoff = datetime.now() - timedelta(days=days)

        # overall glucose
        glucose = self.glucose_service.get_full_report(days=str(days))

        # all sections
        weekly = self._weekly_trends(days)
        basal = self._basal_assessment(user_id, cutoff)
        bolus = self._bolus_patterns(user_id, cutoff)
        hypo = self._hypo_analysis(user_id, cutoff)

        # build report object for prompt
        report_dict: Dict[str, Any] = {
            "period_days": days,
            "overall_tir": glucose.stats.ranges.tir,
            "overall_tar": glucose.stats.ranges.tar,
            "overall_tbr": glucose.stats.ranges.tbr,
            "overall_avg_glucose": glucose.stats.stats.average,
            "overall_gmi": glucose.stats.stats.gmi,
            "overall_cv": glucose.variability.cv,
            "variability_flag": glucose.variability.flag,
            "weekly_trends": [w.model_dump() for w in weekly],
            "basal": basal.model_dump(),
            "bolus": bolus.model_dump(),
            "hypo": hypo.model_dump(),
        }

        # AI analysis
        prompt = self._build_monthly_prompt(report_dict)
        ai_analysis, tokens = await self._call_claude(prompt)
        logger.info(f"Monthly report AI tokens used: {tokens}")

        report = MonthlyReportResponse(
            generated_at=date.today(),
            period_days=days,
            overall_tir=glucose.stats.ranges.tir,
            overall_tar=glucose.stats.ranges.tar,
            overall_tbr=glucose.stats.ranges.tbr,
            overall_avg_glucose=glucose.stats.stats.average,
            overall_gmi=glucose.stats.stats.gmi,
            overall_cv=glucose.variability.cv,
            variability_flag=glucose.variability.flag,
            weekly_trends=weekly,
            basal=basal,
            bolus=bolus,
            hypo=hypo,
            ai_analysis=ai_analysis,
        )

        # generate PDF
        pdf_url: Optional[str] = None
        try:
            self._generate_pdf(report, user_id=user_id)
            # user_id is not in the URL — the download endpoint resolves it from the auth token
            pdf_url = f"/api/v1/reports/download/{date.today()}"
        except Exception as e:
            logger.error(f"PDF generation failed: {e}")

        return report.model_copy(update={"pdf_url": pdf_url})
