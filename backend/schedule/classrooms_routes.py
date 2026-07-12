import asyncio
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query

from .classrooms_models import FreeClassrooms
from .classrooms_parser import ScheduleParsingError, NetworkError, ParsingError, Schedule  

router = APIRouter(
    prefix="/classrooms",
    tags=["Classrooms"],
)

@router.get("/free", response_model=FreeClassrooms)
async def get_free_classrooms(
    date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    time: Optional[str] = Query(None, description="HH:MM")
):
    
    if date:
        dt = datetime.strptime(date, "%Y-%m-%d")
    else:
        dt = datetime.now()
    
    if time:
        hours, minutes = map(int, time.split(':'))
        dt = dt.replace(hour=hours, minute=minutes)
    
    client = Schedule()
    
    try:
        free_classrooms = await client.get_free_classrooms(date=dt)
        return free_classrooms
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get free classrooms: {str(e)}"
        )