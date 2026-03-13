"""
Comprehensive tests for the Task model.
"""

import pytest
from task_manager.task import Task


class TestTaskCreation:
    """Tests for Task instantiation and initialization."""

    def test_task_creation_with_title_only(self):
        """Test creating a Task with only a title."""
        task = Task("Buy groceries")
        assert task.title == "Buy groceries"
        assert task.description is None
        assert task.completed is False

    def test_task_creation_with_title_and_description(self):
        """Test creating a Task with title and description."""
        task = Task("Buy groceries", "Milk, eggs, bread")
        assert task.title == "Buy groceries"
        assert task.description == "Milk, eggs, bread"
        assert task.completed is False

    def test_task_default_completed_status(self):
        """Test that completed defaults to False."""
        task = Task("Default task")
        assert task.completed is False

    def test_task_empty_string_title(self):
        """Test that Task accepts empty string as title."""
        task = Task("")
        assert task.title == ""
        assert task.completed is False


class TestTaskRepr:
    """Tests for Task __repr__ method."""

    def test_repr_output(self):
        """Test that __repr__ returns expected format."""
        task = Task("Test task")
        assert repr(task) == "Task(title='Test task', completed=False)"

    def test_repr_with_description(self):
        """Test __repr__ output when task has description."""
        task = Task("Test task", "A description")
        assert repr(task) == "Task(title='Test task', completed=False)"

    def test_repr_completed_task(self):
        """Test __repr__ output for completed task."""
        task = Task("Test task")
        task.completed = True
        assert repr(task) == "Task(title='Test task', completed=True)"


class TestTaskEquality:
    """Tests for Task equality comparison."""

    def test_task_equality_same_title(self):
        """Test that tasks with same title are equal."""
        task1 = Task("Same title")
        task2 = Task("Same title")
        assert task1 == task2

    def test_task_equality_different_titles(self):
        """Test that tasks with different titles are not equal."""
        task1 = Task("Task 1")
        task2 = Task("Task 2")
        assert task1 != task2

    def test_task_equality_with_different_descriptions(self):
        """Test that tasks with same title but different descriptions are equal."""
        task1 = Task("Same title", "Description 1")
        task2 = Task("Same title", "Description 2")
        assert task1 == task2

    def test_task_equality_with_different_completion_status(self):
        """Test that tasks with same title but different completion are equal."""
        task1 = Task("Same title")
        task2 = Task("Same title")
        task2.completed = True
        assert task1 == task2

    def test_task_inequality_with_non_task_object(self):
        """Test that Task is not equal to non-Task objects."""
        task = Task("Test task")
        assert task != "Test task"
        assert task != 123
        assert task != None
        assert task != {"title": "Test task"}

    def test_task_equality_reflexivity(self):
        """Test that Task equality is reflexive (x == x)."""
        task = Task("Test task")
        assert task == task

    def test_task_equality_symmetry(self):
        """Test that Task equality is symmetric (x == y implies y == x)."""
        task1 = Task("Same title")
        task2 = Task("Same title")
        assert (task1 == task2) == (task2 == task1)

    def test_task_equality_transitivity(self):
        """Test that Task equality is transitive (x == y and y == z implies x == z)."""
        task1 = Task("Same title")
        task2 = Task("Same title")
        task3 = Task("Same title")
        assert task1 == task2
        assert task2 == task3
        assert task1 == task3


class TestTaskTypeValidation:
    """Tests for Task type validation."""

    def test_title_must_be_string(self):
        """Test that title must be a string type."""
        with pytest.raises(TypeError, match="title must be a string"):
            Task(123)

    def test_title_must_be_string_none(self):
        """Test that None as title raises TypeError."""
        with pytest.raises(TypeError, match="title must be a string"):
            Task(None)

    def test_title_must_be_string_list(self):
        """Test that list as title raises TypeError."""
        with pytest.raises(TypeError, match="title must be a string"):
            Task(["list", "of", "items"])

    def test_title_must_be_string_dict(self):
        """Test that dict as title raises TypeError."""
        with pytest.raises(TypeError, match="title must be a string"):
            Task({"key": "value"})

    def test_title_must_be_string_bool(self):
        """Test that bool as title raises TypeError."""
        with pytest.raises(TypeError, match="title must be a string"):
            Task(True)

    def test_description_accepts_none(self):
        """Test that description accepts None as default value."""
        task = Task("Test", None)
        assert task.description is None

    def test_description_accepts_string(self):
        """Test that description accepts string."""
        task = Task("Test", "A valid description")
        assert task.description == "A valid description"


class TestTaskAttributes:
    """Tests for Task attribute access and modification."""

    def test_completed_can_be_set_to_true(self):
        """Test that completed attribute can be set to True."""
        task = Task("Test task")
        task.completed = True
        assert task.completed is True

    def test_completed_can_be_toggled(self):
        """Test toggling completed status."""
        task = Task("Test task")
        assert task.completed is False
        task.completed = True
        assert task.completed is True
        task.completed = False
        assert task.completed is False

    def test_title_is_readonly_after_creation(self):
        """Test that title attribute can be accessed."""
        task = Task("Test task")
        assert task.title == "Test task"
        # Note: Python doesn't enforce readonly, but we test access works

    def test_description_can_be_modified(self):
        """Test that description can be modified after creation."""
        task = Task("Test task", "Original description")
        assert task.description == "Original description"
        task.description = "New description"
        assert task.description == "New description"
