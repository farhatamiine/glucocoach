from typing import List

from pydantic import BaseModel, Field

from models.glucose import AGPHour


class GlucoseQueryParams(BaseModel):
    """Query parameters for fetching glucose data."""

    count: int = Field(
        default=1152, ge=1, le=10000, description="Number of CGM readings to fetch"
    )
    days: str = Field(
        default="4", description="Number of past days (e.g. '4', '7', '30')"
    )


class GlucoseStats(BaseModel):
    """Core glucose performance metrics."""

    average: float = Field(..., description="Mean glucose in mg/dL")
    gmi: float = Field(
        ..., description="Glucose Management Indicator (estimated A1c %)"
    )


class GlucoseMetadata(BaseModel):
    """Metadata about the analyzed glucose data period."""

    period_days: str = Field(..., description="The lookback period in days")
    total_readings: int = Field(..., description="Number of data points analyzed")


class GlucoseRanges(BaseModel):
    """Time in Range (TIR) targets and classifications."""

    tir: float = Field(..., description="Time In Range 70–180 mg/dL (%)")
    tar: float = Field(..., description="Time Above Range >180 mg/dL (%)")
    tbr: float = Field(..., description="Time Below Range <70 mg/dL (%)")


class GlucoStatsResponse(BaseModel):
    """Summary of glucose statistics, metadata, and ranges."""

    metadata: GlucoseMetadata
    stats: GlucoseStats
    ranges: GlucoseRanges


class GlucoVariabilityResponse(BaseModel):
    """Analysis of how much glucose fluctuates."""

    std_dev: float = Field(
        ...,
        description="Standard Deviation: How far your glucose readings scatter around your average.",
    )
    cv: float = Field(
        ...,
        description="Coefficient of Variation: The most important variability number (ideal is < 36%).",
    )
    highest: float = Field(
        ..., description="Highest reading in the period → your worst spike"
    )
    lowest: float = Field(
        ..., description="Lowest reading in the period  → your worst hypo"
    )
    flag: str = Field(
        ..., description="Glucose variability status (STABLE or HIGH VARIABILITY)"
    )


class GlucosePattern(BaseModel):
    """Aggregated glucose data for a specific time period."""

    avg: int = Field(..., description="Average glucose during this period")
    reading: int = Field(..., description="Number of readings in this period")
    time: str = Field(..., description="Time window for this pattern")


class GlucosePatternResponse(BaseModel):
    """Comparison of glucose patterns across different times of day."""

    morning: GlucosePattern
    afternoon: GlucosePattern
    evening: GlucosePattern
    night: GlucosePattern
    worst_period: str = Field(
        ..., description="The time of day with the highest average glucose"
    )


class GlucoseDawnPhenomenon(BaseModel):
    """Analysis of glucose rise in early morning hours."""

    avg_2am: float = Field(..., description="Average glucose around 2 AM")
    avg_7am: float = Field(..., description="Average glucose around 7 AM")
    delta: float = Field(..., description="Difference between 7 AM and 2 AM")
    flag: str = Field(
        ..., description="Severity of dawn phenomenon (NONE, MILD, MODERATE, SEVERE)"
    )
    interpretation: str = Field(
        ..., description="Clinical interpretation of the dawn phenomenon data"
    )


class AGPResponse(BaseModel):
    hours: List[AGPHour]


class GlucoseFullReport(BaseModel):
    """Comprehensive analysis combining all glucose metrics."""

    stats: GlucoStatsResponse
    variability: GlucoVariabilityResponse
    patterns: GlucosePatternResponse
    dawn_phenomenon: GlucoseDawnPhenomenon
    agp: AGPResponse
