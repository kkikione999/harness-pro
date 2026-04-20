# Sleep History Reading Bug Fix Transcript

## Date
2026-04-20

## Project
/Users/josh_folder/hp-sleeper-test-without_skill

## Bug Description
When querying sleep history with a date range (`from` and `to` parameters), the API always returns empty results even though sleep records exist in the database.

## Investigation Process

### 1. Located Project Structure
Found the project at `/Users/josh_folder/hp-sleeper-test-without_skill` - a Swift iOS app with a Node.js/TypeScript backend.

### 2. Found Sleep API Routes
Located `/backend/src/routes/sleep.ts` which contains the GET `/sleep` endpoint for querying sleep history:
```typescript
// GET /sleep - Get sleep history
fastify.get('/', {
  handler: async (request, reply) => {
    const userId = request.userId!;
    const { from, to, limit } = request.query as {
      from?: string;
      to?: string;
      limit?: string;
    };

    const records = await sleepService.getSleepHistory(userId, {
        from: from ? new Date(from) : undefined,
        to: to ? new Date(to) : undefined,
        limit: limit ? parseInt(limit) : undefined,
    });
    // ...
  }
});
```

### 3. Found Sleep Service Implementation
Located `/backend/src/services/sleepService.ts` - the `getSleepHistory` function had the bug:

**BEFORE (Buggy):**
```typescript
async getSleepHistory(userId: string, options: SleepRecordQueryOptions = {}) {
  const { from, to, limit } = options;

  let where: any = { userId };

  if (from || to) {
    where.date = {};
    if (from) where.date.lte = from.toISOString().split('T')[0];  // WRONG!
    if (to) where.date.gte = to.toISOString().split('T')[0];    // WRONG!
  }

  return await prisma.sleepRecord.findMany({
    where,
    orderBy: { date: 'desc' },
    take: limit || 30,
  });
}
```

### 4. Identified Root Cause
The comparison operators were **reversed**:

| Parameter | Intended Meaning | Used Operator | Correct Operator |
|-----------|-----------------|---------------|------------------|
| `from` | Records FROM this date onwards | `lte` (less than or equal) | `gte` (greater than or equal) |
| `to` | Records UP TO this date | `gte` (greater than or equal) | `lte` (less than or equal) |

This caused the query to look for dates **earlier** than `from` and **later** than `to`, which is logically impossible when `from` < `to`.

### 5. Applied Fix
Changed the operators in `/backend/src/services/sleepService.ts`:

**AFTER (Fixed):**
```typescript
async getSleepHistory(userId: string, options: SleepRecordQueryOptions = {}) {
  const { from, to, limit } = options;

  let where: any = { userId };

  if (from || to) {
    where.date = {};
    if (from) where.date.gte = from.toISOString().split('T')[0];  // FIXED
    if (to) where.date.lte = to.toISOString().split('T')[0];    // FIXED
  }

  return await prisma.sleepRecord.findMany({
    where,
    orderBy: { date: 'desc' },
    take: limit || 30,
  });
}
```

## Files Changed
- `/Users/josh_folder/hp-sleeper-test-without_skill/backend/src/services/sleepService.ts` (lines 52-53)

## Test Notes
The existing test in `backend/tests/sleep.test.ts` (line 144-161) tests date range filters but doesn't verify the actual `where` clause. The mock always returns an empty array, which wouldn't catch this bug.

## Summary
Fixed the sleep history query bug by correcting the comparison operators for `from` and `to` date filters. The operators were swapped - `lte` should be `gte` for `from` parameter and vice versa for `to` parameter.
