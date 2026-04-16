# Plan: test-feature

## Context

The feature requires a currency formatting utility. Reading `src/format.ts` reveals the `formatCurrency` function already exists and implements the required behavior:
- Returns proper format like "$1,234.56"
- Handles USD and EUR currencies via symbol mapping
- Returns "0.00" for negative amounts

The implementation matches all acceptance criteria. However, no tests exist - this plan focuses on adding test coverage via TDD.

## Changes

### src/format.test.ts (NEW)
- **`formatCurrency`** — Create unit tests covering:
  - USD format "$1,234.56"
  - EUR format "€1,234.56"
  - Zero amount "0.00"
  - Negative amount returns "0.00"
  - Large numbers with proper separators

### src/format.ts
- No changes needed - implementation already satisfies acceptance criteria

## Order

1. Create `src/format.test.ts` with comprehensive unit tests for `formatCurrency`
2. Run tests to verify RED (tests fail because no test file exists yet)
3. Verify tests pass (GREEN) - implementation already correct
4. Consider additional test for `parseCurrency` helper if needed

## Milestones

### M1: Test Coverage for formatCurrency
- Create `src/format.test.ts` with all edge cases
- Verify: `npm test` or equivalent test command passes

## Validation

- **AC1 (Function signature)**: Verified by TypeScript compilation
- **AC2 (Proper format)**: Test verifies "$1,234.56" output for 1234.56
- **AC3 (USD/EUR)**: Tests verify both $ and € symbols
- **AC4 (No negatives)**: Test verifies "0.00" for negative input

Run: `npm test` or `npx vitest run` (depending on test setup)

## Risks

- **Risk**: Test runner not configured → Mitigation: Check for jest/vitest config, create if needed
