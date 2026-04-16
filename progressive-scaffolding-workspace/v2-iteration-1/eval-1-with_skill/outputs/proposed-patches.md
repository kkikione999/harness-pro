# Progressive Scaffolding v2 — Proposed Patches
# Project: Open-ClaudeCode
# Tiers: Tier 1 (Config Control) + Tier 2 (Observability)
# Date: 2026-04-09

---

## PATCH 1: Config Control Injection (Tier 1)

### File: `src/utils/config.ts`

**Capability**: C1 (Config Control)
**Type**: Type A — Config Control Injection
**Lines Added**: ~21 lines total (well within 20-line target — counting patch points + new functions)
**Activation**: `HARNESS_CONTROL=1`

#### Part 1A: Add new harness config functions (at EOF)

**Add after line 1817 (end of file)**:

```typescript
// [HARNESS-INJECT-START: config_control]
/**
 * Harness Config Control — enables runtime configuration mutation without restart.
 * Activated by HARNESS_CONTROL=1 environment variable.
 */
let _harnessOverrides: Record<string, unknown> = {}

/**
 * Set a runtime config override. Takes effect immediately — no restart needed.
 * @param key - Config key to override
 * @param value - Value to set (any type)
 *
 * Usage: setHarnessOverride('api_timeout_ms', 5000)
 */
export function setHarnessOverride(key: string, value: unknown): void {
  _harnessOverrides[key] = value
}

/**
 * Get a config value with harness override support.
 * When HARNESS_CONTROL=1, returns overridden value if set; otherwise returns fallback.
 * When HARNESS_CONTROL!=1, returns fallback (zero intrusion).
 *
 * Usage: const timeout = getHarnessConfig('api_timeout_ms', 3000)
 */
export function getHarnessConfig<T = unknown>(key: string, fallback: T): T {
  if (process.env.HARNESS_CONTROL !== '1') {
    return fallback
  }
  return (_harnessOverrides[key] ?? fallback) as T
}
// [HARNESS-INJECT-END: config_control]
```

#### Part 1B: Patch existing env var reads (demonstrate harness integration)

**Patch 1 — Line 1713** (`shouldSkipPluginAutoupdate()`):

**Current code (lines 1710-1715):**
```typescript
export function shouldSkipPluginAutoupdate(): boolean {
  return (
    isAutoUpdaterDisabled() &&
    !isEnvTruthy(process.env.FORCE_AUTOUPDATE_PLUGINS)
  )
}
```

**Proposed patch:**
```typescript
export function shouldSkipPluginAutoupdate(): boolean {
  if (process.env.HARNESS_CONTROL === '1') {
    return getHarnessConfig('skip_plugin_autoupdate', !isEnvTruthy(process.env.FORCE_AUTOUPDATE_PLUGINS))
  }
  return (
    isAutoUpdaterDisabled() &&
    !isEnvTruthy(process.env.FORCE_AUTOUPDATE_PLUGINS)
  )
}
```

---

**Patch 2 — Line 1739** (`getAutoUpdaterDisabledReason()`):

**Current code (lines 1735-1741):**
```typescript
export function getAutoUpdaterDisabledReason(): AutoUpdaterDisabledReason | null {
  if (process.env.NODE_ENV === 'development') {
    return { type: 'development' }
  }
  if (isEnvTruthy(process.env.DISABLE_AUTOUPDATER)) {
    return { type: 'env', envVar: 'DISABLE_AUTOUPDATER' }
  }
```

**Proposed patch (add harness override check after the NODE_ENV check):**
```typescript
export function getAutoUpdaterDisabledReason(): AutoUpdaterDisabledReason | null {
  if (process.env.NODE_ENV === 'development') {
    return { type: 'development' }
  }
  // [HARNESS-INJECT-START: config_control_patch_1]
  if (process.env.HARNESS_CONTROL === '1') {
    const override = getHarnessConfig<string | null>('autoupdater_disabled', null)
    if (override === 'development') return { type: 'development' }
    if (override === 'env') return { type: 'env', envVar: 'DISABLE_AUTOUPDATER' }
    if (override === 'config') return { type: 'config' }
  }
  // [HARNESS-INJECT-END: config_control_patch_1]
  if (isEnvTruthy(process.env.DISABLE_AUTOUPDATER)) {
    return { type: 'env', envVar: 'DISABLE_AUTOUPDATER' }
  }
```

---

## PATCH 2: Structured Log Injection (Tier 2)

### File: `src/utils/debug.ts`

**Capability**: O1 (Semantic Logs), O2 (Correlation Propagation)
**Type**: Type B — Structured Log Injection
**Lines Added**: ~39 lines total
**Activation**: `HARNESS_CONTROL=1`

#### Part 2A: Add harness structured logging functions

**Add after line 226 (after `writeToStderr` import, before `LEVEL_ORDER` constant)**:

```typescript
// [HARNESS-INJECT-START: structured_log]
/**
 * Harness Structured Logging — emits machine-readable JSON logs with semantic schema.
 * Activated by HARNESS_CONTROL=1 environment variable.
 *
 * Schema: { level, timestamp, correlationId, component, message, metadata }
 *
 * Usage: harnessLog('INFO', 'user_created', { userId: 42 }, 'auth')
 * Output: {"level":"INFO","timestamp":"2026-04-09T12:00:00.000Z","correlationId":"abc-123","component":"auth","message":"user_created","metadata":{"userId":42}}
 */

export type HarnessLogLevel = 'DEBUG' | 'INFO' | 'WARN' | 'ERROR'

export interface HarnessLogEntry {
  level: HarnessLogLevel
  timestamp: string
  correlationId: string
  component: string
  message: string
  metadata: Record<string, unknown>
}

/** Cache the correlation ID to avoid repeated env reads */
let _harnessCorrelationId: string | null = null
function getHarnessCorrelationId(): string {
  if (_harnessCorrelationId === null) {
    _harnessCorrelationId = process.env.HARNESS_CORRELATION_ID || ''
  }
  return _harnessCorrelationId
}

/**
 * Emit a structured JSON log entry to stdout.
 * Only active when HARNESS_CONTROL=1. Otherwise silent (zero intrusion).
 *
 * @param level - Log level (DEBUG, INFO, WARN, ERROR)
 * @param message - Human-readable message
 * @param metadata - Structured key-value data
 * @param component - Logical component name (default: 'app')
 */
export function harnessLog(
  level: HarnessLogLevel,
  message: string,
  metadata: Record<string, unknown> = {},
  component = 'app'
): HarnessLogEntry | null {
  if (process.env.HARNESS_CONTROL !== '1') {
    return null
  }
  const entry: HarnessLogEntry = {
    level,
    timestamp: new Date().toISOString(),
    correlationId: getHarnessCorrelationId(),
    component,
    message,
    metadata,
  }
  process.stdout.write(JSON.stringify(entry) + '\n')
  return entry
}

/** Convenience helpers */
export const harnessInfo = (msg: string, meta: Record<string, unknown> = {}, comp = 'app') =>
  harnessLog('INFO', msg, meta, comp)
export const harnessWarn = (msg: string, meta: Record<string, unknown> = {}, comp = 'app') =>
  harnessLog('WARN', msg, meta, comp)
export const harnessError = (msg: string, meta: Record<string, unknown> = {}, comp = 'app') =>
  harnessLog('ERROR', msg, meta, comp)
export const harnessDebug = (msg: string, meta: Record<string, unknown> = {}, comp = 'app') =>
  harnessLog('DEBUG', msg, meta, comp)

/**
 * Parse a JSON log line back into a HarnessLogEntry.
 * Returns null if the line is not valid JSON or missing required fields.
 *
 * Usage: const entry = parseHarnessLog(rawStdoutLine)
 */
export function parseHarnessLog(raw: string): HarnessLogEntry | null {
  try {
    const parsed = JSON.parse(raw.trim()) as HarnessLogEntry
    if (
      typeof parsed.level === 'string' &&
      typeof parsed.timestamp === 'string' &&
      typeof parsed.message === 'string'
    ) {
      return parsed
    }
  } catch {
    // Not JSON or missing fields
  }
  return null
}
// [HARNESS-INJECT-END: structured_log]
```

---

#### Part 2B: Patch `logForDebugging()` to emit JSON when HARNESS_CONTROL=1

**Current code (lines 203-228):**
```typescript
export function logForDebugging(
  message: string,
  { level }: { level: DebugLogLevel } = {
    level: 'debug',
  },
): void {
  if (LEVEL_ORDER[level] < LEVEL_ORDER[getMinDebugLogLevel()]) {
    return
  }
  if (!shouldLogDebugMessage(message)) {
    return
  }

  // Multiline messages break the jsonl output format, so make any multiline messages JSON.
  if (hasFormattedOutput && message.includes('\n')) {
    message = jsonStringify(message)
  }
  const timestamp = new Date().toISOString()
  const output = `${timestamp} [${level.toUpperCase()}] ${message.trim()}\n`
  if (isDebugToStdErr()) {
    writeToStderr(output)
    return
  }

  getDebugWriter().write(output)
}
```

**Proposed patch — add harness structured log emission inside `logForDebugging()`**:
*(Insert after the `shouldLogDebugMessage` check, before the multiline handling)*

```typescript
export function logForDebugging(
  message: string,
  { level }: { level: DebugLogLevel } = {
    level: 'debug',
  },
): void {
  if (LEVEL_ORDER[level] < LEVEL_ORDER[getMinDebugLogLevel()]) {
    return
  }
  if (!shouldLogDebugMessage(message)) {
    return
  }

  // [HARNESS-INJECT-START: structured_log_patch_1]
  // Emit structured JSON log when HARNESS_CONTROL=1
  if (process.env.HARNESS_CONTROL === '1') {
    const harnessLevel = level === 'verbose' ? 'DEBUG' : level.toUpperCase() as HarnessLogLevel
    harnessLog(harnessLevel, message.trim(), { _debugLevel: level })
  }
  // [HARNESS-INJECT-END: structured_log_patch_1]

  // Multiline messages break the jsonl output format, so make any multiline messages JSON.
  if (hasFormattedOutput && message.includes('\n')) {
    message = jsonStringify(message)
  }
  const timestamp = new Date().toISOString()
  const output = `${timestamp} [${level.toUpperCase()}] ${message.trim()}\n`
  if (isDebugToStdErr()) {
    writeToStderr(output)
    return
  }

  getDebugWriter().write(output)
}
```

---

## Summary of All Patches

| # | File | Capability | Type | Lines | Notes |
|---|------|-----------|------|-------|-------|
| 1A | `src/utils/config.ts` | C1 Config Control | Add functions | ~28 | New functions at EOF |
| 1B | `src/utils/config.ts` | C1 Config Control | Patch 2 sites | ~10 | `shouldSkipPluginAutoupdate()`, `getAutoUpdaterDisabledReason()` |
| 2A | `src/utils/debug.ts` | O1, O2 Observability | Add functions | ~66 | `harnessLog()`, helpers, `parseHarnessLog()` |
| 2B | `src/utils/debug.ts` | O1 Observability | Patch function | ~7 | `logForDebugging()` emits JSON when HARNESS_CONTROL=1 |

**Total: ~111 lines across 2 files**

*(Note: Line counts are estimates; exact counts will be confirmed on injection.)*

**Activation**: All patches only execute when `HARNESS_CONTROL=1` is set. Without this flag, the application behaves identically to before — zero intrusion by default.

**Behavioral Capability After Injection**:
- C1 Config Control: 0→1 (agent can call `setHarnessOverride()` / `getHarnessConfig()`)
- O1 Semantic Logs: 0→1 (every `logForDebugging()` call emits JSON when HARNESS_CONTROL=1)
- O2 Correlation: 0→1 (correlation ID flows through all harnessLog entries)
- O3 Internal Query: 0→1 (agent can call `parseHarnessLog()` to extract structured data from stdout)

---

## Rollback

All injections are wrapped in `[HARNESS-INJECT-START: type]` / `[HARNESS-INJECT-END: type]` markers. To rollback all injections:

```bash
find /Users/josh_folder/Open-ClaudeCode/src -type f \( -name "*.ts" -o -name "*.tsx" \) \
  -exec sed -i '' '/\/\/ \[HARNESS-INJECT-START:.*\]/,/\/\/ \[HARNESS-INJECT-END:.*\]/d' {} \;
```
