# Context: test-feature

## Patterns Discovered
- TypeScript utility functions in src/ directory
- Currency formatting uses Record<string, string> for symbol mapping
- Uses toLocaleString for number formatting with en-US locale
- Input validation: negative amounts return "0.00"
- Error handling: parseFloat with fallback to 0 for invalid input

## Key Insights
- formatCurrency already exists and matches acceptance criteria
- parseCurrency helper function exists for inverse operation
- Symbol mapping is extensible via Record type
- No test file exists yet - TDD approach needed

## File Locations
- Entry point: src/format.ts
- Feature index: features/test-feature/index.md
- Plan to create: features/test-feature/plan.md
