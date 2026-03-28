from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, Optional

import httpx
from sqlalchemy import func
from sqlalchemy.orm import Session

from core.config import Settings
from core.logger import get_logger
from db.models.bolus_log import BolusLog
from db.models.hypo_event import HypoEvent
from db.models.summary import DailySummary
from services.glucose_service import GlucoseService
from services.meal_service import MealService

logger = get_logger(__name__)

ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_MODEL = "claude-sonnet-4-20250514"
MOCK_MODE = True


class InsightsService:
    def __init__(
        self,
        db: Session,
        glucose_service: GlucoseService,
        meal_service: MealService,
        settings: Settings,
    ) -> None:
        self.db = db
        self.glucose_service = glucose_service
        self.meal_service = meal_service
        self.settings = settings

    # ── Cache check ────────────────────────────────────────────────────────

    def _get_cached_insight(self, user_id: int) -> Optional[DailySummary]:
        """Return today's summary if it already has an AI insight."""
        return (
            self.db.query(DailySummary)
            .filter(
                DailySummary.user_id == user_id,
                DailySummary.date == date.today(),
                DailySummary.ai_insight.isnot(None),
            )
            .first()
        )

    # ── Data aggregation ───────────────────────────────────────────────────

    def _build_lean_summary(self, user_id: int, days: int) -> Dict[str, Any]:
        """
        Aggregate all data into a small dict.
        NEVER sends raw CGM readings — only computed metrics.
        """
        glucose_report = self.glucose_service.get_full_report(days=str(days))
        cutoff = datetime.now(timezone.utc) - timedelta(days=days)
        meal_correlation = self.meal_service.get_correlation(user_id, days=days)

        # hypo stats from DB
        hypo_count = (
            self.db.query(func.count(HypoEvent.id))
            .filter(HypoEvent.user_id == user_id, HypoEvent.started_at >= cutoff)
            .scalar()
            or 0
        )
        avg_hypo_duration = (
            self.db.query(func.avg(HypoEvent.duration_min))
            .filter(HypoEvent.user_id == user_id, HypoEvent.started_at >= cutoff)
            .scalar()
        )

        # bolus stats from DB
        bolus_count = (
            self.db.query(func.count(BolusLog.id))
            .filter(BolusLog.user_id == user_id, BolusLog.timestamp >= cutoff)
            .scalar()
            or 0
        )
        avg_bolus_units = (
            self.db.query(func.avg(BolusLog.units))
            .filter(BolusLog.user_id == user_id, BolusLog.timestamp >= cutoff)
            .scalar()
        )

        return {
            "period_days": days,
            "tir": glucose_report.stats.ranges.tir,
            "tar": glucose_report.stats.ranges.tar,
            "tbr": glucose_report.stats.ranges.tbr,
            "avg_glucose_mgdl": glucose_report.stats.stats.average,
            "gmi": glucose_report.stats.stats.gmi,
            "cv": glucose_report.variability.cv,
            "std_dev": glucose_report.variability.std_dev,
            "variability_flag": glucose_report.variability.flag,
            "worst_period": glucose_report.patterns.worst_period,
            "dawn_phenomenon": glucose_report.dawn_phenomenon.flag,
            "dawn_delta_mgdl": round(glucose_report.dawn_phenomenon.delta, 1),
            "hypo_count": hypo_count,
            "meal_correlation": meal_correlation,
            "avg_hypo_duration_min": round(avg_hypo_duration, 1)
            if avg_hypo_duration
            else None,
            "bolus_count": bolus_count,
            "avg_bolus_units": round(avg_bolus_units, 2) if avg_bolus_units else None,
        }

    # ── Prompt builder ─────────────────────────────────────────────────────

    def _build_prompt(self, summary: Dict[str, Any]) -> str:
        return f"""You are a diabetes management assistant helping a person with T1D/LADA 
who uses FreeStyle Libre 2 and Nightscout for CGM monitoring.

Here is their glucose and treatment summary for the past {summary["period_days"]} days:

GLUCOSE CONTROL:
- Time In Range (70-180 mg/dL): {summary["tir"]}%
- Time Above Range (>180 mg/dL): {summary["tar"]}%
- Time Below Range (<70 mg/dL): {summary["tbr"]}%
- Average glucose: {summary["avg_glucose_mgdl"]} mg/dL
- GMI (estimated HbA1c): {summary["gmi"]}%

VARIABILITY:
- CV: {summary["cv"]}% (target <36%)
- Std Dev: {summary["std_dev"]} mg/dL
- Status: {summary["variability_flag"]}

PATTERNS:
- Worst time of day: {summary["worst_period"]}
- Dawn phenomenon: {summary["dawn_phenomenon"]} (glucose rise: {summary["dawn_delta_mgdl"]} mg/dL)

HYPOS:
- Count: {summary["hypo_count"]} events
- Avg duration: {summary["avg_hypo_duration_min"]} min

BOLUS:
- Total boluses: {summary["bolus_count"]}
- Avg dose: {summary["avg_bolus_units"]} units

Please provide:
1. A brief assessment of their glucose control (2-3 sentences)
2. The top 2 specific patterns or concerns to address
3. One actionable suggestion they can discuss with their doctor

Keep the response concise, factual, and encouraging. Do not diagnose or prescribe.
Max 200 words."""

    # ── Claude API call ────────────────────────────────────────────────────

    async def _call_claude(self, prompt: str) -> tuple[str, int]:
        """Call Anthropic API. Returns (insight_text, tokens_used)."""

        if MOCK_MODE:
            return (
                "Mock insight: Your TIR is 68% which is approaching the 70% target. "
                "Your worst period is morning, likely linked to the MODERATE dawn phenomenon detected. "
                "CV at 38% is slightly above the 36% target — focus on consistent meal timing. "
                "Discuss basal adjustment for overnight with your doctor.",
                0,  # 0 tokens used
            )

        headers = {
            "x-api-key": self.settings.anthropic_api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }
        payload: Dict[str, Any] = {
            "model": ANTHROPIC_MODEL,
            "max_tokens": 400,
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

    # ── Save to DB ─────────────────────────────────────────────────────────

    def _save_to_summary(self, insight: str, user_id: int) -> DailySummary:
        today = date.today()
        summary = (
            self.db.query(DailySummary)
            .filter(DailySummary.user_id == user_id, DailySummary.date == today)
            .first()
        )
        if summary:
            summary.ai_insight = insight
        else:
            summary = DailySummary(date=today, user_id=user_id, ai_insight=insight)
            self.db.add(summary)
        self.db.commit()
        self.db.refresh(summary)
        return summary

    # ── Main entry point ───────────────────────────────────────────────────

    async def get_weekly_insight(self, user_id: int, days: int = 7) -> Dict[str, Any]:
        # 1. check cache
        cached = self._get_cached_insight(user_id=user_id)
        if cached:
            logger.info("Returning cached insight — no API call made")
            return {
                "date": cached.date,
                "insight": cached.ai_insight,
                "cached": True,
                "tokens_used": None,
            }

        # 2. build lean summary
        summary = self._build_lean_summary(user_id=user_id, days=days)
        prompt = self._build_prompt(summary)
        logger.info(
            f"Calling Claude API for insight — ~{len(prompt.split())} words in prompt"
        )

        # 3. call Claude
        insight, tokens = await self._call_claude(prompt)
        logger.info(f"Claude responded — tokens used: {tokens}")

        # 4. cache to DB
        self._save_to_summary(insight, user_id=user_id)

        return {
            "date": date.today(),
            "insight": insight,
            "cached": False,
            "tokens_used": tokens,
        }
