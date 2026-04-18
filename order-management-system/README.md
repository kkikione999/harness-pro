# Distributed Order Management System

A distributed order management system with two independent services communicating via HTTP.

## Architecture

The system consists of two separate services:

1. **Order Service** (Port 8081)
   - Handles order CRUD operations
   - Manages order state machine (pending -> paid -> cancelled)
   - Calls Inventory Service for stock operations
   - Uses its own SQLite database (`orders.db`)

2. **Inventory Service** (Port 8082)
   - Manages product inventory
   - Handles stock reservation, confirmation, and release
   - Uses its own SQLite database (`inventory.db`)

```
┌─────────────────┐         HTTP          ┌─────────────────┐
│  Order Service  │ ◄─────────────────────► │ Inventory       │
│  (Port 8081)    │                        │ Service         │
│                 │                        │ (Port 8082)     │
│  - orders.db    │                        │  - inventory.db │
└─────────────────┘                        └─────────────────┘
```

## Features

- **Create Orders**: Automatically reserves inventory
- **Pay Orders**: Confirms stock deduction
- **Cancel Orders**: Releases reserved inventory
- **Overselling Prevention**: Inventory is atomically reserved
- **Service Independence**: Services can run and fail independently

## Requirements

- Python 3.10+

## Installation

```bash
# Install dependencies for both services
cd order_management_system

# Install Order Service dependencies
cd order_service
pip install -r requirements.txt

# Install Inventory Service dependencies
cd ../inventory_service
pip install -r requirements.txt
```

Or install all at once:

```bash
pip install -r requirements.txt
```

## Running the Services

You need to start both services. Open two terminal windows:

**Terminal 1 - Start Inventory Service:**
```bash
cd order_management_system/inventory_service
python -m uvicorn main:app --host 0.0.0.0 --port 8082
```

**Terminal 2 - Start Order Service:**
```bash
cd order_management_system/order_service
python -m uvicorn main:app --host 0.0.0.0 --port 8081
```

Both services will start with SQLite databases in the `data/` directory.

## API Endpoints

### Order Service (Port 8081)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/orders` | Create a new order |
| GET | `/orders/{id}` | Get order details |
| POST | `/orders/{id}/pay` | Pay for an order |
| POST | `/orders/{id}/cancel` | Cancel an order |

### Inventory Service (Port 8082)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/products` | Create a product with stock |
| POST | `/products/{id}/stock` | Set product stock |
| GET | `/products/{id}/stock` | Get stock info |
| POST | `/products/{id}/reserve` | Reserve stock |
| POST | `/products/{id}/confirm` | Confirm stock deduction |
| POST | `/products/{id}/release` | Release reserved stock |

## Example Usage

### 1. Initialize Product Stock

```bash
# Create a product with 100 units at $25.99 each
curl -X POST http://localhost:8082/products \
  -H "Content-Type: application/json" \
  -d '{
    "product_id": "PROD-001",
    "name": "Widget",
    "price": 25.99,
    "stock": 100
  }'
```

### 2. Check Stock

```bash
curl http://localhost:8082/products/PROD-001/stock
```

### 3. Create an Order

```bash
curl -X POST http://localhost:8081/orders \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "USER-001",
    "items": [{"product_id": "PROD-001", "quantity": 5}]
  }'
```

After creating an order:
- Order status is `pending`
- Inventory is reserved (available decreases, reserved increases)
- Stock check shows: `available_stock: 95, reserved_stock: 5`

### 4. Pay for the Order

```bash
curl -X POST http://localhost:8081/orders/{order_id}/pay
```

After payment:
- Order status changes to `paid`
- Inventory is confirmed/deducted
- Stock check shows: `available_stock: 95, reserved_stock: 0`

### 5. Cancel the Order

```bash
curl -X POST http://localhost:8081/orders/{order_id}/cancel
```

After cancellation:
- Order status changes to `cancelled`
- Reserved inventory is released
- Stock check shows: `available_stock: 100, reserved_stock: 0`

## Order Status Flow

```
pending ──┬──► paid ──► completed
          │
          └──► cancelled
```

- **pending**: Order created, inventory reserved
- **paid**: Payment confirmed, inventory deducted
- **cancelled**: Order cancelled, reserved inventory released
- **completed**: (Future) Order delivered

## Stock Flow

1. **Create Order**: Stock is reserved (available decreases, reserved increases)
2. **Pay Order**: Reserved stock is converted to actual deduction (total decreases, reserved decreases)
3. **Cancel Order**: Reserved stock is released back (available increases, reserved decreases)

## Running Tests

### Unit Tests for Inventory Service
```bash
cd tests
pytest test_inventory_service.py -v
```

### Unit Tests for Order Service
```bash
cd tests
pytest test_order_service.py -v
```

### Integration Tests
```bash
# Start both services first (as shown above)
# Then run integration tests
cd tests
pytest test_integration.py -v
```

## Error Handling

- **404 Not Found**: Order or product does not exist
- **400 Bad Request**: Insufficient stock, invalid order state
- **503 Service Unavailable**: Inventory Service is down when Order Service tries to call it

## Project Structure

```
order_management_system/
├── order_service/
│   ├── main.py              # FastAPI app (port 8081)
│   ├── models.py            # Pydantic models
│   ├── database.py          # SQLite for orders
│   ├── services.py          # Order business logic
│   ├── inventory_client.py  # HTTP client to Inventory Service
│   └── requirements.txt
├── inventory_service/
│   ├── main.py              # FastAPI app (port 8082)
│   ├── models.py            # Pydantic models
│   ├── database.py          # SQLite for inventory
│   ├── services.py          # Inventory business logic
│   └── requirements.txt
├── tests/
│   ├── test_inventory_service.py
│   ├── test_order_service.py
│   └── test_integration.py
├── data/                    # SQLite databases (created at runtime)
├── requirements.txt
└── README.md
```

## Key Design Decisions

1. **Separate Databases**: Each service has its own database to ensure independence
2. **HTTP Communication**: Services communicate via HTTP, not direct database access
3. **Stock Reservation Pattern**: Inventory is reserved before order creation to prevent overselling
4. **Two-Phase Commit**: Stock operations use reserve -> confirm/release pattern for consistency
5. **Graceful Degradation**: If Inventory Service is down, Order Service returns 503 but keeps its own state