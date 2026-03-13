"""Task storage module for the task manager."""

from typing import List, Optional

from task_manager.task import Task


class TaskStore:
    """In-memory store for tasks with add, list, and get operations."""

    def __init__(self) -> None:
        """Initialize empty task store."""
        self._tasks: List[Task] = []

    def add_task(self, task: Task) -> Task:
        """Add a task to the store.

        Args:
            task: The Task instance to add to the store.

        Returns:
            The same task instance that was added.

        Raises:
            TypeError: If task is not a Task instance.
        """
        if not isinstance(task, Task):
            raise TypeError("task must be a Task instance")

        self._tasks.append(task)
        return task

    def list_tasks(self) -> List[Task]:
        """Return all tasks in the store.

        Returns:
            A new list containing all tasks in insertion order.
        """
        return list(self._tasks)

    def get_task(self, title: str) -> Optional[Task]:
        """Retrieve a task by its title.

        Args:
            title: The title of the task to retrieve.

        Returns:
            The Task object if found, None otherwise.
        """
        for task in self._tasks:
            if task.title == title:
                return task
        return None
