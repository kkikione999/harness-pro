"""Task models for the task manager."""

from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class Task:
    """Represents a task with title, completion status,
    and creation timestamp."""

    id: int
    title: str
    completed: bool = False
    created_at: datetime = field(default_factory=datetime.now)

    def to_dict(self) -> dict:
        """Convert task to dictionary for JSON serialization.

        Returns:
            Dictionary representation of the task.
        """
        return {
            "id": self.id,
            "title": self.title,
            "completed": self.completed,
            "created_at": self.created_at.isoformat(),
        }

    @classmethod
    def from_dict(cls, data: dict) -> "Task":
        """Create a Task from a dictionary.

        Args:
            data: Dictionary containing task data.

        Returns:
            A new Task instance.
        """
        task_data = data.copy()
        task_data["created_at"] = datetime.fromisoformat(task_data["created_at"])
        return cls(**task_data)
