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
