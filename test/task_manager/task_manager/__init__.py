"""Task manager package."""

# Lazy imports to avoid circular import issues
def __getattr__(name: str):
    """Lazy import implementation."""
    if name == "Task":
        from .models import Task as _Task
        return _Task
    elif name == "TaskStore":
        from .store import TaskStore as _TaskStore
        return _TaskStore
    else:
        raise AttributeError(f"module {__name__} has no attribute {name}")

__all__ = ["Task", "TaskStore"]
