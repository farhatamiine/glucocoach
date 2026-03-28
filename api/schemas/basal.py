from datetime import datetime, timezone
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class BasalCreate(BaseModel):
    timestamp: Optional[datetime] = Field(default=None)
    units: float = Field(..., gt=0, le=60, description="Basal units (safety cap: 60u)")
    insulin: Optional[str] = Field(
        default=None, description="Glargine | Degludec | Tresiba"
    )
    time: Optional[str] = Field(default=None, description="Night | Morning")
    notes: Optional[str] = Field(default=None, max_length=500)

    @field_validator("insulin")
    @classmethod
    def validate_insulin(cls, v: str | None) -> str | None:
        allowed = {"Glargine", "Degludec", "Tresiba"}
        if v is not None and v not in allowed:
            raise ValueError(f"insulin must be one of {allowed}")
        return v

    @field_validator("time")
    @classmethod
    def validate_time(cls, v: str | None) -> str | None:
        allowed = {"Night", "Morning"}
        if v is not None and v not in allowed:
            raise ValueError(f"time must be one of {allowed}")
        return v

    @field_validator("units")
    @classmethod
    def round_units(cls, v: float) -> float:
        return round(v, 2)

    def get_timestamp(self) -> datetime:
        return self.timestamp or datetime.now(timezone.utc)


class BasalUpdate(BaseModel):
    units: Optional[float] = Field(default=None, gt=0, le=60)
    insulin: Optional[str] = Field(default=None)
    time: Optional[str] = Field(default=None)
    notes: Optional[str] = Field(default=None, max_length=500)

    @field_validator("insulin")
    @classmethod
    def validate_insulin(cls, v: str | None) -> str | None:
        allowed = {"Glargine", "Degludec", "Tresiba"}
        if v is not None and v not in allowed:
            raise ValueError(f"insulin must be one of {allowed}")
        return v

    @field_validator("time")
    @classmethod
    def validate_time(cls, v: str | None) -> str | None:
        allowed = {"Night", "Morning"}
        if v is not None and v not in allowed:
            raise ValueError(f"time must be one of {allowed}")
        return v


class BasalResponse(BaseModel):
    id: int
    timestamp: datetime
    units: float
    insulin: Optional[str]
    time: Optional[str]
    notes: Optional[str]

    model_config = {"from_attributes": True}
