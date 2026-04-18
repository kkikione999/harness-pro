"""Data models for the Order Service."""

from enum import Enum
from pydantic import BaseModel
from typing import Optional


class OrderStatus(str, Enum):
    PENDING = "pending"
    PAID = "paid"
    CANCELLED = "cancelled"
    COMPLETED = "completed"


class OrderItemCreate(BaseModel):
    product_id: str
    quantity: int


class OrderCreate(BaseModel):
    user_id: str
    items: list[OrderItemCreate]


class OrderItemResponse(BaseModel):
    product_id: str
    quantity: int
    unit_price: float


class OrderResponse(BaseModel):
    id: str
    user_id: str
    status: OrderStatus
    items: list[OrderItemResponse]
    total_amount: float
    created_at: str


class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None