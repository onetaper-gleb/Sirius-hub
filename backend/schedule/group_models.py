from typing import List

from pydantic import BaseModel, field_validator


class Teacher(BaseModel):
    first_name: str | None
    last_name: str | None
    middle_name: str | None
    fio: str | None


class Event(BaseModel):
    start_time: str | None
    end_time: str | None
    number_pair: int | None
    discipline: str | None
    group_type: str | None
    address: str | None
    classroom: str | None
    comment: str | None
    place: str | None
    url_online: str | None
    group: str | None
    code: str | None
    color: str | None
    teachers: List[Teacher]

    @field_validator("teachers", mode="before")
    @classmethod
    def parse_teachers_strings(cls, value):
        if not isinstance(value, list) or len(value) == 0:
            return []
        test_teacher = value[0]
        if isinstance(test_teacher, str):
            result = []
            teachers = test_teacher.split(",")
            for teacher in teachers:
                teacher = teacher.strip()
                args = teacher.split(" ")
                if len(args) == 2:
                    last_name, first_name = args
                    middle_name = None
                elif len(args) == 3:
                    last_name, first_name, middle_name = args
                else:
                    last_name = teacher
                    first_name, middle_name = None, None
                result.append(
                    {
                        "fio": teacher.strip(),
                        "first_name": first_name,
                        "middle_name": middle_name,
                        "last_name": last_name,
                    }
                )
            return result
        return value


class Day(BaseModel):
    date: str | None
    day_week: str | None
    events: List[Event] | None
