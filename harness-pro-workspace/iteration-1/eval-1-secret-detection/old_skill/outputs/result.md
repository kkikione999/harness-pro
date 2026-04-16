# Old Skill Execution Result — Post Milestone 1

## Context

- **Project**: /tmp/test-p0-project
- **Milestone**: 1 (completed)
- **Changed files**: `Sources/Config.swift`
- **Skill version**: OLD (no lint checks)

## What the Old Skill Instructs After Worker Completes a Milestone

Per Step 3 (Milestone Review) of the old SKILL.md:

1. Spawn a **fresh reviewer Agent** (not the worker, not the coordinator)
2. The reviewer prompt includes:
   - Acceptance criteria for this milestone
   - List of changed files
3. The reviewer checks: spec compliance, code quality, test integrity, P0 rules
4. Report severity: CRITICAL (must fix now), HIGH (fix before next), MEDIUM (advisory)
5. **CRITICAL issues** -> fix before spawning the next milestone's worker
6. **HIGH issues** -> fix before next milestone
7. **MEDIUM issues** -> log and continue

## Lint Checks Performed

**None.** The old skill does not include any lint step between worker completion and reviewer spawn. There is no mention of running lint checks, P0 rule scanners, or secret detection at any point in the milestone completion flow.

The only quality gate is the reviewer Agent itself, which is instructed to "check P0 rules" as part of its review -- but this is a manual judgment call by the reviewer, not a mechanical lint check.

## File Content Under Review

```swift
// Sources/Config.swift
import Foundation

enum Config {
    static let apiKey: String = {
        guard let key = ProcessInfo.processInfo.environment["API_KEY"] else {
            fatalError("API_KEY environment variable is required")
        }
        return key
    }()
    static let baseURL = "https://api.example.com"
}
```

## Next Step Per Old Skill

Spawn reviewer Agent with prompt:

```
Review milestone 1 of feature config-setup.

Acceptance criteria: (from plan)
Changed files: Sources/Config.swift

Check: spec compliance, code quality, test integrity, P0 rules.
Report: CRITICAL (must fix now), HIGH (fix before next), MEDIUM (advisory).
Do NOT read the full plan — only the criteria and changed files listed above.
```

## Key Observation

The old skill has **no mechanical lint enforcement** at the milestone boundary. Secret detection, dependency direction checks, and other P0 lint rules rely entirely on the reviewer Agent's judgment. If the reviewer does not flag a hardcoded secret (e.g., if `baseURL` were an actual API key), it would pass through undetected.
