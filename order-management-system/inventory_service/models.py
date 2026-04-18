"""Data models for the Inventory Service."""

from pydantic import BaseModel
from typing import Optional


class StockAdjustRequest(BaseModel):
    stock: int


class StockResponse(BaseModel):
    product_id: str
    available_stock: int
    reserved_stock: int


class ReserveRequest(BaseModel):
    quantity: int


class ConfirmRequest(BaseModel):
    quantity: int


class ReleaseRequest(BaseModel):
    quantity: int


class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None


class ProductCreate(BaseModel):
    product_id: str
    name: str = "Product"
    price: float = 0.0
    stock: int = 0