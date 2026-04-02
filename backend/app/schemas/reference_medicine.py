from pydantic import BaseModel, Field


class ReferenceMedicineOut(BaseModel):
    id: int
    name: str = Field(max_length=255)
    sort_order: int

    model_config = {"from_attributes": True}
