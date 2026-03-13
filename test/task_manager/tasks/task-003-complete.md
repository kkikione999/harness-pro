# Task 003: Task completion marking functionality

**Status**: Pending
**Priority**: High
**Estimated Complexity**: Low

## Overview

Add functionality to mark tasks as completed/incomplete in both the Task model and TaskStore.

## Requirements

### Task Model Enhancement

Update the Task model (`task.py`) with completion methods:

#### `mark_complete(self) -> None`
- Mark the task as completed by setting `self.completed = True`
- No return value
- No validation needed (can mark already completed tasks)

#### `mark_incomplete(self) -> None`
- Mark the task as incomplete by setting `self.completed = False`
- No return value
- No validation needed (can mark already incomplete tasks)

#### `toggle_completion(self) -> None`
- Toggle the completion status (complete ↔ incomplete)
- If currently completed, mark as incomplete
- If currently incomplete, mark as complete
- No return value

### TaskStore Enhancement

Add convenience methods to TaskStore (`store.py`):

#### `mark_task_complete(self, title: str) -> Optional[Task]`
- Find a task by title and mark it as complete
- Return the Task if found and marked complete
- Return None if no task with that title exists

#### `mark_task_incomplete(self, title: str) -> Optional[Task]`
- Find a task by title and mark it as incomplete
- Return the Task if found and marked incomplete
- Return None if no task with that title exists

#### `toggle_task_completion(self, title: str) -> Optional[Task]`
- Find a task by title and toggle its completion status
- Return the Task if found and toggled
- Return None if no task with that title exists

### Test Coverage

Implement comprehensive tests in `tests/test_complete.py`:

#### Task Model Tests
- Test mark_complete sets completed to True
- Test mark_incomplete sets completed to False
- Test toggle_completion changes state appropriately
- Test can mark already completed task as complete
- Test can mark already incomplete task as incomplete
- Test multiple toggle operations work correctly

#### TaskStore Tests
- Test mark_task_complete finds and marks task
- Test mark_task_complete returns None for non-existent task
- Test mark_task_incomplete finds and unmarks task
- Test mark_task_incomplete returns None for non-existent task
- Test toggle_task_completion toggles existing task
- Test toggle_task_completion returns None for non-existent task
- Test completion status persists in list_tasks
- Test multiple completion operations work correctly

## Acceptance Criteria

- [ ] Task model has mark_complete, mark_incomplete, and toggle_completion methods
- [ ] TaskStore has mark_task_complete, mark_task_incomplete, and toggle_task_completion methods
- [ ] All existing tests still pass (48 tests)
- [ ] New tests pass with pytest
- [ ] Test coverage is maintained or improved
- [ ] Code is clean and follows Python conventions
- [ ] Methods are intuitive and easy to use

## Implementation Notes

- Keep methods simple and focused
- Use existing get_task method in TaskStore for finding tasks
- Don't break backward compatibility with existing code
- Add docstrings to new methods
- Follow existing code style and patterns

## Dependencies

Task 001 and Task 002 must be completed and merged (Task model and TaskStore available)

## Deliverables

- Enhanced Task model in `task.py`
- Enhanced TaskStore in `store.py`
- Comprehensive tests in `tests/test_complete.py`
- All tests passing (existing + new)

## Submission

Submit a pull request to the main branch with:
- Clear commit message: "Task 003: Add task completion marking functionality"
- All tests passing (48+ tests)
- PR description referencing this task document
- Demonstrate that completion marking works correctly
