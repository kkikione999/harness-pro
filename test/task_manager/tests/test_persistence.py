"""Tests for task persistence functionality."""

import json
import tempfile
from datetime import datetime
from pathlib import Path

import pytest

from task_manager.models import Task
from task_manager.store import TaskStore


class TestTaskSerialization:
    """Tests for Task to_dict and from_dict methods."""

    def test_task_to_dict_returns_correct_structure(self):
        """Test that to_dict returns a dictionary with all task fields."""
        custom_time = datetime(2024, 1, 15, 10, 30, 0)
        task = Task(id=1, title="Test Task", completed=True, created_at=custom_time)

        result = task.to_dict()

        assert result == {
            "id": 1,
            "title": "Test Task",
            "completed": True,
            "created_at": "2024-01-15T10:30:00",
        }

    def test_task_to_dict_uses_iso_format_for_datetime(self):
        """Test that to_dict serializes datetime in ISO format."""
        custom_time = datetime(2024, 6, 1, 14, 45, 30)
        task = Task(id=1, title="Test", created_at=custom_time)

        result = task.to_dict()

        assert result["created_at"] == "2024-06-01T14:45:30"

    def test_task_from_dict_creates_task_correctly(self):
        """Test that from_dict creates a Task from dictionary data."""
        data = {
            "id": 2,
            "title": "From Dict Task",
            "completed": False,
            "created_at": "2024-03-10T08:00:00",
        }

        task = Task.from_dict(data)

        assert task.id == 2
        assert task.title == "From Dict Task"
        assert task.completed is False
        assert task.created_at == datetime(2024, 3, 10, 8, 0, 0)

    def test_task_round_trip_serialization(self):
        """Test that to_dict and from_dict are inverse operations."""
        original_time = datetime(2024, 12, 25, 0, 0, 0)
        original = Task(id=5, title="Round Trip", completed=True, created_at=original_time)

        serialized = original.to_dict()
        restored = Task.from_dict(serialized)

        assert restored.id == original.id
        assert restored.title == original.title
        assert restored.completed == original.completed
        assert restored.created_at == original.created_at


class TestFileOperations:
    """Tests for file save and load operations."""

    def test_save_to_file_creates_valid_json_file(self):
        """Test that save_to_file creates a valid JSON file."""
        store = TaskStore()
        store.add_task("Task 1")
        store.add_task("Task 2")

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            filepath = f.name

        try:
            store.save_to_file(filepath)

            content = Path(filepath).read_text()
            data = json.loads(content)

            assert "tasks" in data
            assert "next_id" in data
            assert len(data["tasks"]) == 2
            assert data["next_id"] == 3
        finally:
            Path(filepath).unlink(missing_ok=True)

    def test_load_from_file_restores_tasks_correctly(self):
        """Test that load_from_file restores tasks from JSON file."""
        store = TaskStore()
        task1 = store.add_task("Original Task")

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            filepath = f.name

        try:
            store.save_to_file(filepath)

            new_store = TaskStore()
            new_store.load_from_file(filepath)

            tasks = new_store.list_tasks()
            assert len(tasks) == 1
            assert tasks[0].title == "Original Task"
            assert tasks[0].id == 1
        finally:
            Path(filepath).unlink(missing_ok=True)

    def test_load_from_file_restores_next_id(self):
        """Test that load_from_file restores next_id correctly."""
        store = TaskStore()
        store.add_task("Task 1")
        store.add_task("Task 2")
        # next_id should now be 3

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            filepath = f.name

        try:
            store.save_to_file(filepath)

            new_store = TaskStore()
            new_store.load_from_file(filepath)

            # Adding a new task should get id 3
            new_task = new_store.add_task("Task 3")
            assert new_task.id == 3
        finally:
            Path(filepath).unlink(missing_ok=True)

    def test_load_from_file_handles_nonexistent_file_gracefully(self):
        """Test that load_from_file handles non-existent file without error."""
        store = TaskStore()
        store.add_task("Existing Task")

        nonexistent_path = "/nonexistent/path/tasks.json"
        store.load_from_file(nonexistent_path)

        # Store should remain unchanged
        tasks = store.list_tasks()
        assert len(tasks) == 1
        assert tasks[0].title == "Existing Task"

    def test_round_trip_preserves_all_task_data(self):
        """Test that save and load preserves all task data including timestamps."""
        store = TaskStore()
        task1 = store.add_task("Task 1")
        task2 = store.add_task("Task 2")

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            filepath = f.name

        try:
            store.save_to_file(filepath)

            new_store = TaskStore()
            new_store.load_from_file(filepath)

            restored_tasks = new_store.list_tasks()
            assert len(restored_tasks) == 2

            restored_task1 = new_store.get_task(1)
            assert restored_task1.title == "Task 1"
            assert restored_task1.completed is False
            assert isinstance(restored_task1.created_at, datetime)

            restored_task2 = new_store.get_task(2)
            assert restored_task2.title == "Task 2"
        finally:
            Path(filepath).unlink(missing_ok=True)

    def test_load_replaces_current_tasks(self):
        """Test that load_from_file replaces current tasks in store."""
        store1 = TaskStore()
        store1.add_task("Task A")
        store1.add_task("Task B")

        store2 = TaskStore()
        store2.add_task("Old Task")

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            filepath = f.name

        try:
            store1.save_to_file(filepath)
            store2.load_from_file(filepath)

            tasks = store2.list_tasks()
            assert len(tasks) == 2
            titles = [t.title for t in tasks]
            assert "Task A" in titles
            assert "Task B" in titles
            assert "Old Task" not in titles
        finally:
            Path(filepath).unlink(missing_ok=True)
