from datetime import datetime, timezone
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class BolusCreate(BaseModel):
    timestamp: Optional[datetime] = Field(default=None)
    units: float = Field(..., gt=0, le=30)
    bolus_type: str = Field(default="manual")
    meal_type: Optional[str] = Field(
        default=None, description="low_gi | medium_gi | high_gi"
    )
    glucose_at_injection: Optional[float] = Field(default=None, ge=0)
    inject_to_meal_min: Optional[int] = Field(
        default=None, ge=0, description="Minutes before eating"
    )
    notes: Optional[str] = Field(default=None, max_length=500)

    @field_validator("bolus_type")
    @classmethod
    def validate_bolus_type(cls, v: str) -> str:
        allowed = {"manual", "correction", "meal"}
        if v not in allowed:
            raise ValueError(f"bolus_type must be one of {allowed}")
        return v

    @field_validator("meal_type")
    @classmethod
    def validate_meal_type(cls, v: str | None) -> str | None:
        if v is not None and v not in {"low_gi", "medium_gi", "high_gi"}:
            raise ValueError("meal_type must be low_gi | medium_gi | high_gi")
        return v

    def get_timestamp(self) -> datetime:
        return self.timestamp or datetime.now(timezone.utc)


class BolusUpdate(BaseModel):
    units: Optional[float] = Field(default=None, gt=0, le=30)
    bolus_type: Optional[str] = Field(default=None)
    meal_type: Optional[str] = Field(default=None)
    glucose_at_injection: Optional[float] = Field(default=None, ge=0)
    inject_to_meal_min: Optional[int] = Field(default=None, ge=0)
    notes: Optional[str] = Field(default=None, max_length=500)

    @field_validator("bolus_type")
    @classmethod
    def validate_bolus_type(cls, v: str | None) -> str | None:
        if v is not None and v not in {"manual", "correction", "meal"}:
            raise ValueError("bolus_type must be one of manual | correction | meal")
        return v

    @field_validator("meal_type")
    @classmethod
    def validate_meal_type(cls, v: str | None) -> str | None:
        if v is not None and v not in {"low_gi", "medium_gi", "high_gi"}:
            raise ValueError("meal_type must be low_gi | medium_gi | high_gi")
        return v


class BolusResponse(BaseModel):
    id: int
    timestamp: datetime
    units: float
    bolus_type: str
    meal_type: Optional[str]
    glucose_at_injection: Optional[float]
    inject_to_meal_min: Optional[int]
    notes: Optional[str]

    model_config = {"from_attributes": True}


class BolusTimingResponse(BaseModel):
    """Recommendation for when to inject before a meal."""

    inject_minutes_before: int = Field(
        ..., description="Minutes before eating to inject (-1 means do not bolus)"
    )
    message: str = Field(..., description="Human-readable instruction")
    warning: Optional[str] = Field(
        default=None, description="Warning if glucose too high to meal bolus"
    )
