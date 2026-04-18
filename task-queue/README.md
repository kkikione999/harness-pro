# Task Queue Management Service

A simple task queue service with SQLite storage and HTTP API.

## Quick Start

```bash
pip install -r requirements.txt
python app.py
```

The server starts on `http://localhost:8080`.

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/tasks` | Create a new task |
| GET | `/tasks` | List all tasks (filter with `?status=pending`) |
| GET | `/tasks/{id}` | Get a single task |
| POST | `/tasks/{id}/claim` | Claim a specific task |
| POST | `/tasks/claim` | Claim the highest priority pending task |
| POST | `/tasks/{id}/complete` | Mark task as completed |
| POST | `/tasks/{id}/fail` | Mark task as failed (auto-retry up to 3 times) |
| GET | `/queues` | View queue statistics |

## Examples

```bash
# Create a high priority task
curl -X POST http://localhost:8080/tasks \
  -H "Content-Type: application/json" \
  -d '{"description": "Process images", "priority": "high"}'

# List all pending tasks
curl http://localhost:8080/tasks?status=pending

# Claim a task (gets highest priority)
curl -X POST http://localhost:8080/tasks/claim

# Complete a task
curl -X POST http://localhost:8080/tasks/1/complete

# Mark task as failed (will retry)
curl -X POST http://localhost:8080/tasks/1/fail

# Check queue stats
curl http://localhost:8080/queues
```

## Running Tests

```bash
python -m pytest test_app.py -v
# or
python test_app.py
```
