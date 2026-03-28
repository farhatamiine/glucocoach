from fastapi import APIRouter
from typing import Dict, Any
from core.config import get_settings

health_router = APIRouter()


@health_router.get("/")
def health() -> Dict[str, Any]:
    """
    Returns the application status, name, and version.
    """
    settings = get_settings()
    return {
        "app_name": settings.app_name,
        "app_version": settings.app_version,
        "app_status": "ok",
        "url": settings.nightscout_url,  # confirm new value loaded
    }
