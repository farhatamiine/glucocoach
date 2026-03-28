from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class MealCreate(BaseModel):
    meal_type: str = Field(..., pattern="^(low_gi|medium_gi|high_gi)$")
    carbs_g: Optional[float] = Field(None, ge=0, le=500)
    description: Optional[str] = Field(None, max_length=500)
    glucose_before: Optional[float] = None


class MealUpdate(BaseModel):
    glucose_peak: float
    result: Optional[str] = Field(None, pattern="^(spike|stable|low)$")


class MealResponse(BaseModel):
    id: int
    meal_type: str
    carbs_g: Optional[float]
    description: Optional[str]
    glucose_before: Optional[float]
    glucose_peak: Optional[float]
    result: Optional[str]
    timestamp: datetime
    model_config = {"from_attributes": True}


class MealCorrelation(BaseModel):
    meal_type: str
    avg_spike: Optional[float]
    sample_count: int
