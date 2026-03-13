"""Tests for task completion marking functionality."""

import pytest

from task import Task
from store import TaskStore


class TestTaskMarkComplete:
    """Tests for Task.mark_complete method."""

    def test_mark_complete_sets_completed_to_true(self):
        """Test that mark_complete sets completed to True."""
        task = Task("Test task")
        assert task.completed is False

        task.mark_complete()
        assert task.completed is True

    def test_mark_complete_already_completed_task(self):
        """Test that marking an already completed task as complete works."""
        task = Task("Test task")
        task.completed = True

        task.mark_complete()
        assert task.completed is True


class TestTaskMarkIncomplete:
    """Tests for Task.mark_incomplete method."""

    def test_mark_incomplete_sets_completed_to_false(self):
        """Test that mark_incomplete sets completed to False."""
        task = Task("Test task")
        task.completed = True

        task.mark_incomplete()
        assert task.completed is False

    def test_mark_incomplete_already_incomplete_task(self):
        """Test that marking an already incomplete task as incomplete works."""
        task = Task("Test task")
        assert task.completed is False

        task.mark_incomplete()
        assert task.completed is False


class TestTaskToggleCompletion:
    """Tests for Task.toggle_completion method."""

    def test_toggle_completion_from_incomplete_to_complete(self):
        """Test that toggle_completion changes incomplete to complete."""
        task = Task("Test task")
        assert task.completed is False

        task.toggle_completion()
        assert task.completed is True

    def test_toggle_completion_from_complete_to_incomplete(self):
        """Test that toggle_completion changes complete to incomplete."""
        task = Task("Test task")
        task.completed = True

        task.toggle_completion()
        assert task.completed is False

    def test_multiple_toggle_operations(self):
        """Test that multiple toggle operations work correctly."""
        task = Task("Test task")
        assert task.completed is False

        task.toggle_completion()
        assert task.completed is True

        task.toggle_completion()
        assert task.completed is False

        task.toggle_completion()
        assert task.completed is True


class TestTaskStoreMarkTaskComplete:
    """Tests for TaskStore.mark_task_complete method."""

    def test_mark_task_complete_finds_and_marks_task(self):
        """Test that mark_task_complete finds and marks a task."""
        store = TaskStore()
        task = Task("Test task")
        store.add_task(task)

        result = store.mark_task_complete("Test task")
        assert result is task
        assert task.completed is True

    def test_mark_task_complete_returns_none_for_nonexistent_task(self):
        """Test that mark_task_complete returns None for non-existent task."""
        store = TaskStore()

        result = store.mark_task_complete("Non-existent task")
        assert result is None

    def test_mark_task_complete_already_completed_task(self):
        """Test that marking an already completed task as complete works."""
        store = TaskStore()
        task = Task("Test task")
        store.add_task(task)
        task.completed = True

        result = store.mark_task_complete("Test task")
        assert result is task
        assert task.completed is True


class TestTaskStoreMarkTaskIncomplete:
    """Tests for TaskStore.mark_task_incomplete method."""

    def test_mark_task_incomplete_finds_and_unmarks_task(self):
        """Test that mark_task_incomplete finds and unmarks a task."""
        store = TaskStore()
        task = Task("Test task")
        store.add_task(task)
        task.completed = True

        result = store.mark_task_incomplete("Test task")
        assert result is task
        assert task.completed is False

    def test_mark_task_incomplete_returns_none_for_nonexistent_task(self):
        """Test that mark_task_incomplete returns None for non-existent task."""
        store = TaskStore()

        result = store.mark_task_incomplete("Non-existent task")
        assert result is None

    def test_mark_task_incomplete_already_incomplete_task(self):
        """Test that marking an already incomplete task as incomplete works."""
        store = TaskStore()
        task = Task("Test task")
        store.add_task(task)

        result = store.mark_task_incomplete("Test task")
        assert result is task
        assert task.completed is False


class TestTaskStoreToggleTaskCompletion:
    """Tests for TaskStore.toggle_task_completion method."""

    def test_toggle_task_completion_toggles_existing_task(self):
        """Test that toggle_task_completion toggles an existing task."""
        store = TaskStore()
        task = Task("Test task")
        store.add_task(task)

        result = store.toggle_task_completion("Test task")
        assert result is task
        assert task.completed is True

        result = store.toggle_task_completion("Test task")
        assert result is task
        assert task.completed is False

    def test_toggle_task_completion_returns_none_for_nonexistent_task(self):
        """Test that toggle_task_completion returns None for non-existent task."""
        store = TaskStore()

        result = store.toggle_task_completion("Non-existent task")
        assert result is None


class TestTaskStoreCompletionPersists:
    """Tests that completion status persists in list_tasks."""

    def test_completion_status_persists_in_list_tasks(self):
        """Test that completion status persists when listing tasks."""
        store = TaskStore()
        task1 = Task("Task 1")
        task2 = Task("Task 2")
        task3 = Task("Task 3")
        store.add_task(task1)
        store.add_task(task2)
        store.add_task(task3)

        store.mark_task_complete("Task 2")
        store.mark_task_complete("Task 3")

        tasks = store.list_tasks()
        assert tasks[0].completed is False
        assert tasks[1].completed is True
        assert tasks[2].completed is True

    def test_multiple_completion_operations(self):
        """Test that multiple completion operations work correctly."""
        store = TaskStore()
        task1 = Task("Task 1")
        task2 = Task("Task 2")
        task3 = Task("Task 3")
        store.add_task(task1)
        store.add_task(task2)
        store.add_task(task3)

        store.mark_task_complete("Task 1")
        store.mark_task_complete("Task 2")
        store.toggle_task_completion("Task 1")  # Task 1 becomes incomplete
        store.mark_task_complete("Task 3")
        store.mark_task_incomplete("Task 2")

        assert task1.completed is False
        assert task2.completed is False
        assert task3.completed is True

        tasks = store.list_tasks()
        assert tasks[0].completed is False
        assert tasks[1].completed is False
        assert tasks[2].completed is True


class TestTaskStoreCompletionIndependence:
    """Tests that completion operations don't affect other stores."""

    def test_completion_operations_are_independent_between_stores(self):
        """Test that completion operations in one store don't affect another."""
        store1 = TaskStore()
        store2 = TaskStore()

        task1 = Task("Same title")
        task2 = Task("Same title")

        store1.add_task(task1)
        store2.add_task(task2)

        store1.mark_task_complete("Same title")

        assert task1.completed is True
        assert task2.completed is False
