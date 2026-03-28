from fastapi import APIRouter, Depends, HTTPException, Query, status

from core.auth import get_current_user
from core.dependencies import get_meal_service
from db.models.user import User
from schemas.meal_log import MealCorrelation, MealCreate, MealResponse, MealUpdate
from services.meal_service import MealService

meal_router = APIRouter()


@meal_router.post("/", response_model=MealResponse, status_code=201)
def log_meal(
    payload: MealCreate,
    current_user: User = Depends(get_current_user),
    service: MealService = Depends(get_meal_service),
):
    return service.create_meal(payload, user_id=current_user.id)


@meal_router.get("/", response_model=list[MealResponse])
def list_meals(
    limit: int = Query(default=20, ge=1, le=100),
    days: int = Query(default=30, ge=1, le=90),
    current_user: User = Depends(get_current_user),
    service: MealService = Depends(get_meal_service),
):
    return service.list_meals(current_user.id, limit=limit, days=days)


@meal_router.get("/correlation", response_model=list[MealCorrelation])
def get_correlation(
    days: int = Query(default=14, ge=7, le=90),
    current_user: User = Depends(get_current_user),
    service: MealService = Depends(get_meal_service),
):
    """
    The GlucoCoach premium insight:
    Average glucose spike per meal type over the last N days.
    Example: high_gi meals spike you +5.9 mmol/L on average.
    """
    return service.get_correlation(current_user.id, days=days)


@meal_router.get("/{meal_id}", response_model=MealResponse)
def get_meal(
    meal_id: int,
    current_user: User = Depends(get_current_user),
    service: MealService = Depends(get_meal_service),
):
    meal = service.get_meal(meal_id, user_id=current_user.id)
    if not meal:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal not found")
    return meal


@meal_router.patch("/{meal_id}", response_model=MealResponse)
def update_meal_peak(
    meal_id: int,
    payload: MealUpdate,
    current_user: User = Depends(get_current_user),
    service: MealService = Depends(get_meal_service),
):
    """Call this ~2 hours after a meal to record the glucose peak."""
    try:
        return service.update_peak(meal_id, payload.glucose_peak, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@meal_router.delete("/{meal_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_meal(
    meal_id: int,
    current_user: User = Depends(get_current_user),
    service: MealService = Depends(get_meal_service),
):
    try:
        service.delete_meal(meal_id, user_id=current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
