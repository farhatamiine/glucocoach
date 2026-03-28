from pydantic import BaseModel


class User(BaseModel):
    full_name: str
    age: int
    weight: int
    basal_unit: int
    height: int
