"""Tests for task manager store."""

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
