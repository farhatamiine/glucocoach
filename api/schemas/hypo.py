from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, model_validator


class HypoCreate(BaseModel):
    lowest_value: float = Field(
        ..., le=70, description="Lowest BG during hypo (mg/dL, must be ≤70)"
    )
    started_at: datetime = Field(..., description="When the hypo started")
    ended_at: Optional[datetime] = Field(default=None, description="When BG recovered")
    duration_min: Optional[int] = Field(default=None, ge=0)
    recovery_min: Optional[int] = Field(default=None, ge=0)
    treated_with: Optional[str] = Field(
        default=None, description="e.g. '3 sugar cubes', 'juice'"
    )
    notes: Optional[str] = Field(default=None, max_length=500)

    @model_validator(mode="after")
    def calc_duration(self) -> "HypoCreate":
        """Auto-calculate duration_min if started_at and ended_at are both provided."""
        if self.ended_at and self.started_at and self.duration_min is None:
            delta = self.ended_at - self.started_at
            self.duration_min = max(0, int(delta.total_seconds() / 60))
        return self


class HypoUpdate(BaseModel):
    lowest_value: Optional[float] = Field(default=None, le=70)
    ended_at: Optional[datetime] = Field(default=None)
    duration_min: Optional[int] = Field(default=None, ge=0)
    recovery_min: Optional[int] = Field(default=None, ge=0)
    treated_with: Optional[str] = Field(default=None)
    notes: Optional[str] = Field(default=None, max_length=500)


class HypoResponse(BaseModel):
    id: int
    lowest_value: float
    started_at: datetime
    ended_at: Optional[datetime]
    duration_min: Optional[int]
    recovery_min: Optional[int]
    treated_with: Optional[str]
    notes: Optional[str]

    model_config = {"from_attributes": True}
