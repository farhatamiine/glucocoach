from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status

from core.auth import get_current_user
from core.dependencies import get_bolus_service, get_glucose_service
from db.models.user import User
from schemas.bolus import BolusCreate, BolusResponse, BolusTimingResponse, BolusUpdate
from services.bolus_service import BolusService
from services.glucose_service import GlucoseService

bolus_router = APIRouter()


@bolus_router.get("/timing", response_model=BolusTimingResponse)
def get_bolus(
    meal_type: str = Query(
        default="medium_gi", description="Type of meal (low_gi, medium_gi, high_gi)"
    ),
    current_user: User = Depends(get_current_user),
    service: GlucoseService = Depends(get_glucose_service),
):
    """
    Calculates the optimal timing for an insulin bolus based on current glucose level and meal GI.
    """
    try:
        return service.get_bolus_timing(meal_type=meal_type)
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))


@bolus_router.post(
    "/",
    response_model=BolusResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Log a bolus insulin dose",
)
def create_bolus(
    payload: BolusCreate,
    current_user: User = Depends(get_current_user),
    service: BolusService = Depends(get_bolus_service),
):
    """
    Save a bolus insulin event to the database.

    - **units**: Required. Dose in units (max 30u safety cap)
    - **bolus_type**: `manual` | `correction` | `meal` (default: manual)
    - **meal_carbs**: Carb count in grams (meal boluses only)
    - **glucose_at_time**: BG reading at injection time (mg/dL)
    """
    try:
        return service.create_bolus(payload, user_id=current_user.id)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@bolus_router.get("", response_model=List[BolusResponse], summary="List bolus logs")
def list_boluses(
    limit: int = Query(default=20, ge=1, le=100),
    days: int = Query(default=30, ge=1, le=90),
    current_user: User = Depends(get_current_user),
    service: BolusService = Depends(get_bolus_service),
):
    """Returns bolus logs ordered by most recent first."""
    return service.list_boluses(user_id=current_user.id, limit=limit, days=days)


@bolus_router.get("/{bolus_id}", response_model=BolusResponse, summary="Get a bolus log")
def get_bolus(
    bolus_id: int,
    current_user: User = Depends(get_current_user),
    service: BolusService = Depends(get_bolus_service),
):
    bolus = service.get_bolus(bolus_id, user_id=current_user.id)
    if not bolus:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bolus log not found")
    return bolus


@bolus_router.patch("/{bolus_id}", response_model=BolusResponse, summary="Update a bolus log")
def update_bolus(
    bolus_id: int,
    payload: BolusUpdate,
    current_user: User = Depends(get_current_user),
    service: BolusService = Depends(get_bolus_service),
):
    try:
        return service.update_bolus(bolus_id, payload, user_id=current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@bolus_router.delete("/{bolus_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete a bolus log")
def delete_bolus(
    bolus_id: int,
    current_user: User = Depends(get_current_user),
    service: BolusService = Depends(get_bolus_service),
):
    try:
        service.delete_bolus(bolus_id, user_id=current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
