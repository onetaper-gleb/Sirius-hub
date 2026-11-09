from datetime import date as Date
from datetime import datetime
from datetime import time as Time
from datetime import timedelta
from typing import List, Optional

from fastapi import APIRouter, HTTPException, Query

from .classrooms_parser import Schedule

router = APIRouter(prefix="/classrooms", tags=["Classrooms"])


@router.get("/free", response_model=List[str])
async def get_free_classrooms(
    date: Optional[Date] = Query(None, description="YYYY-MM-DD"),
    start_time: Optional[Time] = Query(None, description="HH:MM"),
    end_time: Optional[Time] = Query(None, description="HH:MM"),
):
    now = datetime.now()
    requested_date = date or now.date()
    start_clock = start_time or now.time()
    if start_clock.tzinfo is not None or (end_time and end_time.tzinfo is not None):
        raise HTTPException(400, "Use local times without a time zone")
    start_date = datetime.combine(requested_date, start_clock)
    end_date = (
        datetime.combine(requested_date, end_time)
        if end_time is not None
        else start_date + timedelta(hours=1, minutes=20)
    )
    if start_date >= end_date or start_date.date() != end_date.date():
        raise HTTPException(
            400, "The interval must start before it ends within one day"
        )
    monday = now.date() - timedelta(days=now.weekday())
    requested_monday = requested_date - timedelta(days=requested_date.weekday())
    if abs((requested_monday - monday).days // 7) > 10:
        raise HTTPException(400, "The requested week is outside the supported range")
    try:
        return await Schedule().get_free_classrooms(
            start_date=start_date, end_date=end_date
        )
    except Exception:
        raise HTTPException(502, "Failed to get free classrooms")
