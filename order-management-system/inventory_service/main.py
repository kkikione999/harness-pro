"""FastAPI application for the Inventory Service."""

from fastapi import FastAPI, HTTPException, status
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager

from .models import (
    StockAdjustRequest,
    StockResponse,
    ReserveRequest,
    ConfirmRequest,
    ReleaseRequest,
    ErrorResponse,
    ProductCreate,
)
from .services import (
    get_product_stock_info,
    set_product_stock,
    reserve_stock,
    confirm_deduction,
    release_reservation,
    create_product,
    ProductNotFoundError,
    InsufficientStockError,
)
from .database import init_inventory_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database on startup."""
    init_inventory_db()
    yield


app = FastAPI(
    title="Inventory Service",
    description="Manages product inventory, stock reservation, and deduction",
    version="1.0.0",
    lifespan=lifespan,
)


@app.exception_handler(ProductNotFoundError)
async def product_not_found_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_404_NOT_FOUND,
        content={"error": "Product not found", "detail": str(exc)},
    )


@app.exception_handler(InsufficientStockError)
async def insufficient_stock_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"error": "Insufficient stock", "detail": str(exc)},
    )


@app.exception_handler(ValueError)
async def value_error_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"error": "Bad request", "detail": str(exc)},
    )


@app.post("/products", response_model=StockResponse, status_code=status.HTTP_201_CREATED)
async def create_product_endpoint(product_data: ProductCreate):
    """
    Create a new product with initial stock.

    - **product_id**: The product ID
    - **name**: The product name (optional, defaults to "Product")
    - **price**: The product price (optional, defaults to 0.0)
    - **stock**: The initial stock quantity
    """
    product = create_product(
        product_data.product_id,
        product_data.name,
        product_data.price,
        product_data.stock
    )

    return StockResponse(
        product_id=product["id"],
        available_stock=product["total_stock"],
        reserved_stock=0,
    )


@app.post("/products/{product_id}/stock", response_model=StockResponse)
async def set_stock_endpoint(product_id: str, stock_data: StockAdjustRequest):
    """
    Initialize or update product stock.

    - **product_id**: The product ID to update
    - **stock**: The stock quantity to set
    """
    stock_info = set_product_stock(product_id, stock_data.stock)

    return StockResponse(
        product_id=stock_info["product_id"],
        available_stock=stock_info["available_stock"],
        reserved_stock=stock_info["reserved_stock"],
    )


@app.get("/products/{product_id}/stock", response_model=StockResponse)
async def get_stock_endpoint(product_id: str):
    """
    Get product stock information.

    - **product_id**: The product ID to query
    """
    stock_info = get_product_stock_info(product_id)
    if not stock_info:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product {product_id} not found",
        )

    return StockResponse(
        product_id=stock_info["product_id"],
        available_stock=stock_info["available_stock"],
        reserved_stock=stock_info["reserved_stock"],
    )


@app.post("/products/{product_id}/reserve", response_model=StockResponse)
async def reserve_stock_endpoint(product_id: str, request: ReserveRequest):
    """
    Reserve stock for a product (pre-allocation for an order).

    - **product_id**: The product ID
    - **quantity**: The quantity to reserve
    """
    stock_info = reserve_stock(product_id, request.quantity)

    return StockResponse(
        product_id=stock_info["product_id"],
        available_stock=stock_info["available_stock"],
        reserved_stock=stock_info["reserved_stock"],
    )


@app.post("/products/{product_id}/confirm", response_model=StockResponse)
async def confirm_deduction_endpoint(product_id: str, request: ConfirmRequest):
    """
    Confirm stock deduction after payment.

    - **product_id**: The product ID
    - **quantity**: The quantity to confirm/deduct
    """
    stock_info = confirm_deduction(product_id, request.quantity)

    return StockResponse(
        product_id=stock_info["product_id"],
        available_stock=stock_info["available_stock"],
        reserved_stock=stock_info["reserved_stock"],
    )


@app.post("/products/{product_id}/release", response_model=StockResponse)
async def release_reservation_endpoint(product_id: str, request: ReleaseRequest):
    """
    Release reserved stock (e.g., when order is cancelled).

    - **product_id**: The product ID
    - **quantity**: The quantity to release
    """
    stock_info = release_reservation(product_id, request.quantity)

    return StockResponse(
        product_id=stock_info["product_id"],
        available_stock=stock_info["available_stock"],
        reserved_stock=stock_info["reserved_stock"],
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8082)