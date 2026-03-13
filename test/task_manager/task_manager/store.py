"""Task storage module for the task manager."""

from __future__ import annotations

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
