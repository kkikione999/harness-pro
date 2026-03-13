"""
Core Task model for the task manager application.
"""

from typing import Optional


class Task:
    """Represents a task with a title, optional description, and completion status."""

    def __init__(self, title: str, description: Optional[str] = None):
        """Initialize a new Task.

        Args:
            title: The task title (required)
            description: Optional description of the task

        Raises:
            TypeError: If title is not a string
        """
        if not isinstance(title, str):
            raise TypeError("title must be a string")

        self.title = title
        self.description = description
        self.completed = False

    def __repr__(self) -> str:
        """Return a string representation of the Task for debugging."""
        return f"Task(title='{self.title}', completed={self.completed})"

    def __eq__(self, other: object) -> bool:
        """Compare tasks based on title equality.

        Args:
            other: Another object to compare with

        Returns:
            True if other is a Task with the same title, False otherwise
        """
        if not isinstance(other, Task):
            return False
        return self.title == other.title

    def mark_complete(self) -> None:
        """Mark the task as completed."""
        self.completed = True

    def mark_incomplete(self) -> None:
        """Mark the task as incomplete."""
        self.completed = False

    def toggle_completion(self) -> None:
        """Toggle the completion status between complete and incomplete."""
        self.completed = not self.completed
