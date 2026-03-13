"""Task storage module for the task manager."""

from __future__ import annotations

import json
from pathlib import Path

from task_manager.models import Task


class TaskStore:
    """In-memory store for tasks with add, list, and get operations."""

    def __init__(self) -> None:
        """Initialize empty task store with auto-incrementing ID counter."""
        self._tasks: dict[int, Task] = {}
        self._next_id: int = 1

    def add_task(self, title: str) -> Task:
        """Create and add a new task with the given title.

        Args:
            title: The title of the task to create.

        Returns:
            The newly created Task with auto-assigned ID.
        """
        task = Task(id=self._next_id, title=title)
        self._tasks[self._next_id] = task
        self._next_id += 1
        return task

    def list_tasks(self) -> list[Task]:
        """Return all tasks in the store.

        Returns:
            A list of all stored tasks, ordered by ID.
        """
        return list(self._tasks.values())

    def get_task(self, task_id: int) -> Task | None:
        """Get a task by its ID.

        Args:
            task_id: The ID of the task to retrieve.

        Returns:
            The task if found, None otherwise.
        """
        return self._tasks.get(task_id)

    def save_to_file(self, filepath: str) -> None:
        """Save all tasks to a JSON file.

        Args:
            filepath: Path to the JSON file.
        """
        data = {
            "tasks": [task.to_dict() for task in self._tasks.values()],
            "next_id": self._next_id,
        }
        Path(filepath).write_text(json.dumps(data, indent=2))

    def load_from_file(self, filepath: str) -> None:
        """Load tasks from a JSON file.

        Replaces current tasks and updates next_id appropriately.
        If the file does not exist, the store remains unchanged.

        Args:
            filepath: Path to the JSON file.
        """
        path = Path(filepath)
        if not path.exists():
            return

        data = json.loads(path.read_text())
        self._tasks = {
            task_data["id"]: Task.from_dict(task_data)
            for task_data in data["tasks"]
        }
        self._next_id = data["next_id"]
