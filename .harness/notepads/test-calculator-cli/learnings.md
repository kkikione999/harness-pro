# Project Learnings - Simple Calculator CLI

*This file accumulates patterns, conventions, and discoveries across all tasks.*

## [task-001] Project initialization

**Conventions Established:**
- ESM-first project: `"type": "module"` in package.json
- Modern TypeScript: ES2022 target, ESNext modules, strict mode enabled
- Standard scripts: `build` (tsc), `test` (vitest), `lint` (tsc --noEmit), `calc` (run CLI)
- Clean directory structure: `src/` for source, `tests/` for tests, `dist/` for build output

**Configuration Patterns:**
- tsconfig.json uses `"moduleResolution": "node"` for ESM compatibility
- OutDir maps to `./dist`, RootDir maps to `./src`
- Bin field in package.json: `{"calc": "./dist/cli.js"}` for CLI installation
- SkipLibCheck and forceConsistentCasingInFileNames enabled for robustness

**Gotchas:**
- Empty `src/` directory causes TypeScript "no inputs" error - this is expected during bootstrap
- Git on Windows may convert LF to CRLF in config files (harmless for JSON)
- Main branch is `master`, not `main` (repository-specific)
- Worktrees must be managed carefully when switching between branches

**Validation Notes:**
- Architecture constraint check not applicable for bootstrap task (tooling doesn't exist yet)
- Configuration-only tasks don't require test coverage
- All configuration files should be syntax-verified before committing
