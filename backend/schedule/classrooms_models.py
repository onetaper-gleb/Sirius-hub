from typing import List

from pydantic import BaseModel


class FreeClassrooms(BaseModel):
    classrooms: List[str]