"""Integration tests for the distributed Order Management System.

These tests verify the two services work correctly together.
"""

import pytest
import time
import subprocess
import httpx
import os
import sqlite3
from contextlib import contextmanager

# Paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INVENTORY_DIR = os.path.join(BASE_DIR, "inventory_service")
ORDER_DIR = os.path.join(BASE_DIR, "order_service")
DATA_DIR = os.path.join(BASE_DIR, "data")

INVENTORY_DB = os.path.join(DATA_DIR, "inventory.db")
ORDERS_DB = os.path.join(DATA_DIR, "orders.db")


@contextmanager
def start_services():
    """Start both services and ensure they're ready."""
    # Clean up any existing databases
    for db in [INVENTORY_DB, ORDERS_DB]:
        if os.path.exists(db):
            os.remove(db)

    # Start Inventory Service (run from BASE_DIR so module imports work)
    inventory_proc = subprocess.Popen(
        ["python3", "-m", "uvicorn", "inventory_service.main:app", "--host", "0.0.0.0", "--port", "8082"],
        cwd=BASE_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    # Start Order Service (run from BASE_DIR so module imports work)
    order_proc = subprocess.Popen(
        ["python3", "-m", "uvicorn", "order_service.main:app", "--host", "0.0.0.0", "--port", "8081"],
        cwd=BASE_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    # Wait for services to be ready
    inventory_ready = False
    order_ready = False
    max_wait = 30
    start_time = time.time()

    while time.time() - start_time < max_wait:
        try:
            resp = httpx.get("http://localhost:8082/docs", timeout=1.0)
            if resp.status_code == 200:
                inventory_ready = True
        except Exception:
            pass

        try:
            resp = httpx.get("http://localhost:8081/docs", timeout=1.0)
            if resp.status_code == 200:
                order_ready = True
        except Exception:
            pass

        if inventory_ready and order_ready:
            break

        time.sleep(0.5)

    if not inventory_ready:
        inventory_proc.kill()
        order_proc.kill()
        raise RuntimeError("Inventory Service failed to start")

    if not order_ready:
        inventory_proc.kill()
        order_proc.kill()
        raise RuntimeError("Order Service failed to start")

    try:
        yield
    finally:
        # Cleanup
        inventory_proc.terminate()
        order_proc.terminate()
        inventory_proc.wait(timeout=5)
        order_proc.wait(timeout=5)


@pytest.fixture(scope="module")
def services():
    """Fixture to start both services for integration tests."""
    with start_services():
        yield


class TestInventoryServiceAPI:
    """Tests for Inventory Service API."""

    def test_create_product(self, services):
        """Test creating a product."""
        response = httpx.post("http://localhost:8082/products", json={
            "product_id": "PROD-001",
            "name": "Test Product",
            "price": 25.99,
            "stock": 100
        })
        assert response.status_code == 201
        data = response.json()
        assert data["product_id"] == "PROD-001"
        assert data["available_stock"] == 100

    def test_get_stock(self, services):
        """Test getting stock."""
        httpx.post("http://localhost:8082/products", json={
            "product_id": "PROD-002",
            "name": "Product 2",
            "price": 10.0,
            "stock": 50
        })

        response = httpx.get("http://localhost:8082/products/PROD-002/stock")
        assert response.status_code == 200
        data = response.json()
        assert data["available_stock"] == 50

    def test_reserve_stock(self, services):
        """Test reserving stock."""
        httpx.post("http://localhost:8082/products", json={
            "product_id": "PROD-003",
            "name": "Product 3",
            "price": 15.0,
            "stock": 100
        })

        response = httpx.post("http://localhost:8082/products/PROD-003/reserve", json={
            "quantity": 30
        })
        assert response.status_code == 200
        data = response.json()
        assert data["available_stock"] == 70
        assert data["reserved_stock"] == 30

    def test_confirm_deduction(self, services):
        """Test confirming stock deduction."""
        httpx.post("http://localhost:8082/products", json={
            "product_id": "PROD-004",
            "name": "Product 4",
            "price": 20.0,
            "stock": 100
        })

        # Reserve
        httpx.post("http://localhost:8082/products/PROD-004/reserve", json={"quantity": 30})

        # Confirm
        response = httpx.post("http://localhost:8082/products/PROD-004/confirm", json={
            "quantity": 30
        })
        assert response.status_code == 200
        data = response.json()
        assert data["available_stock"] == 70
        assert data["reserved_stock"] == 0

    def test_release_reservation(self, services):
        """Test releasing reservation."""
        httpx.post("http://localhost:8082/products", json={
            "product_id": "PROD-005",
            "name": "Product 5",
            "price": 30.0,
            "stock": 100
        })

        # Reserve
        httpx.post("http://localhost:8082/products/PROD-005/reserve", json={"quantity": 50})

        # Release
        response = httpx.post("http://localhost:8082/products/PROD-005/release", json={
            "quantity": 30
        })
        assert response.status_code == 200
        data = response.json()
        assert data["available_stock"] == 80
        assert data["reserved_stock"] == 20


class TestDistributedFlow:
    """Tests for the complete distributed flow."""

    def test_create_order_flow(self, services):
        """Test creating an order reserves inventory."""
        # Setup: Create product
        httpx.post("http://localhost:8082/products", json={
            "product_id": "DIST-001",
            "name": "Distributed Product",
            "price": 50.0,
            "stock": 100
        })

        # Create order via Order Service
        response = httpx.post("http://localhost:8081/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "DIST-001", "quantity": 5}]
        })
        assert response.status_code == 201
        order = response.json()
        assert order["status"] == "pending"

        # Check inventory was reserved
        inv_response = httpx.get("http://localhost:8082/products/DIST-001/stock")
        inv_data = inv_response.json()
        assert inv_data["available_stock"] == 95
        assert inv_data["reserved_stock"] == 5

    def test_pay_order_confirms_inventory(self, services):
        """Test paying an order confirms inventory deduction."""
        # Setup: Create product
        httpx.post("http://localhost:8082/products", json={
            "product_id": "DIST-002",
            "name": "Distributed Product 2",
            "price": 30.0,
            "stock": 100
        })

        # Create order
        order_response = httpx.post("http://localhost:8081/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "DIST-002", "quantity": 10}]
        })
        order_id = order_response.json()["id"]

        # Pay order
        pay_response = httpx.post(f"http://localhost:8081/orders/{order_id}/pay")
        assert pay_response.status_code == 200
        assert pay_response.json()["status"] == "paid"

        # Check inventory was confirmed/deducted
        inv_response = httpx.get("http://localhost:8082/products/DIST-002/stock")
        inv_data = inv_response.json()
        assert inv_data["available_stock"] == 90
        assert inv_data["reserved_stock"] == 0

    def test_cancel_order_releases_inventory(self, services):
        """Test cancelling an order releases inventory reservation."""
        # Setup: Create product
        httpx.post("http://localhost:8082/products", json={
            "product_id": "DIST-003",
            "name": "Distributed Product 3",
            "price": 40.0,
            "stock": 100
        })

        # Create order
        order_response = httpx.post("http://localhost:8081/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "DIST-003", "quantity": 15}]
        })
        order_id = order_response.json()["id"]

        # Cancel order
        cancel_response = httpx.post(f"http://localhost:8081/orders/{order_id}/cancel")
        assert cancel_response.status_code == 200
        assert cancel_response.json()["status"] == "cancelled"

        # Check inventory was released
        inv_response = httpx.get("http://localhost:8082/products/DIST-003/stock")
        inv_data = inv_response.json()
        assert inv_data["available_stock"] == 100
        assert inv_data["reserved_stock"] == 0

    def test_insufficient_stock_prevents_order(self, services):
        """Test that insufficient stock prevents order creation."""
        # Setup: Create product with limited stock
        httpx.post("http://localhost:8082/products", json={
            "product_id": "DIST-004",
            "name": "Limited Product",
            "price": 25.0,
            "stock": 5
        })

        # Try to create order with more than available
        response = httpx.post("http://localhost:8081/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "DIST-004", "quantity": 10}]
        })
        assert response.status_code == 400
        assert "Insufficient stock" in response.json()["error"]

    def test_overselling_prevented(self, services):
        """Test that overselling is prevented across services."""
        # Setup: Create product with limited stock
        httpx.post("http://localhost:8082/products", json={
            "product_id": "DIST-005",
            "name": "Rare Product",
            "price": 100.0,
            "stock": 10
        })

        # First order succeeds
        response1 = httpx.post("http://localhost:8081/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "DIST-005", "quantity": 6}]
        })
        assert response1.status_code == 201

        # Second order fails (only 4 left)
        response2 = httpx.post("http://localhost:8081/orders", json={
            "user_id": "USER-002",
            "items": [{"product_id": "DIST-005", "quantity": 6}]
        })
        assert response2.status_code == 400

    def test_service_independence(self, services):
        """Test that services can be queried independently."""
        # Create product
        httpx.post("http://localhost:8082/products", json={
            "product_id": "IND-001",
            "name": "Independent Product",
            "price": 50.0,
            "stock": 100
        })

        # Both services should respond
        inv_resp = httpx.get("http://localhost:8082/products/IND-001/stock")
        assert inv_resp.status_code == 200

        # Even without orders, Order Service should respond to non-existent order query
        order_resp = httpx.get("http://localhost:8081/orders/NONEXISTENT")
        assert order_resp.status_code == 404


if __name__ == "__main__":
    pytest.main([__file__, "-v"])