"""FastAPI application for the Order Service."""

from fastapi import FastAPI, HTTPException, status
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager

from .models import (
    OrderCreate,
    OrderResponse,
    ErrorResponse,
)
from .services import (
    create_order,
    get_order,
    pay_order,
    cancel_order,
    OrderNotFoundError,
    InvalidOrderStateError,
    ServiceUnavailableError,
)
from .inventory_client import (
    ProductNotFoundError,
    InsufficientStockError,
    InventoryServiceError,
    ServiceConnectionError,
)
from .database import init_orders_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database on startup."""
    init_orders_db()
    yield


app = FastAPI(
    title="Order Service",
    description="Manages order CRUD, state machine, and coordinates with Inventory Service",
    version="1.0.0",
    lifespan=lifespan,
)


@app.exception_handler(OrderNotFoundError)
async def order_not_found_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_404_NOT_FOUND,
        content={"error": "Order not found", "detail": str(exc)},
    )


@app.exception_handler(InsufficientStockError)
async def insufficient_stock_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"error": "Insufficient stock", "detail": str(exc)},
    )


@app.exception_handler(ProductNotFoundError)
async def product_not_found_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_404_NOT_FOUND,
        content={"error": "Product not found", "detail": str(exc)},
    )


@app.exception_handler(InvalidOrderStateError)
async def invalid_order_state_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"error": "Invalid order state", "detail": str(exc)},
    )


@app.exception_handler(ServiceUnavailableError)
async def service_unavailable_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={"error": "Service unavailable", "detail": str(exc)},
    )


@app.exception_handler(ServiceConnectionError)
async def service_connection_error_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={"error": "Service unavailable", "detail": str(exc)},
    )


@app.exception_handler(InventoryServiceError)
async def inventory_service_error_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={"error": "Inventory Service error", "detail": str(exc)},
    )


@app.post("/orders", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
async def create_new_order(order_data: OrderCreate):
    """
    Create a new order with inventory reservation.

    - **user_id**: The user ID placing the order
    - **items**: List of items with product_id and quantity

    This endpoint calls the Inventory Service to reserve stock.
    """
    items = [{"product_id": item.product_id, "quantity": item.quantity} for item in order_data.items]
    order = create_order(order_data.user_id, items)

    return OrderResponse(
        id=order["id"],
        user_id=order["user_id"],
        status=order["status"],
        items=[
            {
                "product_id": item["product_id"],
                "quantity": item["quantity"],
                "unit_price": item["unit_price"],
            }
            for item in order["items"]
        ],
        total_amount=order["total_amount"],
        created_at=order["created_at"],
    )


@app.get("/orders/{order_id}", response_model=OrderResponse)
async def get_order_details(order_id: str):
    """
    Get order details by ID.

    - **order_id**: The order ID to retrieve
    """
    order = get_order(order_id)
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Order {order_id} not found",
        )

    return OrderResponse(
        id=order["id"],
        user_id=order["user_id"],
        status=order["status"],
        items=[
            {
                "product_id": item["product_id"],
                "quantity": item["quantity"],
                "unit_price": item["unit_price"],
            }
            for item in order["items"]
        ],
        total_amount=order["total_amount"],
        created_at=order["created_at"],
    )


@app.post("/orders/{order_id}/pay", response_model=OrderResponse)
async def pay_order_endpoint(order_id: str):
    """
    Pay for an order.

    This endpoint calls the Inventory Service to confirm stock deduction.

    - **order_id**: The order ID to pay
    """
    order = pay_order(order_id)

    return OrderResponse(
        id=order["id"],
        user_id=order["user_id"],
        status=order["status"],
        items=[
            {
                "product_id": item["product_id"],
                "quantity": item["quantity"],
                "unit_price": item["unit_price"],
            }
            for item in order["items"]
        ],
        total_amount=order["total_amount"],
        created_at=order["created_at"],
    )


@app.post("/orders/{order_id}/cancel", response_model=OrderResponse)
async def cancel_order_endpoint(order_id: str):
    """
    Cancel an order.

    This endpoint calls the Inventory Service to release reserved stock.

    - **order_id**: The order ID to cancel
    """
    order = cancel_order(order_id)

    return OrderResponse(
        id=order["id"],
        user_id=order["user_id"],
        status=order["status"],
        items=[
            {
                "product_id": item["product_id"],
                "quantity": item["quantity"],
                "unit_price": item["unit_price"],
            }
            for item in order["items"]
        ],
        total_amount=order["total_amount"],
        created_at=order["created_at"],
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8081)