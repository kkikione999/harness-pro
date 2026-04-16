# Assessment Framework Reference

## Overview

The progressive-scaffolding skill assesses projects on 11 dimensions organized into 3 categories:

- **Controllability (E1-E4)**: Can the agent control the system?
- **Observability (O1-O4)**: Can the agent see what's happening?
- **Verification (V1-V3)**: Can the agent verify success?

## Controllability Dimensions

### E1: Execute — Can the agent trigger code execution?

| Level | Description | Indicators |
|-------|-------------|------------|
| 1 | Can run arbitrary bash commands | Always available |
| 2 | Has build system (Makefile/npm/go) | Can use `make`, `npm`, `go` |
| 3 | Sandboxed execution available | Docker, container isolation |

### E2: Intervene — Can the agent modify system state?

| Level | Description | Indicators |
|-------|-------------|------------|
| 1 | Read-only access | Cannot modify files |
| 2 | Can write files/configs | File write permissions |
| 3 | Can restart processes/services | Process management capability |

### E3: Input — Can the agent inject data into system?

| Level | Description | Indicators |
|-------|-------------|------------|
| 1 | Manual data injection | No automation |
| 2 | Environment variables / config files | Has .env or config.yaml |
| 3 | Runtime injection | API or dynamic config reload |

### E4: Orchestrate — Can the agent execute multi-step flows?

| Level | Description | Indicators |
|-------|-------------|------------|
| 1 | Manual multi-step | Must chain commands manually |
| 2 | Scripted sequences | Makefile with chained commands |
| 3 | Automated pipelines | Docker Compose, CI/CD |

## Observability Dimensions

### O1: Feedback — Can the system output information?

| Level | Description | Indicators |
|-------|-------------|------------|
| 1 | Basic stdout/stderr | Always available |
| 2 | Structured output | Has logging statements |
| 3 | Typed outputs | JSON logs, structured fields |

### O2: Persist — Is information retained?

| Level | Description | Indicators |
|-------|-------------|------------|
| 1 | In-memory only | Lost on restart |
| 2 | Log files | Has logs/ directory or .log files |
| 3 | Queryable storage | Structured logging (logrus, winston, zap) |

### O3: Queryable — Can history be searched?

| Level | Description | Indicators |
|-------|-------------|------------|
| 1 | No search capability | Raw log files, cannot query |
| 2 | Basic search | grep/cat logs, jq for JSON |
| 3 | Full query language | LogQL, Elasticsearch, Loki |

### O4: Attribute — Can causes be traced to results?

| Level | Description | Indicators |
|-------|-------------|------------|
| 1 | No tracing | No correlation mechanism |
| 2 | Request IDs | Has x-request-id or similar |
| 3 | Full correlation | Correlation IDs in all components |

## Verification Dimensions

### V1: Exit Code — Can the system report success/failure?

| Level | Description | Indicators |
|-------|-------------|------------|
| 1 | No exit codes | Ignores return values |
| 2 | Basic exit codes | Tests return 0/non-0 |
| 3 | Semantic exit | Typed exit codes (1=auth, 2=validation, etc.) |

### V2: Semantic — Can output be parsed?

| Level | Description | Indicators |
|-------|-------------|------------|
| 1 | Raw text | Human-readable only |
| 2 | Structured text | Parsable with regex |
| 3 | Machine-readable | JSON, XML, protobuf |

### V3: Automated — Can verification run without human?

| Level | Description | Indicators |
|-------|-------------|------------|
| 1 | Manual verification | Human must check results |
| 2 | Scripted verification | `make test` works |
| 3 | Auto-trigger on changes | CI/CD, pre-commit hooks |

## Usability Threshold

A project is "usable" for autonomous agent operation when:

- **All 3 categories reach Level 2 minimum**:
  - Controllability ≥ 8/12 (E1+E2+E3+E4 ≥ 8)
  - Observability ≥ 8/12 (O1+O2+O3+O4 ≥ 8)
  - Verification ≥ 6/9 (V1+V2+V3 ≥ 6)

This means no dimension can be at Level 1 in a usable project.

## Assessment Report Template

```markdown
## Assessment Report: [Project Name]

### Controllability (E1-E4)
| Dimension | Level | Evidence |
|-----------|-------|----------|
| E1 Execute | L2 | Makefile exists with run target |
| E2 Intervene | L2 | Can write files |
| E3 Input | L1 | No config injection |
| E4 Orchestrate | L1 | Manual multi-step |

**Score: 6/12 — Level 1**

### Observability (O1-O4)
| Dimension | Level | Evidence |
|-----------|-------|----------|
| O1 Feedback | L2 | Has console.log statements |
| O2 Persist | L1 | No log files |
| O3 Queryable | L1 | Cannot search logs |
| O4 Attribute | L1 | No correlation IDs |

**Score: 4/12 — Level 1**

### Verification (V1-V3)
| Dimension | Level | Evidence |
|-----------|-------|----------|
| V1 Exit Code | L2 | Tests return exit codes |
| V2 Semantic | L1 | Raw test output |
| V3 Automated | L2 | `make test` available |

**Score: 5/9 — Level 1**

### Overall: Level 1 — NOT USABLE

### Priority Gaps
1. **E3 Input** (L1→L2): Add .env file support
2. **O2 Persist** (L1→L2): Add logging framework
3. **O4 Attribute** (L1→L2): Add correlation IDs
```
