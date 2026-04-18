"""Business logic services for Order Service."""

import uuid
from datetime import datetime
from typing import Optional

from .database import (
    get_orders_connection,
)
from .models import OrderStatus
from .inventory_client import (
    reserve_stock,
    release_stock,
    confirm_stock,
    ProductNotFoundError,
    InsufficientStockError,
    InventoryServiceError,
    ServiceConnectionError,
)


class OrderNotFoundError(Exception):
    """Raised when an order is not found."""
    pass


class InvalidOrderStateError(Exception):
    """Raised when an operation is invalid for the current order state."""
    pass


class ServiceUnavailableError(Exception):
    """Raised when the Inventory Service is unavailable."""
    pass


def generate_order_id() -> str:
    """Generate a unique order ID."""
    return f"ORD-{uuid.uuid4().hex[:12].upper()}"


def create_order(user_id: str, items: list[dict]) -> dict:
    """
    Create a new order with inventory reservation.

    Args:
        user_id: The user ID
        items: List of items [{"product_id": "...", "quantity": N}]

    Returns:
        The created order dict

    Raises:
        InsufficientStockError: If stock is not available
        ProductNotFoundError: If a product does not exist
        ServiceUnavailableError: If Inventory Service is unavailable
    """
    order_id = generate_order_id()
    created_at = datetime.utcnow().isoformat()

    # First, reserve stock for all items via Inventory Service
    reserved_items = []
    try:
        for item in items:
            product_id = item["product_id"]
            quantity = item["quantity"]

            # Call Inventory Service to reserve stock
            # The response includes available_stock and reserved_stock but not price
            # We need to track what we reserved
            stock_info = reserve_stock(product_id, quantity)

            reserved_items.append({
                "product_id": product_id,
                "quantity": quantity,
                "unit_price": 0.0,  # Price is not provided by inventory service
            })
    except (ProductNotFoundError, InsufficientStockError, InventoryServiceError, ServiceConnectionError) as e:
        # Rollback all previously reserved stock
        for item in reserved_items:
            try:
                release_stock(item["product_id"], item["quantity"])
            except Exception:
                pass  # Best effort rollback
        raise e

    # Now create the order with placeholder prices (0.0)
    # Note: In a real system, we'd get prices from Inventory Service or a catalog
    total_amount = sum(item["unit_price"] * item["quantity"] for item in reserved_items)

    try:
        with get_orders_connection() as order_conn:
            order_conn.execute(
                "INSERT INTO orders (id, user_id, status, total_amount, created_at) "
                "VALUES (?, ?, ?, ?, ?)",
                (order_id, user_id, OrderStatus.PENDING.value, total_amount, created_at)
            )

            for item in reserved_items:
                order_conn.execute(
                    "INSERT INTO order_items (order_id, product_id, quantity, unit_price) "
                    "VALUES (?, ?, ?, ?)",
                    (order_id, item["product_id"], item["quantity"], item["unit_price"])
                )

            order_conn.commit()
    except Exception as e:
        # Rollback stock reservations if order creation fails
        for item in reserved_items:
            try:
                release_stock(item["product_id"], item["quantity"])
            except Exception:
                pass  # Best effort rollback
        raise e

    return {
        "id": order_id,
        "user_id": user_id,
        "status": OrderStatus.PENDING.value,
        "items": reserved_items,
        "total_amount": total_amount,
        "created_at": created_at,
    }


def get_order(order_id: str) -> Optional[dict]:
    """Get order by ID."""
    with get_orders_connection() as conn:
        cursor = conn.execute(
            "SELECT id, user_id, status, total_amount, created_at FROM orders WHERE id = ?",
            (order_id,)
        )
        row = cursor.fetchone()
        if not row:
            return None

        cursor = conn.execute(
            "SELECT product_id, quantity, unit_price FROM order_items WHERE order_id = ?",
            (order_id,)
        )
        items = [
            {
                "product_id": item["product_id"],
                "quantity": item["quantity"],
                "unit_price": item["unit_price"],
            }
            for item in cursor.fetchall()
        ]

        return {
            "id": row["id"],
            "user_id": row["user_id"],
            "status": row["status"],
            "items": items,
            "total_amount": row["total_amount"],
            "created_at": row["created_at"],
        }


def pay_order(order_id: str) -> dict:
    """
    Pay for an order and confirm stock deduction.

    Args:
        order_id: The order ID

    Returns:
        The updated order dict

    Raises:
        OrderNotFoundError: If the order does not exist
        InvalidOrderStateError: If the order is not in pending state
        ServiceUnavailableError: If the Inventory Service is unavailable
    """
    order = get_order(order_id)
    if not order:
        raise OrderNotFoundError(f"Order {order_id} not found")

    if order["status"] != OrderStatus.PENDING.value:
        raise InvalidOrderStateError(
            f"Cannot pay order in {order['status']} state. Must be pending."
        )

    # Confirm stock deduction for each item via Inventory Service
    try:
        for item in order["items"]:
            confirm_stock(item["product_id"], item["quantity"])
    except (ProductNotFoundError, InventoryServiceError) as e:
        raise ServiceUnavailableError(f"Failed to confirm stock: {e}")

    # Update order status to paid
    with get_orders_connection() as order_conn:
        order_conn.execute(
            "UPDATE orders SET status = ? WHERE id = ?",
            (OrderStatus.PAID.value, order_id)
        )
        order_conn.commit()

    order["status"] = OrderStatus.PAID.value
    return order


def cancel_order(order_id: str) -> dict:
    """
    Cancel an order and release reserved stock.

    Args:
        order_id: The order ID

    Returns:
        The updated order dict

    Raises:
        OrderNotFoundError: If the order does not exist
        InvalidOrderStateError: If the order cannot be cancelled
        ServiceUnavailableError: If the Inventory Service is unavailable
    """
    order = get_order(order_id)
    if not order:
        raise OrderNotFoundError(f"Order {order_id} not found")

    if order["status"] not in [OrderStatus.PENDING.value]:
        raise InvalidOrderStateError(
            f"Cannot cancel order in {order['status']} state. Only pending orders can be cancelled."
        )

    # Release reserved stock for each item via Inventory Service
    try:
        for item in order["items"]:
            release_stock(item["product_id"], item["quantity"])
    except (ProductNotFoundError, InventoryServiceError) as e:
        raise ServiceUnavailableError(f"Failed to release stock: {e}")

    # Update order status to cancelled
    with get_orders_connection() as order_conn:
        order_conn.execute(
            "UPDATE orders SET status = ? WHERE id = ?",
            (OrderStatus.CANCELLED.value, order_id)
        )
        order_conn.commit()

    order["status"] = OrderStatus.CANCELLED.value
    return order