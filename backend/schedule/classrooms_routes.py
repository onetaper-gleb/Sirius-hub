import asyncio
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, HTTPException, Query

from .classrooms_models import FreeClassrooms
from .classrooms_parser import Schedule

router = APIRouter(
    prefix="/classrooms",
    tags=["Classrooms"],
)


@router.get("/free", response_model=List[str])
async def get_free_classrooms(
    date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    start_time: Optional[str] = Query(None, description="HH:MM"),
    end_time: Optional[str] = Query(None, description="HH:MM")
):

    if date:
        date_time = datetime.strptime(date, "%Y-%m-%d")
    else:
        date_time = datetime.now()

    if start_time:
        hours, minutes = map(int, start_time.split(":"))
        start_date = date_time.replace(hour=hours, minute=minutes)
    else:
        start_date = datetime.now()

    if end_time:
        hours, minutes = map(int, end_time.split(":"))
        end_date = date_time.replace(hour=hours, minute=minutes)
    else:
        end_date = start_date + timedelta(hours=1, minutes=20)

    if start_date >= end_date:
        raise HTTPException(
            status_code=400, detail=f"The start time mush be before the end time"
        )

    client = Schedule()

    try:
        free_classrooms = await client.get_free_classrooms(start_date=start_date, end_date=end_date)
        return free_classrooms
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to get free classrooms: {str(e)}"
        )
