from fastapi import Depends
from sqlalchemy.orm import Session

from core.config import get_settings
from db.database import get_db
from services.basal_service import BasalService
from services.bolus_service import BolusService
from services.glucose_service import GlucoseService
from services.hypo_service import HypoService
from services.insight_service import InsightsService
from services.meal_service import MealService
from services.report_service import MonthlyReportService


def get_glucose_service() -> GlucoseService:
    settings = get_settings()
    return GlucoseService(settings=settings)


def get_bolus_service(db: Session = Depends(get_db)) -> BolusService:
    return BolusService(db=db, glucose_service=get_glucose_service())


def get_basal_service(db: Session = Depends(get_db)) -> BasalService:
    return BasalService(db=db)


def get_hypo_service(db: Session = Depends(get_db)) -> HypoService:
    return HypoService(db=db, glucose_service=get_glucose_service())


def get_insights_service(
    db: Session = Depends(get_db),
    glucose_service: GlucoseService = Depends(get_glucose_service),
) -> InsightsService:
    settings = get_settings()
    meal_service = MealService(db)
    return InsightsService(db=db, glucose_service=glucose_service, meal_service=meal_service, settings=settings)


def get_monthly_report_service(
    db: Session = Depends(get_db),
    glucose_service: GlucoseService = Depends(get_glucose_service),
) -> MonthlyReportService:
    settings = get_settings()
    return MonthlyReportService(
        db=db, glucose_service=glucose_service, settings=settings
    )


def get_meal_service(db: Session = Depends(get_db)) -> MealService:
    return MealService(db)
