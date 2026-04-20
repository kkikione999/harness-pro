# Workflow Summary: Delete Friend Feature (Both-Sides Removal)

## Task
Add a delete friend feature where removing a friend deletes the relationship for both users simultaneously.

## Steps Followed

### 1. Codebase Exploration
- Explored project structure: backend (Node.js/Fastify/Prisma) at `/Users/josh_folder/hp-sleeper-test/backend/`, iOS app at `/Users/josh_folder/hp-sleeper-test/HpSleeper/`
- Read Prisma schema to understand the `Friendship` model: single row with `requesterId` and `addresseeId`, unique constraint on `(requesterId, addresseeId)`, status enum (PENDING/ACCEPTED/REJECTED)
- Read existing backend routes (`friends.ts`), service (`friendService.ts`), and all iOS files (FriendsView, FriendRow, FriendsViewModel, APIService, models)

### 2. Analysis of Existing Implementation
- A `DELETE /friends/:id` endpoint already existed, accepting a `friendshipId` parameter
- The `removeFriend` service method deleted the single `Friendship` row, which technically removes the relationship for both sides (since there is only one row per friendship)
- However, the API required knowing the `friendshipId`, not the friend's `userId`
- The iOS client had a swipe-to-delete gesture but no confirmation dialog
- No explicit messaging to the user that the deletion affects both sides

### 3. Backend Changes

#### File: `/Users/josh_folder/hp-sleeper-test/backend/src/services/friendService.ts`
- Added `removeFriendByUserId(currentUserId, targetUserId)` method
- Uses `findFirst` with an OR query to find the accepted friendship in either direction (user could be requester or addressee)
- Validates: cannot remove self, friendship must exist and be ACCEPTED
- Deletes the single friendship row, which removes the relationship for both users

#### File: `/Users/josh_folder/hp-sleeper-test/backend/src/routes/friends.ts`
- Added `DELETE /friends/by-user/:userId` endpoint
- Takes the target friend's user ID as a path parameter (more ergonomic than requiring friendshipId)
- Error handling: 400 for self-removal, 404 for non-existent friendship, 500 for server errors

#### File: `/Users/josh_folder/hp-sleeper-test/backend/tests/friends.test.ts`
- Added `findFirst` mock to the Prisma mock object
- Added 5 new tests for `DELETE /friends/by-user/:userId`:
  1. Successfully removes friend by user ID (verifies bidirectional OR query and delete call)
  2. Works when current user is the addressee (reverse direction)
  3. Returns 400 when trying to remove self
  4. Returns 404 when friendship does not exist
  5. Returns 401 without auth token

### 4. iOS Changes

#### File: `/Users/josh_folder/hp-sleeper-test/HpSleeper/ViewModels/FriendsViewModel.swift`
- Added `removeFriendByUserId(_ userId: String)` method that calls `DELETE /friends/by-user/{userId}`
- Removes the friend from local `friends` array by matching `userId`

#### File: `/Users/josh_folder/hp-sleeper-test/HpSleeper/Views/Friends/FriendsView.swift`
- Added `@State private var friendToDelete: FriendInfo?` to track which friend is pending deletion
- Changed the swipe-to-delete action from immediately calling `removeFriend` to setting `friendToDelete`
- Added a `.alert` modifier with:
  - Title: "删除好友" (Delete Friend)
  - Cancel and Destructive (Delete) buttons
  - Message explicitly states: "删除后双方将不再是好友" (After deletion, neither side will be friends anymore)
  - On confirmation, calls `viewModel.removeFriendByUserId(friend.userId)`

## Decisions Made

1. **Added new endpoint instead of only modifying existing one**: The existing `DELETE /friends/:id` (by friendshipId) still works. Added `DELETE /friends/by-user/:userId` as a more ergonomic alternative since the iOS client naturally has the friend's `userId` available.

2. **Single-row deletion achieves "both sides" removal**: The Friendship model uses a single row per friendship pair. Deleting this one row effectively removes the friend relationship for both users. No need to delete multiple rows or add status tracking for deleted friendships.

3. **Only ACCEPTED friendships can be removed via the new endpoint**: The `removeFriendByUserId` method explicitly filters for `status: ACCEPTED`, preventing deletion of pending or rejected requests.

4. **Confirmation dialog on iOS**: Added an alert dialog before deletion to prevent accidental friend removal, with clear messaging that the action is mutual.

5. **Kept existing `removeFriend(friendshipId:)` method**: Did not remove the old method for backward compatibility.

## Files Modified

| File | Change |
|------|--------|
| `/Users/josh_folder/hp-sleeper-test/backend/src/services/friendService.ts` | Added `removeFriendByUserId` method |
| `/Users/josh_folder/hp-sleeper-test/backend/src/routes/friends.ts` | Added `DELETE /friends/by-user/:userId` route |
| `/Users/josh_folder/hp-sleeper-test/backend/tests/friends.test.ts` | Added `findFirst` mock + 5 new tests for the new endpoint |
| `/Users/josh_folder/hp-sleeper-test/HpSleeper/ViewModels/FriendsViewModel.swift` | Added `removeFriendByUserId` method |
| `/Users/josh_folder/hp-sleeper-test/HpSleeper/Views/Friends/FriendsView.swift` | Added confirmation alert dialog, changed delete flow |

## Test Results

All 33 tests pass (28 existing + 5 new):
```
tests/friends.test.ts (33 tests) 61ms
Test Files  1 passed (1)
     Tests  33 passed (33)
```

## Status: COMPLETE

All changes are implemented, tested, and consistent across backend and iOS frontend.
