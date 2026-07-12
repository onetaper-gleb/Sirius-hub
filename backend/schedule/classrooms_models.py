from pydantic import BaseModel
from typing import List


class FreeClassrooms(BaseModel):
    classrooms: List[str]
    number: int | None
    date: str | None
    time: str | None
    weekday: str | None
    current_pair_number: int | None
    current_pair_time: str | None