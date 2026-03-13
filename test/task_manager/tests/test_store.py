"""Tests for task manager store."""

import sys
import os

# Add project root to path for imports
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)

import pytest

from task import Task
from store import TaskStore


class TestTaskStoreInitialization:
    """Tests for TaskStore initialization."""

    def test_store_initializes_empty(self):
        """Test that a new store has no tasks."""
        store = TaskStore()
        assert store.list_tasks() == []


class TestTaskStoreAddTask:
    """Tests for add_task method."""

    def test_add_task_stores_task(self):
        """Test that add_task stores the task in the store."""
        store = TaskStore()
        task = Task("Buy groceries")

        result = store.add_task(task)

        assert result == task
        tasks = store.list_tasks()
        assert len(tasks) == 1
        assert tasks[0] == task

    def test_add_task_returns_same_instance(self):
        """Test that add_task returns the same task instance."""
        store = TaskStore()
        task = Task("Test task")

        result = store.add_task(task)

        assert result is task

    def test_add_multiple_tasks(self):
        """Test adding multiple tasks to the store."""
        store = TaskStore()
        task1 = Task("Task 1")
        task2 = Task("Task 2")
        task3 = Task("Task 3")

        store.add_task(task1)
        store.add_task(task2)
        store.add_task(task3)

        tasks = store.list_tasks()
        assert len(tasks) == 3
        assert task1 in tasks
        assert task2 in tasks
        assert task3 in tasks

    def test_add_task_validates_type(self):
        """Test that add_task validates the parameter is a Task."""
        store = TaskStore()

        with pytest.raises(TypeError, match="task must be a Task instance"):
            store.add_task("not a task")

        with pytest.raises(TypeError, match="task must be a Task instance"):
            store.add_task(123)

        with pytest.raises(TypeError, match="task must be a Task instance"):
            store.add_task({"title": "fake task"})

        with pytest.raises(TypeError, match="task must be a Task instance"):
            store.add_task(None)

    def test_add_task_with_completed_task(self):
        """Test that add_task works with completed tasks."""
        store = TaskStore()
        task = Task("Completed task")
        task.completed = True

        store.add_task(task)

        tasks = store.list_tasks()
        assert len(tasks) == 1
        assert tasks[0].completed is True

    def test_add_task_with_task_with_description(self):
        """Test that add_task works with tasks that have descriptions."""
        store = TaskStore()
        task = Task("Task with description", "This is a description")

        store.add_task(task)

        tasks = store.list_tasks()
        assert len(tasks) == 1
        assert tasks[0].description == "This is a description"


class TestTaskStoreListTasks:
    """Tests for list_tasks method."""

    def test_list_empty_store(self):
        """Test that list_tasks returns empty list for empty store."""
        store = TaskStore()
        assert store.list_tasks() == []

    def test_list_tasks_returns_copy(self):
        """Test that list_tasks returns a copy, not reference."""
        store = TaskStore()
        task1 = Task("Task 1")
        task2 = Task("Task 2")
        store.add_task(task1)
        store.add_task(task2)

        tasks1 = store.list_tasks()
        tasks2 = store.list_tasks()

        assert tasks1 is not tasks2
        assert tasks1 == tasks2

    def test_list_tasks_maintains_insertion_order(self):
        """Test that list_tasks returns tasks in insertion order."""
        store = TaskStore()
        task1 = Task("First")
        task2 = Task("Second")
        task3 = Task("Third")

        store.add_task(task1)
        store.add_task(task2)
        store.add_task(task3)

        tasks = store.list_tasks()
        assert tasks[0] == task1
        assert tasks[1] == task2
        assert tasks[2] == task3

    def test_list_tasks_includes_all_statuses(self):
        """Test that list_tasks includes both completed and incomplete tasks."""
        store = TaskStore()
        task1 = Task("Incomplete")
        task2 = Task("Completed")
        task2.completed = True

        store.add_task(task1)
        store.add_task(task2)

        tasks = store.list_tasks()
        assert len(tasks) == 2
        assert any(t.completed is False for t in tasks)
        assert any(t.completed is True for t in tasks)

    def test_list_tasks_modification_does_not_affect_store(self):
        """Test that modifying returned list does not affect store."""
        store = TaskStore()
        task1 = Task("Task 1")
        task2 = Task("Task 2")
        store.add_task(task1)
        store.add_task(task2)

        tasks = store.list_tasks()
        tasks.append(Task("Extra task"))

        # Store should still have only 2 tasks
        store_tasks = store.list_tasks()
        assert len(store_tasks) == 2
        assert "Extra task" not in [t.title for t in store_tasks]


class TestTaskStoreGetTask:
    """Tests for get_task method."""

    def test_get_task_by_title_found(self):
        """Test that get_task returns task when title matches."""
        store = TaskStore()
        task1 = Task("Task 1")
        task2 = Task("Task 2")
        store.add_task(task1)
        store.add_task(task2)

        result = store.get_task("Task 1")

        assert result == task1
        assert result.title == "Task 1"

    def test_get_task_by_title_not_found(self):
        """Test that get_task returns None when title not found."""
        store = TaskStore()
        store.add_task(Task("Existing task"))

        result = store.get_task("Non-existent task")

        assert result is None

    def test_get_task_from_empty_store(self):
        """Test that get_task returns None for empty store."""
        store = TaskStore()

        result = store.get_task("Any title")

        assert result is None

    def test_get_task_case_sensitive(self):
        """Test that get_task is case-sensitive."""
        store = TaskStore()
        task = Task("Buy Groceries")
        store.add_task(task)

        result_upper = store.get_task("BUY GROCERIES")
        result_lower = store.get_task("buy groceries")
        result_mixed = store.get_task("Buy groceries")

        assert result_upper is None
        assert result_lower is None
        assert result_mixed is None
        assert store.get_task("Buy Groceries") == task

    def test_get_task_returns_first_match(self):
        """Test that get_task returns the first matching task by title."""
        store = TaskStore()
        task1 = Task("Same title")
        task2 = Task("Same title")

        store.add_task(task1)
        store.add_task(task2)

        result = store.get_task("Same title")

        # Should return the first one added
        assert result == task1
        assert result is not task2

    def test_get_task_with_empty_title(self):
        """Test that get_task works with empty title."""
        store = TaskStore()
        task = Task("")
        store.add_task(task)

        result = store.get_task("")

        assert result == task

    def test_get_task_with_whitespace_title(self):
        """Test that get_task works with whitespace in title."""
        store = TaskStore()
        task = Task("  spaces  ")
        store.add_task(task)

        result = store.get_task("  spaces  ")

        assert result == task

    def test_get_task_with_description_still_works(self):
        """Test that get_task works regardless of description."""
        store = TaskStore()
        task1 = Task("Same title", "Description 1")
        task2 = Task("Same title", "Description 2")

        store.add_task(task1)
        store.add_task(task2)

        result = store.get_task("Same title")

        assert result.title == "Same title"


class TestTaskStoreIndependence:
    """Tests for TaskStore instance independence."""

    def test_stores_are_independent(self):
        """Test that different TaskStore instances are independent."""
        store1 = TaskStore()
        store2 = TaskStore()

        task1 = Task("Store 1 task")
        task2 = Task("Store 2 task")

        store1.add_task(task1)
        store2.add_task(task2)

        assert len(store1.list_tasks()) == 1
        assert len(store2.list_tasks()) == 1
        assert store1.list_tasks()[0] == task1
        assert store2.list_tasks()[0] == task2

    def test_get_task_does_not_affect_other_stores(self):
        """Test that get_task in one store doesn't affect another."""
        store1 = TaskStore()
        store2 = TaskStore()

        store1.add_task(Task("Shared title"))
        store2.add_task(Task("Shared title"))

        result1 = store1.get_task("Shared title")
        result2 = store2.get_task("Shared title")

        # Results should be different Task instances
        assert result1 is not result2
        # But they should be equal based on title
        assert result1 == result2
