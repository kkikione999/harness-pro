"""Unit tests for task queue service."""

import os
import tempfile
import unittest
from app import create_app


class TestTaskQueue(unittest.TestCase):
    """Test cases for task queue service."""

    def setUp(self):
        """Set up test fixtures."""
        # Use a temporary database for testing
        self.db_fd, self.db_path = tempfile.mkstemp()

        # Create app with test database
        self.app = create_app(self.db_path)
        self.app.config["TESTING"] = True
        self.client = self.app.test_client()

    def tearDown(self):
        """Clean up after tests."""
        os.close(self.db_fd)
        os.unlink(self.db_path)

    def test_create_task(self):
        """Test creating a new task."""
        response = self.client.post("/tasks", json={
            "description": "Test task",
            "priority": "high"
        })

        self.assertEqual(response.status_code, 201)
        data = response.get_json()
        self.assertEqual(data["description"], "Test task")
        self.assertEqual(data["priority"], "high")
        self.assertEqual(data["status"], "pending")
        self.assertEqual(data["retry_count"], 0)
        self.assertIn("id", data)

    def test_create_task_default_priority(self):
        """Test creating task with default priority (medium)."""
        response = self.client.post("/tasks", json={
            "description": "Test task"
        })

        self.assertEqual(response.status_code, 201)
        data = response.get_json()
        self.assertEqual(data["priority"], "medium")

    def test_create_task_invalid_priority(self):
        """Test creating task with invalid priority."""
        response = self.client.post("/tasks", json={
            "description": "Test task",
            "priority": "invalid"
        })

        self.assertEqual(response.status_code, 400)
        self.assertIn("error", response.get_json())

    def test_create_task_missing_description(self):
        """Test creating task without description."""
        response = self.client.post("/tasks", json={})

        self.assertEqual(response.status_code, 400)
        self.assertIn("error", response.get_json())

    def test_list_tasks(self):
        """Test listing all tasks."""
        # Create some tasks
        self.client.post("/tasks", json={"description": "Task 1"})
        self.client.post("/tasks", json={"description": "Task 2"})

        response = self.client.get("/tasks")

        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(len(data), 2)

    def test_list_tasks_filter_by_status(self):
        """Test listing tasks filtered by status."""
        # Create tasks
        self.client.post("/tasks", json={"description": "Task 1"})
        self.client.post("/tasks", json={"description": "Task 2"})

        # Claim one task
        tasks = self.client.get("/tasks").get_json()
        task_id = tasks[0]["id"]
        self.client.post(f"/tasks/{task_id}/claim")

        # Filter by pending
        response = self.client.get("/tasks?status=pending")
        data = response.get_json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["status"], "pending")

        # Filter by running
        response = self.client.get("/tasks?status=running")
        data = response.get_json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["status"], "running")

    def test_get_single_task(self):
        """Test getting a single task by ID."""
        # Create a task
        create_response = self.client.post("/tasks", json={
            "description": "Test task"
        })
        task_id = create_response.get_json()["id"]

        response = self.client.get(f"/tasks/{task_id}")

        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data["id"], task_id)
        self.assertEqual(data["description"], "Test task")

    def test_get_nonexistent_task(self):
        """Test getting a task that doesn't exist."""
        response = self.client.get("/tasks/9999")

        self.assertEqual(response.status_code, 404)
        self.assertIn("error", response.get_json())

    def test_claim_specific_task(self):
        """Test worker claiming a specific pending task."""
        # Create a task
        create_response = self.client.post("/tasks", json={
            "description": "Test task"
        })
        task_id = create_response.get_json()["id"]

        # Claim it
        response = self.client.post(f"/tasks/{task_id}/claim")

        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data["status"], "running")

        # Verify it's no longer claimable
        response = self.client.post(f"/tasks/{task_id}/claim")
        self.assertEqual(response.status_code, 409)

    def test_claim_high_priority_first(self):
        """Test that higher priority tasks are claimed first."""
        # Create tasks in order: low, medium, high
        self.client.post("/tasks", json={"description": "Low priority", "priority": "low"})
        self.client.post("/tasks", json={"description": "High priority", "priority": "high"})
        self.client.post("/tasks", json={"description": "Medium priority", "priority": "medium"})

        # Claim one - should be high priority
        response = self.client.post("/tasks/claim")
        data = response.get_json()
        self.assertEqual(data["description"], "High priority")
        self.assertEqual(data["priority"], "high")

    def test_claim_no_pending_tasks(self):
        """Test claiming when no pending tasks available."""
        # Create and immediately complete a task
        create_response = self.client.post("/tasks", json={"description": "Task"})
        task_id = create_response.get_json()["id"]
        self.client.post(f"/tasks/{task_id}/claim")
        self.client.post(f"/tasks/{task_id}/complete")

        # Try to claim
        response = self.client.post("/tasks/claim")

        self.assertEqual(response.status_code, 404)

    def test_complete_task(self):
        """Test completing a running task."""
        # Create and claim a task
        create_response = self.client.post("/tasks", json={"description": "Task"})
        task_id = create_response.get_json()["id"]
        self.client.post(f"/tasks/{task_id}/claim")

        # Complete it
        response = self.client.post(f"/tasks/{task_id}/complete")

        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data["status"], "completed")

    def test_complete_nonexistent_task(self):
        """Test completing a task that doesn't exist."""
        response = self.client.post("/tasks/9999/complete")

        self.assertEqual(response.status_code, 404)

    def test_fail_task_with_retry(self):
        """Test that failing a task increments retry count."""
        # Create and claim a task
        create_response = self.client.post("/tasks", json={"description": "Task"})
        task_id = create_response.get_json()["id"]
        self.client.post(f"/tasks/{task_id}/claim")

        # Fail it
        response = self.client.post(f"/tasks/{task_id}/fail")

        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data["status"], "pending")  # Should be pending for retry
        self.assertEqual(data["retry_count"], 1)

    def test_fail_task_max_retries(self):
        """Test that task becomes failed after max retries."""
        # Create and claim a task
        create_response = self.client.post("/tasks", json={"description": "Task"})
        task_id = create_response.get_json()["id"]

        # Fail 3 times (max retries)
        for i in range(3):
            self.client.post(f"/tasks/{task_id}/claim")
            response = self.client.post(f"/tasks/{task_id}/fail")
            data = response.get_json()

            if i < 2:
                self.assertEqual(data["status"], "pending")
                self.assertEqual(data["retry_count"], i + 1)
            else:
                self.assertEqual(data["status"], "failed")
                self.assertEqual(data["retry_count"], 3)

    def test_get_queue_stats(self):
        """Test getting queue statistics."""
        # Create some tasks
        self.client.post("/tasks", json={"description": "Task 1", "priority": "high"})
        self.client.post("/tasks", json={"description": "Task 2", "priority": "medium"})
        self.client.post("/tasks", json={"description": "Task 3", "priority": "low"})

        # Claim and complete one
        tasks = self.client.get("/tasks").get_json()
        task_id = tasks[0]["id"]
        self.client.post(f"/tasks/{task_id}/claim")
        self.client.post(f"/tasks/{task_id}/complete")

        response = self.client.get("/queues")

        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data["total"], 3)
        self.assertEqual(data["by_status"]["completed"], 1)
        self.assertEqual(data["by_status"]["pending"], 2)
        self.assertEqual(data["pending_by_priority"].get("high", 0), 0)
        self.assertEqual(data["pending_by_priority"].get("medium", 0), 1)
        self.assertEqual(data["pending_by_priority"].get("low", 0), 1)


if __name__ == "__main__":
    unittest.main()
