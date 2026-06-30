from pydantic import BaseModel


class PromoteRequest(BaseModel):
    uid: str
