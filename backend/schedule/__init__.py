from fastapi import APIRouter

from .classrooms_routes import router as classrooms_router
from .group_routes import router as group_router

router = APIRouter()

router.include_router(group_router)
router.include_router(classrooms_router)

__all__ = ["router"]
