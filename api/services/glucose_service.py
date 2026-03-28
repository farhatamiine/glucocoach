from core.config import Settings
import hashlib
from models.glucose import AGPHour
from schemas.glucose import (
    AGPResponse,
    GlucoStatsResponse,
    GlucoseMetadata,
    GlucoseRanges,
    GlucoseStats,
    GlucoVariabilityResponse,
    GlucoseFullReport,
    GlucosePatternResponse,
    GlucosePattern,
    GlucoseDawnPhenomenon,
)
from schemas.bolus import BolusTimingResponse
from typing import Any, cast, List, Dict
from collections import defaultdict
import pandas as pd
import requests
import numpy as np
from core.logger import get_logger
from datetime import datetime, timedelta


logger = get_logger(__name__)


# Calculates Glucose Management Indicator (GMI)
def _calculate_gmi(avg_glucose: float) -> float:
    """Standard clinical GMI formula for mg/dL."""
    return round(3.31 + (0.02392 * avg_glucose), 1)


# Computes basic glucose statistics and TIR/TAR/TBR ranges
def get_stats(records: List[Dict[str, Any]], days: str) -> GlucoStatsResponse:
    values = [int(r["sgv"]) for r in records if r.get("sgv") is not None]
    if not values:
        raise ValueError("No valid glucose values found.")

    total = len(values)
    avg = sum(values) / total

    return GlucoStatsResponse(
        metadata=GlucoseMetadata(period_days=days, total_readings=total),
        stats=GlucoseStats(average=round(avg, 1), gmi=_calculate_gmi(avg)),
        ranges=GlucoseRanges(
            tir=round(sum(1 for v in values if 70 <= v <= 180) / total * 100, 1),
            tar=round(sum(1 for v in values if v > 180) / total * 100, 1),
            tbr=round(sum(1 for v in values if v < 70) / total * 100, 1),
        ),
    )


# Analyzes glucose variability (Std Dev, CV)
def get_variability(records: List[Dict[str, Any]]) -> GlucoVariabilityResponse:
    values = [int(r["sgv"]) for r in records if r.get("sgv") is not None]
    if not values:
        raise ValueError("No valid glucose values found.")

    std_dev = round(float(np.std(values)), 1)
    cv = round(float((np.std(a=values) / np.mean(values)) * 100), 1)
    highest = max(values)
    lowest = min(values)
    flag = "STABLE" if cv <= 36 else "HIGH VARIABILITY"
    return GlucoVariabilityResponse(
        std_dev=std_dev, cv=cv, flag=flag, highest=highest, lowest=lowest
    )


# Identifies glucose patterns across different times of the day
def get_patterns(records: List[Dict[str, Any]]) -> GlucosePatternResponse:

    buckets: Dict[str, List[int]] = defaultdict(list)
    for r in records:
        hour = datetime.fromisoformat(r["dateString"]).hour
        if 6 <= hour < 12:
            buckets["morning"].append(int(r["sgv"]))
        elif 12 <= hour < 18:
            buckets["afternoon"].append(int(r["sgv"]))
        elif 18 <= hour < 24:
            buckets["evening"].append(int(r["sgv"]))
        else:
            buckets["night"].append(int(r["sgv"]))

    morning: GlucosePattern = GlucosePattern(
        avg=round(np.mean(buckets["morning"])),
        reading=len(buckets["morning"]),
        time="06:00-12:00",
    )

    afternoon: GlucosePattern = GlucosePattern(
        avg=round(np.mean(buckets["afternoon"])),
        reading=len(buckets["afternoon"]),
        time="12:00-18:00",
    )

    evening: GlucosePattern = GlucosePattern(
        avg=round(np.mean(buckets["evening"])),
        reading=len(buckets["evening"]),
        time="18:00-00:00",
    )

    night: GlucosePattern = GlucosePattern(
        avg=round(np.mean(buckets["night"])),
        reading=len(buckets["night"]),
        time="00:00-06:00",
    )

    periods = {
        "morning": morning.avg,
        "afternoon": afternoon.avg,
        "evening": evening.avg,
        "night": night.avg,
    }

    return GlucosePatternResponse(
        afternoon=afternoon,
        evening=evening,
        morning=morning,
        night=night,
        worst_period=max(periods, key=lambda x: periods[x]),
    )


# Determines the severity flag for a dawn phenomenon
def _get_dawn_flag(delta: float) -> str:
    if delta < 15:
        return "NONE"
    elif delta < 30:
        return "MILD"
    elif delta < 50:
        return "MODERATE"
    return "SEVERE"


# Generates an interpretation message for a dawn phenomenon
def _get_dawn_interpretation(delta: float, flag: str) -> str:
    return (
        f"Your glucose rose {round(delta)} mg/dL while sleeping. "
        f"{flag} dawn phenomenon detected. "
        + (
            "Basal insulin is covering well."
            if flag == "NONE"
            else "Consider discussing basal adjustment with your doctor."
            if flag in ("MODERATE", "SEVERE")
            else "Monitor overnight trend."
        )
    )


# Checks for a dawn phenomenon by comparing 2 AM and 7 AM averages
def get_dawn_phenomenon_check(records: List[Dict[str, Any]]) -> GlucoseDawnPhenomenon:
    if not records:
        raise ValueError("No records provided.")

    readings_2am = [
        int(r["sgv"])
        for r in records
        if datetime.fromisoformat(r["dateString"]).hour == 2
    ]
    readings_7am = [
        int(r["sgv"])
        for r in records
        if datetime.fromisoformat(r["dateString"]).hour == 7
    ]

    avg_2am = round(float(np.mean(readings_2am)), 1)
    avg_7am = round(float(np.mean(readings_7am)), 1)
    delta = np.abs(avg_7am - avg_2am)
    flag = _get_dawn_flag(delta)
    interpretation = _get_dawn_interpretation(delta, flag=flag)

    return GlucoseDawnPhenomenon(
        avg_2am=avg_2am,
        avg_7am=avg_7am,
        delta=delta,
        flag=flag,
        interpretation=interpretation,
    )


def calculate_count(days: int) -> int:
    READINGS_PER_DAY = 288  # every 5 minutes
    return days * READINGS_PER_DAY


class GlucoseService:
    def __init__(self, settings: Settings) -> None:
        self.setting = settings

    def get_headers(self) -> dict[str, str]:
        api_secret = self.setting.nightscout_secret
        if not api_secret:
            raise ValueError("api_secret is not set.")
        hashed_api_secret = hashlib.sha1(api_secret.encode()).hexdigest()
        return {"api-secret": hashed_api_secret, "Accept": "application/json"}

    def fetch_nightscout_data(self, days: str) -> List[Dict[str, Any]]:
        """Fetches raw CGM entries from Nightscout."""
        headers = self.get_headers()
        cutoff = (datetime.now() - timedelta(days=int(days))).strftime("%Y-%m-%d")
        params: Dict[str, Any] = {
            "count": calculate_count(int(days)),
            "find[dateString][$gt]": cutoff,
        }
        response = requests.get(
            f"{self.setting.nightscout_url}/api/v1/entries.json",
            headers=headers,
            params=params,
        )
        if response.status_code != 200:
            raise RuntimeError(
                f"Failed to fetch data: {response.status_code} - {response.text}"
            )

        df = pd.json_normalize(response.json())
        to_drop = ["noise", "filtered", "unfiltered", "rssi", "utcOffset", "sysTime"]
        df.drop(columns=to_drop, inplace=True, errors="ignore")
        return cast(List[Dict[str, Any]], df.to_dict(orient="records"))

    def get_bolus_timing(self, meal_type: str) -> BolusTimingResponse:

        glucose = self.get_current()["sgv"]

        match meal_type:
            case "low_gi":
                gi_modifier = -3
            case "medium_gi":
                gi_modifier = 0
            case "high_gi":
                gi_modifier = 5
            case _:
                gi_modifier = 0

        if glucose < 90:
            base = 0
        elif glucose < 120:
            base = 12
        elif glucose < 150:
            base = 17
        elif glucose < 180:
            base = 22
        else:
            base = -1

        final = -1 if base == -1 else base + gi_modifier

        message = (
            "Correct your glucose first before bolusing for a meal."
            if final == -1
            else f"Inject {final} minutes before eating."
        )

        warning = "Glucose too high to bolus for meal." if final == -1 else None

        return BolusTimingResponse(
            inject_minutes_before=final, message=message, warning=warning
        )

    def get_current(self) -> Dict[str, Any]:
        headers = self.get_headers()
        response = requests.get(
            f"{self.setting.nightscout_url}/api/v1/entries/current.json",
            headers=headers,
        )
        if response.status_code != 200:
            raise RuntimeError(f"Failed: {response.status_code}")

        data = response.json()[0]  # returns a list, take first
        return {
            "sgv": data["sgv"],
            "direction": data.get("direction", "Unknown"),
            "trend": data.get("trend", 0),
            "timestamp": data.get("dateString", ""),
        }

    def get_full_report(self, days: str) -> GlucoseFullReport:
        records = self.fetch_nightscout_data(days)
        if not records:
            raise ValueError("No records provided.")
        variability: GlucoVariabilityResponse = get_variability(records=records)
        stats: GlucoStatsResponse = get_stats(records=records, days=days)
        patterns: GlucosePatternResponse = get_patterns(records=records)
        dawn_phenomenon: GlucoseDawnPhenomenon = get_dawn_phenomenon_check(
            records=records
        )
        agp: AGPResponse = self.calculate_agp(records=records)
        return GlucoseFullReport(
            stats=stats,
            variability=variability,
            patterns=patterns,
            dawn_phenomenon=dawn_phenomenon,
            agp=agp,
        )

    def calculate_agp(self, records: List[Dict[str, Any]]) -> AGPResponse:
        if not records:
            raise ValueError("No records provided.")
        buckets: Dict[int, List[int]] = defaultdict(list)
        agp: List[AGPHour] = []
        for r in records:
            hour = datetime.fromisoformat(r["dateString"]).hour
            buckets[hour].append(int(r["sgv"]))
        for hour in range(24):
            values = buckets[hour]
            if not values:
                continue
            agp.append(
                AGPHour(
                    hour=hour,
                    p25=round(float(np.percentile(values, 25)), 1),
                    p5=round(float(np.percentile(values, 5)), 1),
                    p50=round(float(np.percentile(values, 50)), 1),
                    p95=round(float(np.percentile(values, 95)), 1),
                    p75=round(float(np.percentile(values, 75)), 1),
                )
            )

        return AGPResponse(hours=agp)
