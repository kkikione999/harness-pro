"""Database management for Inventory Service."""

import sqlite3
import os
from contextlib import contextmanager
from typing import Generator, Optional

DATABASE_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
os.makedirs(DATABASE_DIR, exist_ok=True)

INVENTORY_DB = os.path.join(DATABASE_DIR, "inventory.db")


@contextmanager
def get_inventory_connection() -> Generator[sqlite3.Connection, None, None]:
    """Get a connection to the inventory database."""
    conn = sqlite3.connect(INVENTORY_DB)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


@contextmanager
def inventory_transaction() -> Generator[sqlite3.Connection, None, None]:
    """Context manager for inventory database transactions."""
    with get_inventory_connection() as conn:
        conn.execute("BEGIN")
        try:
            yield conn
            conn.execute("COMMIT")
        except Exception:
            conn.execute("ROLLBACK")
            raise


def init_inventory_db() -> None:
    """Initialize the inventory database schema."""
    with get_inventory_connection() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS products (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                price REAL NOT NULL DEFAULT 0.0,
                total_stock INTEGER NOT NULL DEFAULT 0,
                reserved_stock INTEGER NOT NULL DEFAULT 0
            )
        """)
        conn.commit()


def get_product(conn: sqlite3.Connection, product_id: str) -> Optional[dict]:
    """Get product by ID."""
    cursor = conn.execute(
        "SELECT id, name, price, total_stock, reserved_stock FROM products WHERE id = ?",
        (product_id,)
    )
    row = cursor.fetchone()
    if not row:
        return None
    return {
        "id": row["id"],
        "name": row["name"],
        "price": row["price"],
        "total_stock": row["total_stock"],
        "reserved_stock": row["reserved_stock"],
    }


def get_available_stock(product_id: str) -> Optional[int]:
    """Get available stock for a product (total - reserved)."""
    with get_inventory_connection() as conn:
        product = get_product(conn, product_id)
        if not product:
            return None
        return product["total_stock"] - product["reserved_stock"]