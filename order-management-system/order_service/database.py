"""Database management for Order Service."""

import sqlite3
import os
from contextlib import contextmanager
from typing import Generator

DATABASE_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
os.makedirs(DATABASE_DIR, exist_ok=True)

ORDERS_DB = os.path.join(DATABASE_DIR, "orders.db")


@contextmanager
def get_orders_connection() -> Generator[sqlite3.Connection, None, None]:
    """Get a connection to the orders database."""
    conn = sqlite3.connect(ORDERS_DB)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


@contextmanager
def orders_transaction() -> Generator[sqlite3.Connection, None, None]:
    """Context manager for orders database transactions."""
    with get_orders_connection() as conn:
        conn.execute("BEGIN")
        try:
            yield conn
            conn.execute("COMMIT")
        except Exception:
            conn.execute("ROLLBACK")
            raise


def init_orders_db() -> None:
    """Initialize the orders database schema."""
    with get_orders_connection() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS orders (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                total_amount REAL NOT NULL DEFAULT 0.0,
                created_at TEXT NOT NULL
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS order_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id TEXT NOT NULL,
                product_id TEXT NOT NULL,
                quantity INTEGER NOT NULL,
                unit_price REAL NOT NULL DEFAULT 0.0,
                FOREIGN KEY (order_id) REFERENCES orders(id)
            )
        """)
        conn.commit()