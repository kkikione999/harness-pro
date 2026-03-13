"""Tests for task manager models."""

from datetime import datetime

from task_manager.models import Task


def test_task_can_be_instantiated():
    """Test that a Task can be created with required fields."""
    task = Task(id=1, title="Test Task")
    assert task.id == 1
    assert task.title == "Test Task"


def test_task_default_values():
    """Test that Task has correct default values."""
    task = Task(id=1, title="Test Task")
    assert task.completed is False
    assert isinstance(task.created_at, datetime)


def test_task_custom_values():
    """Test that Task can be created with custom values."""
    custom_time = datetime(2024, 1, 1, 12, 0, 0)
    task = Task(id=2, title="Custom Task", completed=True,
                created_at=custom_time)
    assert task.id == 2
    assert task.title == "Custom Task"
    assert task.completed is True
    assert task.created_at == custom_time
