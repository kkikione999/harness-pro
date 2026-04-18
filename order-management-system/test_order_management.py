"""Unit tests for the Order Management System."""

import pytest
from fastapi.testclient import TestClient
import os
import sqlite3

# Remove existing test databases before importing app
from main import app
from database import ORDERS_DB, PRODUCTS_DB, init_orders_db, init_products_db

# Reset databases for testing
if os.path.exists(ORDERS_DB):
    os.remove(ORDERS_DB)
if os.path.exists(PRODUCTS_DB):
    os.remove(PRODUCTS_DB)

# Initialize fresh databases
init_orders_db()
init_products_db()


@pytest.fixture
def client():
    """Create a test client."""
    return TestClient(app)


@pytest.fixture(autouse=True)
def reset_databases():
    """Reset databases before each test."""
    # Clear orders
    with sqlite3.connect(ORDERS_DB) as conn:
        conn.execute("DELETE FROM order_items")
        conn.execute("DELETE FROM orders")
        conn.commit()

    # Clear products
    with sqlite3.connect(PRODUCTS_DB) as conn:
        conn.execute("DELETE FROM products")
        conn.commit()

    yield


def create_product(client, product_id: str, stock: int):
    """Helper to create a product with stock."""
    response = client.post(f"/products/{product_id}/stock", json={"stock": stock})
    assert response.status_code == 200
    return response.json()


class TestCreateOrder:
    """Tests for order creation."""

    def test_create_order_success(self, client):
        """Test successful order creation."""
        # Setup: Create product with stock
        create_product(client, "PROD-001", 100)

        # Create order
        response = client.post("/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "PROD-001", "quantity": 2}]
        })

        assert response.status_code == 201
        data = response.json()
        assert data["user_id"] == "USER-001"
        assert data["status"] == "pending"
        assert len(data["items"]) == 1
        assert data["items"][0]["product_id"] == "PROD-001"
        assert data["items"][0]["quantity"] == 2

    def test_create_order_reserves_stock(self, client):
        """Test that creating an order reserves stock."""
        # Setup: Create product with stock
        create_product(client, "PROD-001", 100)

        # Check initial stock
        response = client.get("/products/PROD-001/stock")
        assert response.json()["available_stock"] == 100

        # Create order
        client.post("/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "PROD-001", "quantity": 5}]
        })

        # Check reserved stock
        response = client.get("/products/PROD-001/stock")
        data = response.json()
        assert data["available_stock"] == 95
        assert data["reserved_stock"] == 5

    def test_create_order_insufficient_stock(self, client):
        """Test that creating an order fails with insufficient stock."""
        # Setup: Create product with limited stock
        create_product(client, "PROD-001", 2)

        # Try to create order with more than available
        response = client.post("/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "PROD-001", "quantity": 5}]
        })

        assert response.status_code == 400
        assert "Insufficient stock" in response.json()["error"]

    def test_create_order_product_not_found(self, client):
        """Test that creating an order fails for non-existent product."""
        response = client.post("/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "NONEXISTENT", "quantity": 1}]
        })

        assert response.status_code == 404
        assert "not found" in response.json()["error"].lower()


class TestPayOrder:
    """Tests for order payment."""

    def test_pay_order_success(self, client):
        """Test successful order payment."""
        # Setup: Create product and order
        create_product(client, "PROD-001", 100)
        order_response = client.post("/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "PROD-001", "quantity": 3}]
        })
        order_id = order_response.json()["id"]

        # Pay order
        response = client.post(f"/orders/{order_id}/pay")
        assert response.status_code == 200
        assert response.json()["status"] == "paid"

    def test_pay_order_confirms_deduction(self, client):
        """Test that paying an order confirms stock deduction."""
        # Setup: Create product and order
        create_product(client, "PROD-001", 100)

        # Create order and get the order ID from response
        order_response = client.post("/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "PROD-001", "quantity": 10}]
        })
        order_id = order_response.json()["id"]

        # Pay the order
        client.post(f"/orders/{order_id}/pay")

        # Check stock is deducted
        response = client.get("/products/PROD-001/stock")
        data = response.json()
        assert data["available_stock"] == 90
        assert data["reserved_stock"] == 0

    def test_pay_nonexistent_order(self, client):
        """Test paying a non-existent order returns 404."""
        response = client.post("/orders/NONEXISTENT/pay")
        assert response.status_code == 404


class TestCancelOrder:
    """Tests for order cancellation."""

    def test_cancel_order_success(self, client):
        """Test successful order cancellation."""
        # Setup: Create product and order
        create_product(client, "PROD-001", 100)
        order_response = client.post("/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "PROD-001", "quantity": 3}]
        })
        order_id = order_response.json()["id"]

        # Cancel order
        response = client.post(f"/orders/{order_id}/cancel")
        assert response.status_code == 200
        assert response.json()["status"] == "cancelled"

    def test_cancel_order_releases_stock(self, client):
        """Test that cancelling an order releases reserved stock."""
        # Setup: Create product and order
        create_product(client, "PROD-001", 100)
        order_response = client.post("/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "PROD-001", "quantity": 5}]
        })
        order_id = order_response.json()["id"]

        # Cancel order
        client.post(f"/orders/{order_id}/cancel")

        # Check stock is restored
        response = client.get("/products/PROD-001/stock")
        data = response.json()
        assert data["available_stock"] == 100
        assert data["reserved_stock"] == 0


class TestOversellingPrevention:
    """Tests for overselling prevention."""

    def test_multiple_orders_reserve_correctly(self, client):
        """Test that multiple orders reserve stock correctly."""
        # Setup: Create product with limited stock
        create_product(client, "PROD-001", 10)

        # Create first order for 6
        response1 = client.post("/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "PROD-001", "quantity": 6}]
        })
        assert response1.status_code == 201

        # Create second order for 6 - should fail
        response2 = client.post("/orders", json={
            "user_id": "USER-002",
            "items": [{"product_id": "PROD-001", "quantity": 6}]
        })
        assert response2.status_code == 400

        # First order pays successfully
        client.post(f"/orders/{response1.json()['id']}/pay")

        # Check final stock
        response = client.get("/products/PROD-001/stock")
        data = response.json()
        assert data["available_stock"] == 4
        assert data["reserved_stock"] == 0


class TestGetOrder:
    """Tests for getting order details."""

    def test_get_order_success(self, client):
        """Test getting order details."""
        # Setup: Create product and order
        create_product(client, "PROD-001", 100)
        order_response = client.post("/orders", json={
            "user_id": "USER-001",
            "items": [{"product_id": "PROD-001", "quantity": 2}]
        })
        order_id = order_response.json()["id"]

        # Get order
        response = client.get(f"/orders/{order_id}")
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == order_id
        assert data["user_id"] == "USER-001"
        assert data["status"] == "pending"

    def test_get_nonexistent_order(self, client):
        """Test getting non-existent order returns 404."""
        response = client.get("/orders/NONEXISTENT")
        assert response.status_code == 404


class TestProductStock:
    """Tests for product stock operations."""

    def test_set_and_get_stock(self, client):
        """Test setting and getting stock."""
        # Set stock
        response = client.post("/products/PROD-001/stock", json={"stock": 50})
        assert response.status_code == 200
        assert response.json()["available_stock"] == 50

        # Get stock
        response = client.get("/products/PROD-001/stock")
        assert response.status_code == 200
        assert response.json()["available_stock"] == 50

    def test_get_nonexistent_product(self, client):
        """Test getting stock for non-existent product returns 404."""
        response = client.get("/products/NONEXISTENT/stock")
        assert response.status_code == 404


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
