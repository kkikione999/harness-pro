# Task 002: TaskStore with add, list, and get functionality

**Status**: Pending
**Priority**: High
**Estimated Complexity**: Medium

## Overview

Implement a TaskStore class to manage a collection of tasks with add, list, and get functionality.

## Requirements

### TaskStore Class

Create a `TaskStore` class in `test/task_manager/store.py` with the following methods:

#### `__init__(self)`
- Initialize an empty collection of tasks
- No parameters required

#### `add_task(self, task: Task) -> Task`
- Add a task to the store
- Store the task and return it
- Ensure the task is stored correctly
- Return the same task instance for potential chaining

#### `list_tasks(self) -> List[Task]`
- Return a list of all tasks in the store
- Return a new list (not a reference to internal storage)
- Include all tasks regardless of completion status
- Maintain insertion order

#### `get_task(self, title: str) -> Optional[Task]`
- Retrieve a task by its title
- Return the Task object if found
- Return None if no task with that title exists
- Case-sensitive matching

### Error Handling

- `add_task` should validate that the parameter is a Task instance
- Raise TypeError if not a Task instance
- Provide clear error messages

### Test Coverage

Implement comprehensive tests in `tests/test_store.py`:
- Test store initialization
- Test adding single task
- Test adding multiple tasks
- Test listing tasks returns copy
- Test listing tasks maintains order
- Test listing empty store
- Test getting existing task by title
- Test getting non-existent task returns None
- Test get_task is case-sensitive
- Test add_task validates Task type
- Test add_task rejects non-Task objects

## Acceptance Criteria

- [ ] TaskStore class is implemented in `store.py`
- [ ] All methods work as specified
- [ ] All tests pass with pytest
- [ ] Test coverage is at least 90% for TaskStore
- [ ] Code is clean and follows Python conventions
- [ ] Proper type hints used
- [ ] Clear error handling and messages

## Implementation Notes

- Use a list or dict for internal storage (choose appropriately)
- Consider whether to use unique IDs or titles for lookup
- Ensure immutability of returned lists (return copy)
- Maintain clear separation of concerns between Task and TaskStore
- Use Optional from typing for get_task return type

## Dependencies

Task 001 must be completed and merged (Task model available)

## Deliverables

- TaskStore implementation in `store.py`
- Comprehensive tests in `tests/test_store.py`
- All tests passing
- Updated documentation if needed

## Submission

Submit a pull request to the main branch with:
- Clear commit message: "Task 002: Implement TaskStore with add, list, and get functionality"
- All tests passing
- PR description referencing this task document
- Demonstrate that add, list, and get work correctly
