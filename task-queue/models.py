"""Database models for task queue service."""

import sqlite3
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Optional


class TaskStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


class Priority(Enum):
    LOW = 1
    MEDIUM = 2
    HIGH = 3


PRIORITY_MAP = {
    "low": Priority.LOW,
    "medium": Priority.MEDIUM,
    "high": Priority.HIGH,
}

PRIORITY_TO_INT = {
    "low": 1,
    "medium": 2,
    "high": 3,
}

INT_TO_PRIORITY = {
    1: "low",
    2: "medium",
    3: "high",
}


@dataclass
class Task:
    id: Optional[int]
    description: str
    priority: int  # 1=low, 2=medium, 3=high
    status: str  # pending, running, completed, failed
    retry_count: int
    max_retries: int
    created_at: str
    updated_at: str

    @classmethod
    def from_row(cls, row: tuple) -> "Task":
        return cls(
            id=row[0],
            description=row[1],
            priority=row[2],
            status=row[3],
            retry_count=row[4],
            max_retries=row[5],
            created_at=row[6],
            updated_at=row[7],
        )


class Database:
    def __init__(self, db_path: str = "tasks.db"):
        self.db_path = db_path
        self._init_db()

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self):
        with self._get_connection() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    description TEXT NOT NULL,
                    priority INTEGER NOT NULL DEFAULT 2,
                    status TEXT NOT NULL DEFAULT 'pending',
                    retry_count INTEGER NOT NULL DEFAULT 0,
                    max_retries INTEGER NOT NULL DEFAULT 3,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status)
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority DESC)
            """)
            conn.commit()

    def create_task(self, description: str, priority: int) -> Task:
        now = datetime.utcnow().isoformat()
        with self._get_connection() as conn:
            cursor = conn.execute(
                """
                INSERT INTO tasks (description, priority, status, retry_count, max_retries, created_at, updated_at)
                VALUES (?, ?, 'pending', 0, 3, ?, ?)
                """,
                (description, priority, now, now),
            )
            conn.commit()
            task_id = cursor.lastrowid
            return self.get_task(task_id)

    def get_task(self, task_id: int) -> Optional[Task]:
        with self._get_connection() as conn:
            cursor = conn.execute(
                "SELECT * FROM tasks WHERE id = ?",
                (task_id,),
            )
            row = cursor.fetchone()
            if row is None:
                return None
            return Task.from_row(tuple(row))

    def get_all_tasks(self, status: Optional[str] = None) -> list[Task]:
        with self._get_connection() as conn:
            if status:
                cursor = conn.execute(
                    "SELECT * FROM tasks WHERE status = ? ORDER BY priority DESC, created_at ASC",
                    (status,),
                )
            else:
                cursor = conn.execute(
                    "SELECT * FROM tasks ORDER BY priority DESC, created_at ASC"
                )
            return [Task.from_row(tuple(row)) for row in cursor.fetchall()]

    def claim_task(self) -> Optional[Task]:
        """Claim the highest priority pending task atomically."""
        now = datetime.utcnow().isoformat()
        with self._get_connection() as conn:
            # Atomic claim: update and return in one operation
            # First, get the task with highest priority that is pending
            cursor = conn.execute(
                """
                SELECT id FROM tasks
                WHERE status = 'pending'
                ORDER BY priority DESC, created_at ASC
                LIMIT 1
                """,
            )
            row = cursor.fetchone()

            if row is None:
                return None

            task_id = row[0]

            # Update the task
            conn.execute(
                """
                UPDATE tasks SET status = 'running', updated_at = ?
                WHERE id = ?
                """,
                (now, task_id),
            )
            conn.commit()

            # Fetch the updated task
            return self.get_task(task_id)

    def claim_task_by_id(self, task_id: int) -> Optional[Task]:
        """Claim a specific task by ID if it is pending."""
        now = datetime.utcnow().isoformat()
        with self._get_connection() as conn:
            conn.execute(
                """
                UPDATE tasks SET status = 'running', updated_at = ?
                WHERE id = ? AND status = 'pending'
                """,
                (now, task_id),
            )
            conn.commit()

            # Verify the task was actually claimed
            return self.get_task(task_id)

    def complete_task(self, task_id: int) -> Optional[Task]:
        now = datetime.utcnow().isoformat()
        with self._get_connection() as conn:
            conn.execute(
                """
                UPDATE tasks SET status = 'completed', updated_at = ?
                WHERE id = ? AND status = 'running'
                """,
                (now, task_id),
            )
            conn.commit()
            return self.get_task(task_id)

    def fail_task(self, task_id: int) -> Optional[Task]:
        """
        Mark task as failed. If retries remaining, reset to pending.
        Otherwise, leave as failed.
        """
        with self._get_connection() as conn:
            cursor = conn.execute(
                "SELECT status, retry_count, max_retries FROM tasks WHERE id = ?",
                (task_id,),
            )
            row = cursor.fetchone()

            if row is None:
                return None

            status, retry_count, max_retries = row[0], row[1], row[2]

            if status != "running":
                return None

            now = datetime.utcnow().isoformat()

            # First increment retry_count
            new_retry_count = retry_count + 1

            # If we've exceeded max_retries, mark as failed
            if new_retry_count >= max_retries:
                conn.execute(
                    """
                    UPDATE tasks SET status = 'failed', retry_count = ?, updated_at = ?
                    WHERE id = ?
                    """,
                    (new_retry_count, now, task_id),
                )
                conn.commit()
            else:
                # Otherwise, reset to pending for retry
                conn.execute(
                    """
                    UPDATE tasks
                    SET status = 'pending', retry_count = ?, updated_at = ?
                    WHERE id = ?
                    """,
                    (new_retry_count, now, task_id),
                )
                conn.commit()

            return self.get_task(task_id)

    def get_queue_stats(self) -> dict:
        with self._get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT status, COUNT(*) as count FROM tasks GROUP BY status
                """
            )
            stats = {row[0]: row[1] for row in cursor.fetchall()}

            # Add priority breakdown for pending tasks
            cursor = conn.execute(
                """
                SELECT priority, COUNT(*) as count
                FROM tasks
                WHERE status = 'pending'
                GROUP BY priority
                ORDER BY priority DESC
                """
            )
            pending_by_priority = {INT_TO_PRIORITY[row[0]]: row[1] for row in cursor.fetchall()}

            return {
                "total": sum(stats.values()),
                "by_status": stats,
                "pending_by_priority": pending_by_priority,
            }
