"""Unit tests for the Inventory Service."""

import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from fastapi.testclient import TestClient
import sqlite3

# Remove existing test databases before importing app
from inventory_service.main import app
from inventory_service.database import INVENTORY_DB, init_inventory_db

# Reset database for testing
if os.path.exists(INVENTORY_DB):
    os.remove(INVENTORY_DB)

# Initialize fresh database
init_inventory_db()


@pytest.fixture
def client():
    """Create a test client."""
    return TestClient(app)


@pytest.fixture(autouse=True)
def reset_database():
    """Reset database before each test."""
    with sqlite3.connect(INVENTORY_DB) as conn:
        conn.execute("DELETE FROM products")
        conn.commit()
    yield


def create_product(client, product_id: str, stock: int, name: str = "Test Product", price: float = 10.0):
    """Helper to create a product with stock."""
    response = client.post("/products", json={
        "product_id": product_id,
        "name": name,
        "price": price,
        "stock": stock
    })
    assert response.status_code == 201
    return response.json()


class TestCreateProduct:
    """Tests for product creation."""

    def test_create_product_success(self, client):
        """Test successful product creation."""
        response = client.post("/products", json={
            "product_id": "PROD-001",
            "name": "Test Product",
            "price": 25.99,
            "stock": 100
        })

        assert response.status_code == 201
        data = response.json()
        assert data["product_id"] == "PROD-001"
        assert data["available_stock"] == 100
        assert data["reserved_stock"] == 0


class TestGetStock:
    """Tests for getting stock information."""

    def test_get_stock_success(self, client):
        """Test getting stock for existing product."""
        create_product(client, "PROD-001", 50)

        response = client.get("/products/PROD-001/stock")
        assert response.status_code == 200
        data = response.json()
        assert data["product_id"] == "PROD-001"
        assert data["available_stock"] == 50
        assert data["reserved_stock"] == 0

    def test_get_nonexistent_product(self, client):
        """Test getting stock for non-existent product returns 404."""
        response = client.get("/products/NONEXISTENT/stock")
        assert response.status_code == 404


class TestSetStock:
    """Tests for setting stock."""

    def test_set_stock_success(self, client):
        """Test setting stock for existing product."""
        create_product(client, "PROD-001", 50)

        response = client.post("/products/PROD-001/stock", json={"stock": 100})
        assert response.status_code == 200
        data = response.json()
        assert data["available_stock"] == 100

    def test_set_stock_below_reserved_fails(self, client):
        """Test setting stock below reserved amount fails."""
        create_product(client, "PROD-001", 50)

        # Reserve some stock
        client.post("/products/PROD-001/reserve", json={"quantity": 30})

        # Try to set stock below reserved
        response = client.post("/products/PROD-001/stock", json={"stock": 20})
        assert response.status_code == 400


class TestReserveStock:
    """Tests for stock reservation."""

    def test_reserve_stock_success(self, client):
        """Test successful stock reservation."""
        create_product(client, "PROD-001", 100)

        response = client.post("/products/PROD-001/reserve", json={"quantity": 30})
        assert response.status_code == 200
        data = response.json()
        assert data["available_stock"] == 70
        assert data["reserved_stock"] == 30

    def test_reserve_insufficient_stock(self, client):
        """Test reservation fails with insufficient stock."""
        create_product(client, "PROD-001", 10)

        response = client.post("/products/PROD-001/reserve", json={"quantity": 20})
        assert response.status_code == 400
        assert "Insufficient stock" in response.json()["error"]

    def test_reserve_nonexistent_product(self, client):
        """Test reservation fails for non-existent product."""
        response = client.post("/products/NONEXISTENT/reserve", json={"quantity": 10})
        assert response.status_code == 404

    def test_multiple_reservations(self, client):
        """Test multiple reservations accumulate correctly."""
        create_product(client, "PROD-001", 100)

        # First reservation
        client.post("/products/PROD-001/reserve", json={"quantity": 30})
        response = client.get("/products/PROD-001/stock")
        assert response.json()["reserved_stock"] == 30

        # Second reservation
        client.post("/products/PROD-001/reserve", json={"quantity": 20})
        response = client.get("/products/PROD-001/stock")
        assert response.json()["reserved_stock"] == 50
        assert response.json()["available_stock"] == 50


class TestConfirmDeduction:
    """Tests for stock deduction confirmation."""

    def test_confirm_deduction_success(self, client):
        """Test successful stock deduction confirmation."""
        create_product(client, "PROD-001", 100)

        # Reserve stock first
        client.post("/products/PROD-001/reserve", json={"quantity": 30})

        # Confirm deduction
        response = client.post("/products/PROD-001/confirm", json={"quantity": 30})
        assert response.status_code == 200
        data = response.json()
        assert data["available_stock"] == 70
        assert data["reserved_stock"] == 0
        assert data["available_stock"] + data["reserved_stock"] == 70  # Total decreased

    def test_confirm_deduction_without_reservation(self, client):
        """Test confirmation without prior reservation."""
        create_product(client, "PROD-001", 100)

        # Confirm deduction without reservation (direct deduction)
        response = client.post("/products/PROD-001/confirm", json={"quantity": 30})
        assert response.status_code == 200
        data = response.json()
        assert data["available_stock"] == 70
        assert data["reserved_stock"] == 0


class TestReleaseReservation:
    """Tests for releasing reservations."""

    def test_release_reservation_success(self, client):
        """Test successful reservation release."""
        create_product(client, "PROD-001", 100)

        # Reserve stock
        client.post("/products/PROD-001/reserve", json={"quantity": 50})

        # Release reservation
        response = client.post("/products/PROD-001/release", json={"quantity": 30})
        assert response.status_code == 200
        data = response.json()
        assert data["available_stock"] == 80  # 100 - 20 (still reserved)
        assert data["reserved_stock"] == 20

    def test_release_more_than_reserved(self, client):
        """Test releasing more than reserved caps at zero."""
        create_product(client, "PROD-001", 100)

        # Reserve 30
        client.post("/products/PROD-001/reserve", json={"quantity": 30})

        # Try to release 50 (should cap at 0)
        response = client.post("/products/PROD-001/release", json={"quantity": 50})
        assert response.status_code == 200
        data = response.json()
        assert data["reserved_stock"] == 0
        assert data["available_stock"] == 100


class TestOversellingPrevention:
    """Tests for overselling prevention."""

    def test_prevent_overselling(self, client):
        """Test that stock reservation prevents overselling."""
        create_product(client, "PROD-001", 10)

        # Reserve all 10
        response = client.post("/products/PROD-001/reserve", json={"quantity": 10})
        assert response.status_code == 200
        assert response.json()["available_stock"] == 0

        # Try to reserve more - should fail
        response = client.post("/products/PROD-001/reserve", json={"quantity": 1})
        assert response.status_code == 400


if __name__ == "__main__":
    pytest.main([__file__, "-v"])