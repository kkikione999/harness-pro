"""Unit tests for the Order Service."""

import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from fastapi.testclient import TestClient
import httpx
from unittest.mock import patch, MagicMock

# Set test environment before imports
os.environ["INVENTORY_SERVICE_URL"] = "http://localhost:8082"

# Remove existing test databases before importing app
from order_service.main import app
from order_service.database import ORDERS_DB, init_orders_db

# Reset database for testing
if os.path.exists(ORDERS_DB):
    os.remove(ORDERS_DB)

# Initialize fresh database
init_orders_db()


@pytest.fixture
def client():
    """Create a test client."""
    return TestClient(app)


@pytest.fixture(autouse=True)
def reset_database():
    """Reset database before each test."""
    import sqlite3
    with sqlite3.connect(ORDERS_DB) as conn:
        conn.execute("DELETE FROM order_items")
        conn.execute("DELETE FROM orders")
        conn.commit()
    yield


class TestCreateOrder:
    """Tests for order creation."""

    def test_create_order_success(self):
        """Test successful order creation."""
        with patch('httpx.Client') as mock_client:
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.json.return_value = {
                "product_id": "PROD-001",
                "available_stock": 98,
                "reserved_stock": 2
            }
            mock_client.return_value.__enter__.return_value.post.return_value = mock_response
            mock_client.return_value.__enter__.return_value.__exit__.return_value = None

            with TestClient(app) as client:
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

    def test_create_order_insufficient_stock(self):
        """Test that creating an order fails with insufficient stock."""
        with patch('httpx.Client') as mock_client:
            mock_response = MagicMock()
            mock_response.status_code = 400
            mock_response.json.return_value = {
                "error": "Insufficient stock",
                "detail": "Insufficient stock for product PROD-001"
            }
            mock_client.return_value.__enter__.return_value.post.return_value = mock_response
            mock_client.return_value.__enter__.return_value.__exit__.return_value = None

            with TestClient(app) as client:
                response = client.post("/orders", json={
                    "user_id": "USER-001",
                    "items": [{"product_id": "PROD-001", "quantity": 5}]
                })

                assert response.status_code == 400
                assert "Insufficient stock" in response.json()["error"]

    def test_create_order_product_not_found(self):
        """Test that creating an order fails for non-existent product."""
        with patch('httpx.Client') as mock_client:
            mock_response = MagicMock()
            mock_response.status_code = 404
            mock_response.json.return_value = {
                "error": "Product not found",
                "detail": "Product not found"
            }
            mock_client.return_value.__enter__.return_value.post.return_value = mock_response
            mock_client.return_value.__enter__.return_value.__exit__.return_value = None

            with TestClient(app) as client:
                response = client.post("/orders", json={
                    "user_id": "USER-001",
                    "items": [{"product_id": "NONEXISTENT", "quantity": 1}]
                })

                assert response.status_code == 404
                assert "not found" in response.json()["error"].lower()


class TestPayOrder:
    """Tests for order payment."""

    def test_pay_order_success(self):
        """Test successful order payment."""
        with patch('httpx.Client') as mock_client:
            # Reserve response for order creation
            reserve_response = MagicMock()
            reserve_response.status_code = 200
            reserve_response.json.return_value = {
                "product_id": "PROD-001",
                "available_stock": 97,
                "reserved_stock": 3
            }

            # Confirm response for payment
            confirm_response = MagicMock()
            confirm_response.status_code = 200
            confirm_response.json.return_value = {
                "product_id": "PROD-001",
                "available_stock": 97,
                "reserved_stock": 0
            }

            mock_client.return_value.__enter__.return_value.post.return_value = reserve_response
            mock_client.return_value.__enter__.return_value.get.return_value = reserve_response
            mock_client.return_value.__enter__.return_value.__exit__.return_value = None

            def side_effect(url, **kwargs):
                if "/reserve" in url:
                    return reserve_response
                elif "/confirm" in url:
                    return confirm_response
                return reserve_response

            mock_client.return_value.__enter__.return_value.post.side_effect = side_effect

            with TestClient(app) as client:
                # Create order first
                order_response = client.post("/orders", json={
                    "user_id": "USER-001",
                    "items": [{"product_id": "PROD-001", "quantity": 3}]
                })
                order_id = order_response.json()["id"]

                # Reset mock for pay call
                mock_client.return_value.__enter__.return_value.post.side_effect = None
                mock_client.return_value.__enter__.return_value.post.return_value = confirm_response

                # Pay order
                response = client.post(f"/orders/{order_id}/pay")
                assert response.status_code == 200
                assert response.json()["status"] == "paid"

    def test_pay_nonexistent_order(self):
        """Test paying a non-existent order returns 404."""
        with TestClient(app) as client:
            response = client.post("/orders/NONEXISTENT/pay")
            assert response.status_code == 404


class TestCancelOrder:
    """Tests for order cancellation."""

    def test_cancel_order_success(self):
        """Test successful order cancellation."""
        with patch('httpx.Client') as mock_client:
            # Reserve response for order creation
            reserve_response = MagicMock()
            reserve_response.status_code = 200
            reserve_response.json.return_value = {
                "product_id": "PROD-001",
                "available_stock": 97,
                "reserved_stock": 3
            }

            # Release response for cancellation
            release_response = MagicMock()
            release_response.status_code = 200
            release_response.json.return_value = {
                "product_id": "PROD-001",
                "available_stock": 100,
                "reserved_stock": 0
            }

            def side_effect(url, **kwargs):
                if "/reserve" in url:
                    return reserve_response
                elif "/release" in url:
                    return release_response
                return reserve_response

            mock_client.return_value.__enter__.return_value.post.side_effect = side_effect
            mock_client.return_value.__enter__.return_value.__exit__.return_value = None

            with TestClient(app) as client:
                # Create order first
                order_response = client.post("/orders", json={
                    "user_id": "USER-001",
                    "items": [{"product_id": "PROD-001", "quantity": 3}]
                })
                order_id = order_response.json()["id"]

                # Cancel order
                response = client.post(f"/orders/{order_id}/cancel")
                assert response.status_code == 200
                assert response.json()["status"] == "cancelled"

    def test_cancel_nonexistent_order(self):
        """Test cancelling a non-existent order returns 404."""
        with TestClient(app) as client:
            response = client.post("/orders/NONEXISTENT/cancel")
            assert response.status_code == 404


class TestGetOrder:
    """Tests for getting order details."""

    def test_get_order_success(self):
        """Test getting order details."""
        with patch('httpx.Client') as mock_client:
            reserve_response = MagicMock()
            reserve_response.status_code = 200
            reserve_response.json.return_value = {
                "product_id": "PROD-001",
                "available_stock": 98,
                "reserved_stock": 2
            }

            mock_client.return_value.__enter__.return_value.post.return_value = reserve_response
            mock_client.return_value.__enter__.return_value.__exit__.return_value = None

            with TestClient(app) as client:
                # Create order first
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

    def test_get_nonexistent_order(self):
        """Test getting non-existent order returns 404."""
        with TestClient(app) as client:
            response = client.get("/orders/NONEXISTENT")
            assert response.status_code == 404


class TestServiceUnavailable:
    """Tests for service unavailability handling."""

    def test_pay_order_service_unavailable(self):
        """Test that paying an order fails gracefully when Inventory Service is down."""
        with patch('httpx.Client') as mock_client:
            # Reserve response for order creation
            reserve_response = MagicMock()
            reserve_response.status_code = 200
            reserve_response.json.return_value = {
                "product_id": "PROD-001",
                "available_stock": 97,
                "reserved_stock": 3
            }

            # Connection error on confirm
            from httpcore import ConnectError
            mock_client.return_value.__enter__.return_value.post.side_effect = ConnectError("Connection refused")
            mock_client.return_value.__enter__.return_value.__exit__.return_value = None

            def post_side_effect(url, **kwargs):
                if "/reserve" in url:
                    return reserve_response
                raise ConnectError("Connection refused")

            mock_client.return_value.__enter__.return_value.post.side_effect = post_side_effect

            with TestClient(app) as client:
                # Create order first
                order_response = client.post("/orders", json={
                    "user_id": "USER-001",
                    "items": [{"product_id": "PROD-001", "quantity": 3}]
                })
                order_id = order_response.json()["id"]

                # Try to pay order
                response = client.post(f"/orders/{order_id}/pay")
                assert response.status_code == 503
                assert "Service unavailable" in response.json()["error"]

    def test_cancel_order_service_unavailable(self):
        """Test that cancelling an order fails gracefully when Inventory Service is down."""
        with patch('httpx.Client') as mock_client:
            # Reserve response for order creation
            reserve_response = MagicMock()
            reserve_response.status_code = 200
            reserve_response.json.return_value = {
                "product_id": "PROD-001",
                "available_stock": 97,
                "reserved_stock": 3
            }

            from httpcore import ConnectError

            def post_side_effect(url, **kwargs):
                if "/reserve" in url:
                    return reserve_response
                raise ConnectError("Connection refused")

            mock_client.return_value.__enter__.return_value.post.side_effect = post_side_effect
            mock_client.return_value.__enter__.return_value.__exit__.return_value = None

            with TestClient(app) as client:
                # Create order first
                order_response = client.post("/orders", json={
                    "user_id": "USER-001",
                    "items": [{"product_id": "PROD-001", "quantity": 3}]
                })
                order_id = order_response.json()["id"]

                # Try to cancel order
                response = client.post(f"/orders/{order_id}/cancel")
                assert response.status_code == 503
                assert "Service unavailable" in response.json()["error"]


if __name__ == "__main__":
    pytest.main([__file__, "-v"])