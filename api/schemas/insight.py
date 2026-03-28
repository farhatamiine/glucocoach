from datetime import date
from typing import Optional

from pydantic import BaseModel, Field


class WeeklyInsightRequest(BaseModel):
    """Optional overrides — all auto-fetched if omitted."""

    days: int = Field(default=7, ge=1, le=30, description="Lookback period in days")


class WeeklyInsightResponse(BaseModel):
    date: date
    insight: str
    cached: bool = Field(
        description="True if returned from DB cache, False if freshly generated"
    )
    tokens_used: Optional[int] = Field(
        default=None, description="Anthropic tokens used (None if cached)"
    )
