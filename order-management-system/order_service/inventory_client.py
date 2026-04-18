"""HTTP client for calling Inventory Service."""

import httpx
from typing import Optional

INVENTORY_SERVICE_URL = "http://localhost:8082"


class InventoryServiceError(Exception):
    """Raised when Inventory Service returns an error."""
    pass


class ProductNotFoundError(Exception):
    """Raised when product is not found in Inventory Service."""
    pass


class InsufficientStockError(Exception):
    """Raised when there is insufficient stock."""
    pass


class ServiceConnectionError(Exception):
    """Raised when unable to connect to Inventory Service."""
    pass


def handle_inventory_response(response: httpx.Response) -> dict:
    """Handle response from Inventory Service and raise appropriate errors."""
    if response.status_code == 404:
        raise ProductNotFoundError(f"Product not found: {response.json().get('detail', 'Unknown')}")
    elif response.status_code == 400:
        error_data = response.json()
        raise InsufficientStockError(error_data.get("detail", str(error_data)))
    elif response.status_code >= 400:
        error_data = response.json()
        raise InventoryServiceError(f"Inventory Service error: {error_data.get('error', 'Unknown')}")
    return response.json()


def reserve_stock(product_id: str, quantity: int) -> dict:
    """
    Call Inventory Service to reserve stock.

    Args:
        product_id: The product ID
        quantity: The quantity to reserve

    Returns:
        Stock info dict with available_stock and reserved_stock

    Raises:
        ProductNotFoundError: If the product does not exist
        InsufficientStockError: If there is not enough available stock
        ServiceConnectionError: If the service is unavailable
    """
    try:
        with httpx.Client(timeout=10.0) as client:
            response = client.post(
                f"{INVENTORY_SERVICE_URL}/products/{product_id}/reserve",
                json={"quantity": quantity}
            )
            return handle_inventory_response(response)
    except Exception as e:
        if "connect" in str(e).lower() or "timeout" in str(e).lower():
            raise ServiceConnectionError(f"Failed to connect to Inventory Service: {e}")
        raise


def release_stock(product_id: str, quantity: int) -> dict:
    """
    Call Inventory Service to release reserved stock.

    Args:
        product_id: The product ID
        quantity: The quantity to release

    Returns:
        Stock info dict

    Raises:
        ProductNotFoundError: If the product does not exist
        ServiceConnectionError: If the service is unavailable
    """
    try:
        with httpx.Client(timeout=10.0) as client:
            response = client.post(
                f"{INVENTORY_SERVICE_URL}/products/{product_id}/release",
                json={"quantity": quantity}
            )
            return handle_inventory_response(response)
    except Exception as e:
        if "connect" in str(e).lower() or "timeout" in str(e).lower():
            raise ServiceConnectionError(f"Failed to connect to Inventory Service: {e}")
        raise


def confirm_stock(product_id: str, quantity: int) -> dict:
    """
    Call Inventory Service to confirm stock deduction.

    Args:
        product_id: The product ID
        quantity: The quantity to confirm/deduct

    Returns:
        Stock info dict

    Raises:
        ProductNotFoundError: If the product does not exist
        ServiceConnectionError: If the service is unavailable
    """
    try:
        with httpx.Client(timeout=10.0) as client:
            response = client.post(
                f"{INVENTORY_SERVICE_URL}/products/{product_id}/confirm",
                json={"quantity": quantity}
            )
            return handle_inventory_response(response)
    except Exception as e:
        if "connect" in str(e).lower() or "timeout" in str(e).lower():
            raise ServiceConnectionError(f"Failed to connect to Inventory Service: {e}")
        raise


def get_product_stock(product_id: str) -> dict:
    """
    Call Inventory Service to get product stock info.

    Args:
        product_id: The product ID

    Returns:
        Stock info dict

    Raises:
        ProductNotFoundError: If the product does not exist
        ServiceConnectionError: If the service is unavailable
    """
    try:
        with httpx.Client(timeout=10.0) as client:
            response = client.get(f"{INVENTORY_SERVICE_URL}/products/{product_id}/stock")
            return handle_inventory_response(response)
    except Exception as e:
        if "connect" in str(e).lower() or "timeout" in str(e).lower():
            raise ServiceConnectionError(f"Failed to connect to Inventory Service: {e}")
        raise