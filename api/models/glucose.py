from pydantic import BaseModel


class AGPHour(BaseModel):
    hour: int
    p5: float
    p25: float
    p50: float
    p75: float
    p95: float
