from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status

from core.auth import get_current_user
from core.dependencies import get_basal_service
from schemas.basal import BasalCreate, BasalResponse, BasalUpdate
from services.basal_service import BasalService

basal_router = APIRouter()


@basal_router.post(
    "",
    response_model=BasalResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Log a basal insulin dose",
)
def create_basal(
    payload: BasalCreate,
    current_user=Depends(get_current_user),
    service: BasalService = Depends(get_basal_service),
):
    """
    Save a basal insulin event to the database.

    - **units**: Required. Dose in units (safety cap: 60u)
    - **insulin**: `Glargine` | `Degludec` | `Tresiba`
    - **time**: `Night` | `Morning`
    """
    try:
        return service.create_basal(payload, user_id=current_user.id)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)
        )


@basal_router.get("", response_model=List[BasalResponse], summary="List basal logs")
def list_basals(
    limit: int = Query(default=20, ge=1, le=100),
    days: int = Query(default=30, ge=1, le=90),
    current_user=Depends(get_current_user),
    service: BasalService = Depends(get_basal_service),
):
    """Returns basal logs ordered by most recent first."""
    return service.list_basals(user_id=current_user.id, limit=limit, days=days)


@basal_router.get("/{basal_id}", response_model=BasalResponse, summary="Get a basal log")
def get_basal(
    basal_id: int,
    current_user=Depends(get_current_user),
    service: BasalService = Depends(get_basal_service),
):
    basal = service.get_basal(basal_id, user_id=current_user.id)
    if not basal:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Basal log not found")
    return basal


@basal_router.patch("/{basal_id}", response_model=BasalResponse, summary="Update a basal log")
def update_basal(
    basal_id: int,
    payload: BasalUpdate,
    current_user=Depends(get_current_user),
    service: BasalService = Depends(get_basal_service),
):
    try:
        return service.update_basal(basal_id, payload, user_id=current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@basal_router.delete("/{basal_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete a basal log")
def delete_basal(
    basal_id: int,
    current_user=Depends(get_current_user),
    service: BasalService = Depends(get_basal_service),
):
    try:
        service.delete_basal(basal_id, user_id=current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
