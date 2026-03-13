"""Tests for task manager store."""

import json
import tempfile
from pathlib import Path

import pytest

from task_manager.models import Task
from task_manager.store import TaskStore


class TestTaskStore:
    """Tests for the TaskStore class."""

    def test_add_task_returns_task_with_correct_title(self):
        """Test that adding a task returns a Task with the given title."""
        store = TaskStore()
        task = store.add_task("Buy groceries")

        assert isinstance(task, Task)
        assert task.title == "Buy groceries"
        assert task.id == 1

    def test_add_task_assigns_incrementing_ids(self):
        """Test that add_task assigns incrementing IDs starting from 1."""
        store = TaskStore()

        task1 = store.add_task("First task")
        task2 = store.add_task("Second task")
        task3 = store.add_task("Third task")

        assert task1.id == 1
        assert task2.id == 2
        assert task3.id == 3

    def test_list_tasks_returns_all_added_tasks(self):
        """Test that list_tasks returns all tasks that were added."""
        store = TaskStore()

        # Empty store returns empty list
        assert store.list_tasks() == []

        task1 = store.add_task("Task 1")
        task2 = store.add_task("Task 2")

        tasks = store.list_tasks()

        assert len(tasks) == 2
        assert task1 in tasks
        assert task2 in tasks

    def test_get_task_returns_correct_task(self):
        """Test that get_task returns the correct task by ID."""
        store = TaskStore()
        task1 = store.add_task("Task 1")
        task2 = store.add_task("Task 2")

        retrieved = store.get_task(task1.id)

        assert retrieved == task1
        assert retrieved.title == "Task 1"

        retrieved2 = store.get_task(task2.id)
        assert retrieved2 == task2

    def test_get_task_returns_none_for_nonexistent_id(self):
        """Test that get_task returns None for a non-existent task ID."""
        store = TaskStore()
        store.add_task("Task 1")

        result = store.get_task(999)

        assert result is None

    def test_get_task_returns_none_for_empty_store(self):
        """Test that get_task returns None when store is empty."""
        store = TaskStore()

        result = store.get_task(1)

        assert result is None

    def test_tasks_are_independent_between_stores(self):
        """Test that different TaskStore instances are independent."""
        store1 = TaskStore()
        store2 = TaskStore()

        task1 = store1.add_task("Store 1 task")
        task2 = store2.add_task("Store 2 task")

        assert task1.id == 1
        assert task2.id == 1  # Independent counter

        assert store1.list_tasks() == [task1]
        assert store2.list_tasks() == [task2]


class TestTaskStorePersistence:
    """Tests for TaskStore persistence methods."""

    def test_save_to_file_creates_valid_json_file(self):
        """Test that save_to_file creates a valid JSON file."""
        store = TaskStore()
        store.add_task("Buy groceries")
        store.add_task("Walk the dog")

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            filepath = f.name

        try:
            store.save_to_file(filepath)

            assert Path(filepath).exists()
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
        store.add_task("Task 1")
        store.add_task("Task 2")

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            filepath = f.name

        try:
            store.save_to_file(filepath)

            new_store = TaskStore()
            new_store.load_from_file(filepath)

            tasks = new_store.list_tasks()
            assert len(tasks) == 2
            titles = [t.title for t in tasks]
            assert "Task 1" in titles
            assert "Task 2" in titles
        finally:
            Path(filepath).unlink(missing_ok=True)

    def test_round_trip_save_load_preserves_data(self):
        """Test that save then load preserves all task data."""
        store = TaskStore()
        task1 = store.add_task("First task")
        task2 = store.add_task("Second task")

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            filepath = f.name

        try:
            store.save_to_file(filepath)

            new_store = TaskStore()
            new_store.load_from_file(filepath)

            restored_task1 = new_store.get_task(1)
            assert restored_task1 is not None
            assert restored_task1.title == "First task"
            assert restored_task1.completed is False

            restored_task2 = new_store.get_task(2)
            assert restored_task2 is not None
            assert restored_task2.title == "Second task"
        finally:
            Path(filepath).unlink(missing_ok=True)

    def test_load_from_file_handles_nonexistent_file_gracefully(self):
        """Test that load_from_file handles non-existent file without error."""
        store = TaskStore()
        store.add_task("Existing task")

        nonexistent_path = "/nonexistent/path/file.json"
        store.load_from_file(nonexistent_path)

        # Store should remain unchanged
        tasks = store.list_tasks()
        assert len(tasks) == 1
        assert tasks[0].title == "Existing task"

    def test_load_from_file_preserves_next_id(self):
        """Test that load_from_file restores next_id for correct ID sequencing."""
        store = TaskStore()
        store.add_task("Task 1")
        store.add_task("Task 2")
        # next_id should be 3

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            filepath = f.name

        try:
            store.save_to_file(filepath)

            new_store = TaskStore()
            new_store.load_from_file(filepath)

            # New task should get ID 3
            new_task = new_store.add_task("Task 3")
            assert new_task.id == 3
        finally:
            Path(filepath).unlink(missing_ok=True)
