"""Task Queue Management Service - HTTP API."""

import os
from flask import Flask, jsonify, request
from models import Database, PRIORITY_TO_INT, INT_TO_PRIORITY


def create_app(db_path: str = None) -> Flask:
    """Create and configure the Flask application."""
    app = Flask(__name__)

    if db_path is None:
        db_path = os.environ.get("DATABASE_PATH", "tasks.db")

    # Store db_path in app config for access
    app.config["DATABASE_PATH"] = db_path
    db = Database(db_path)

    @app.route("/tasks", methods=["POST"])
    def create_task():
        """Create a new task."""
        data = request.get_json()

        if not data or "description" not in data:
            return jsonify({"error": "description is required"}), 400

        description = data["description"]
        priority_str = data.get("priority", "medium")

        if priority_str not in PRIORITY_TO_INT:
            return jsonify({"error": "priority must be low, medium, or high"}), 400

        priority = PRIORITY_TO_INT[priority_str]
        task = db.create_task(description, priority)

        return jsonify({
            "id": task.id,
            "description": task.description,
            "priority": INT_TO_PRIORITY[task.priority],
            "status": task.status,
            "retry_count": task.retry_count,
            "max_retries": task.max_retries,
            "created_at": task.created_at,
            "updated_at": task.updated_at,
        }), 201

    @app.route("/tasks", methods=["GET"])
    def list_tasks():
        """List all tasks, optionally filtered by status."""
        status = request.args.get("status")
        tasks = db.get_all_tasks(status)

        return jsonify([{
            "id": task.id,
            "description": task.description,
            "priority": INT_TO_PRIORITY[task.priority],
            "status": task.status,
            "retry_count": task.retry_count,
            "max_retries": task.max_retries,
            "created_at": task.created_at,
            "updated_at": task.updated_at,
        } for task in tasks])

    @app.route("/tasks/<int:task_id>", methods=["GET"])
    def get_task(task_id: int):
        """Get a single task by ID."""
        task = db.get_task(task_id)

        if task is None:
            return jsonify({"error": "Task not found"}), 404

        return jsonify({
            "id": task.id,
            "description": task.description,
            "priority": INT_TO_PRIORITY[task.priority],
            "status": task.status,
            "retry_count": task.retry_count,
            "max_retries": task.max_retries,
            "created_at": task.created_at,
            "updated_at": task.updated_at,
        })

    @app.route("/tasks/<int:task_id>/claim", methods=["POST"])
    def claim_task(task_id: int):
        """Worker claims a specific task."""
        task = db.get_task(task_id)

        if task is None:
            return jsonify({"error": "Task not found"}), 404

        if task.status != "pending":
            return jsonify({"error": f"Task is {task.status}, cannot claim"}), 409

        # Try to claim atomically
        claimed_task = db.claim_task_by_id(task_id)

        if claimed_task is None:
            return jsonify({"error": "Task already claimed by another worker"}), 409

        return jsonify({
            "id": claimed_task.id,
            "description": claimed_task.description,
            "priority": INT_TO_PRIORITY[claimed_task.priority],
            "status": claimed_task.status,
            "retry_count": claimed_task.retry_count,
            "max_retries": claimed_task.max_retries,
            "created_at": claimed_task.created_at,
            "updated_at": claimed_task.updated_at,
        })

    @app.route("/tasks/claim", methods=["POST"])
    def claim_any_task():
        """Worker claims the highest priority pending task."""
        task = db.claim_task()

        if task is None:
            return jsonify({"error": "No pending tasks available"}), 404

        return jsonify({
            "id": task.id,
            "description": task.description,
            "priority": INT_TO_PRIORITY[task.priority],
            "status": task.status,
            "retry_count": task.retry_count,
            "max_retries": task.max_retries,
            "created_at": task.created_at,
            "updated_at": task.updated_at,
        })

    @app.route("/tasks/<int:task_id>/complete", methods=["POST"])
    def complete_task(task_id: int):
        """Mark a task as completed."""
        task = db.complete_task(task_id)

        if task is None:
            return jsonify({"error": "Task not found or not in running state"}), 404

        return jsonify({
            "id": task.id,
            "description": task.description,
            "priority": INT_TO_PRIORITY[task.priority],
            "status": task.status,
            "retry_count": task.retry_count,
            "max_retries": task.max_retries,
            "created_at": task.created_at,
            "updated_at": task.updated_at,
        })

    @app.route("/tasks/<int:task_id>/fail", methods=["POST"])
    def fail_task(task_id: int):
        """Mark a task as failed, triggering retry if under max retries."""
        task = db.fail_task(task_id)

        if task is None:
            return jsonify({"error": "Task not found or not in running state"}), 404

        return jsonify({
            "id": task.id,
            "description": task.description,
            "priority": INT_TO_PRIORITY[task.priority],
            "status": task.status,
            "retry_count": task.retry_count,
            "max_retries": task.max_retries,
            "created_at": task.created_at,
            "updated_at": task.updated_at,
        })

    @app.route("/queues", methods=["GET"])
    def get_queue_stats():
        """Get queue statistics."""
        stats = db.get_queue_stats()
        return jsonify(stats)

    return app


# Create default app instance for running directly
app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
