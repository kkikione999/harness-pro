"""Business logic services for Inventory Service."""

from typing import Optional

from .database import (
    get_inventory_connection,
    get_product,
)


class ProductNotFoundError(Exception):
    """Raised when a product is not found."""
    pass


class InsufficientStockError(Exception):
    """Raised when there is insufficient stock."""
    pass


def create_product(product_id: str, name: str, price: float, stock: int) -> dict:
    """
    Create a new product with initial stock.

    Args:
        product_id: The product ID
        name: The product name
        price: The product price
        stock: The initial stock quantity

    Returns:
        The product dict
    """
    with get_inventory_connection() as conn:
        conn.execute(
            "INSERT INTO products (id, name, price, total_stock, reserved_stock) "
            "VALUES (?, ?, ?, ?, 0)",
            (product_id, name, price, stock)
        )
        conn.commit()

    return {
        "id": product_id,
        "name": name,
        "price": price,
        "total_stock": stock,
        "reserved_stock": 0,
    }


def get_product_stock_info(product_id: str) -> Optional[dict]:
    """
    Get stock information for a product.

    Args:
        product_id: The product ID

    Returns:
        Stock info dict or None if product not found
    """
    with get_inventory_connection() as conn:
        product = get_product(conn, product_id)
        if not product:
            return None
        return {
            "product_id": product["id"],
            "available_stock": product["total_stock"] - product["reserved_stock"],
            "reserved_stock": product["reserved_stock"],
        }


def set_product_stock(product_id: str, stock: int) -> dict:
    """
    Update product total stock.

    Args:
        product_id: The product ID
        stock: The new total stock quantity

    Returns:
        The updated product stock info
    """
    with get_inventory_connection() as conn:
        product = get_product(conn, product_id)
        if not product:
            raise ProductNotFoundError(f"Product {product_id} not found")

        # Ensure stock is not less than already reserved
        if stock < product["reserved_stock"]:
            raise ValueError(
                f"Cannot set stock to {stock}, product has {product['reserved_stock']} reserved"
            )

        conn.execute(
            "UPDATE products SET total_stock = ? WHERE id = ?",
            (stock, product_id)
        )
        conn.commit()

    return {
        "product_id": product_id,
        "available_stock": stock - product["reserved_stock"],
        "reserved_stock": product["reserved_stock"],
    }


def reserve_stock(product_id: str, quantity: int) -> dict:
    """
    Reserve stock for a product (pre-allocation for an order).

    Args:
        product_id: The product ID
        quantity: The quantity to reserve

    Returns:
        The updated stock info

    Raises:
        ProductNotFoundError: If the product does not exist
        InsufficientStockError: If there is not enough available stock
    """
    with get_inventory_connection() as conn:
        product = get_product(conn, product_id)
        if not product:
            raise ProductNotFoundError(f"Product {product_id} not found")

        available = product["total_stock"] - product["reserved_stock"]
        if available < quantity:
            raise InsufficientStockError(
                f"Insufficient stock for product {product_id}: "
                f"requested {quantity}, available {available}"
            )

        # Reserve the stock
        new_reserved = product["reserved_stock"] + quantity
        conn.execute(
            "UPDATE products SET reserved_stock = ? WHERE id = ?",
            (new_reserved, product_id)
        )
        conn.commit()

        return {
            "product_id": product_id,
            "available_stock": product["total_stock"] - new_reserved,
            "reserved_stock": new_reserved,
        }


def confirm_deduction(product_id: str, quantity: int) -> dict:
    """
    Confirm stock deduction after payment.

    Args:
        product_id: The product ID
        quantity: The quantity to confirm/deduct

    Returns:
        The updated stock info

    Raises:
        ProductNotFoundError: If the product does not exist
    """
    with get_inventory_connection() as conn:
        product = get_product(conn, product_id)
        if not product:
            raise ProductNotFoundError(f"Product {product_id} not found")

        # Convert reserved to actual deduction
        new_total = product["total_stock"] - quantity
        new_reserved = max(0, product["reserved_stock"] - quantity)

        conn.execute(
            "UPDATE products SET total_stock = ?, reserved_stock = ? WHERE id = ?",
            (new_total, new_reserved, product_id)
        )
        conn.commit()

        return {
            "product_id": product_id,
            "available_stock": new_total - new_reserved,
            "reserved_stock": new_reserved,
        }


def release_reservation(product_id: str, quantity: int) -> dict:
    """
    Release reserved stock (e.g., when order is cancelled).

    Args:
        product_id: The product ID
        quantity: The quantity to release

    Returns:
        The updated stock info

    Raises:
        ProductNotFoundError: If the product does not exist
    """
    with get_inventory_connection() as conn:
        product = get_product(conn, product_id)
        if not product:
            raise ProductNotFoundError(f"Product {product_id} not found")

        # Release the reservation
        new_reserved = max(0, product["reserved_stock"] - quantity)
        conn.execute(
            "UPDATE products SET reserved_stock = ? WHERE id = ?",
            (new_reserved, product_id)
        )
        conn.commit()

        return {
            "product_id": product_id,
            "available_stock": product["total_stock"] - new_reserved,
            "reserved_stock": new_reserved,
        }