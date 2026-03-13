"""Task storage module for the task manager."""

from typing import List, Optional

from task import Task


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

    def mark_task_complete(self, title: str) -> Optional[Task]:
        """Find a task by title and mark it as complete.

        Args:
            title: The title of the task to mark as complete.

        Returns:
            The Task if found and marked complete, None otherwise.
        """
        task = self.get_task(title)
        if task:
            task.mark_complete()
        return task

    def mark_task_incomplete(self, title: str) -> Optional[Task]:
        """Find a task by title and mark it as incomplete.

        Args:
            title: The title of the task to mark as incomplete.

        Returns:
            The Task if found and marked incomplete, None otherwise.
        """
        task = self.get_task(title)
        if task:
            task.mark_incomplete()
        return task

    def toggle_task_completion(self, title: str) -> Optional[Task]:
        """Find a task by title and toggle its completion status.

        Args:
            title: The title of the task to toggle.

        Returns:
            The Task if found and toggled, None otherwise.
        """
        task = self.get_task(title)
        if task:
            task.toggle_completion()
        return task
