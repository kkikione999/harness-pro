# Observability Scripts for Open-ClaudeCode

A set of TypeScript modules and a shell script for monitoring and understanding the behavior of the Open-ClaudeCode CLI project. Tailored to the project's existing telemetry infrastructure (OpenTelemetry, Datadog, BigQuery, Perfetto, 1P event logging).

## Files

| File | Purpose |
|------|---------|
| `01-structured-logger.ts` | Leveled structured logging with JSON output, trace correlation, and child loggers |
| `02-metrics-collector.ts` | In-process metrics (counters, histograms, gauges) with CLI-specific helpers for API calls, tool execution, tokens, permissions |
| `03-health-checker.ts` | Runtime health assessment: memory, event loop, disk, API connectivity, auth, telemetry pipeline, Node.js version |
| `04-session-tracer.ts` | Lightweight span-based tracing mirroring the project's `sessionTracing.ts` span types (interaction, llm_request, tool, hook) |
| `05-telemetry-pipeline-monitor.ts` | Monitors the health of all telemetry export pipelines (OTLP, BigQuery, Datadog, 1P, Perfetto) with stall/degradation detection |
| `06-analytics-event-inspector.ts` | Captures and validates analytics events against the project's known taxonomy, detects PII leaks and schema violations |
| `07-observability-integration.ts` | Unified facade wiring all primitives together with a single `init()` / `diagnose()` / `exportAll()` API |
| `observability-agent.sh` | Shell script for CLI-based diagnostics: health checks, telemetry config, trace file inspection, environment audit |

## Quick Start

### Shell Script (no build required)

```bash
chmod +x observability-agent.sh

# Full diagnostic
./observability-agent.sh diagnose

# Specific checks
./observability-agent.sh health
./observability-agent.sh telemetry
./observability-agent.sh traces
./observability-agent.sh session
```

### TypeScript Integration

```typescript
import { createObservability } from './07-observability-integration'

const obs = createObservability({
  sessionId: 'my-session-123',
  minLogLevel: 'info',
})

await obs.init()

// During session: trace API calls
obs.trace.apiCall({
  model: 'claude-sonnet-4',
  durationMs: 1230,
  inputTokens: 1500,
  outputTokens: 800,
  ttftMs: 340,
  status: 200,
  success: true,
})

// Trace tool calls
obs.trace.toolCall({
  toolName: 'Read',
  durationMs: 45,
  success: true,
})

// Run diagnostics at any point
const diag = await obs.diagnose()
console.log(diag.health.status)        // 'pass' | 'warn' | 'fail'
console.log(diag.telemetry.overallStatus) // 'healthy' | 'degraded' | 'error'
console.log(diag.recommendations)       // Actionable advice

// Export everything as JSON
const data = obs.exportAll()
```

## Alignment with Project Architecture

These scripts are designed around the existing telemetry subsystems found in the Open-ClaudeCode codebase:

| Subsystem | Project Source | Observability Script |
|-----------|---------------|---------------------|
| OpenTelemetry metrics/logs/traces | `src/utils/telemetry/instrumentation.ts` | `02-metrics-collector.ts`, `05-telemetry-pipeline-monitor.ts` |
| BigQuery metrics export | `src/utils/telemetry/bigqueryExporter.ts` | `05-telemetry-pipeline-monitor.ts` |
| Datadog event tracking | `src/services/analytics/datadog.ts` | `05-telemetry-pipeline-monitor.ts`, `06-analytics-event-inspector.ts` |
| 1P event logging | `src/services/analytics/firstPartyEventLogger.ts` | `05-telemetry-pipeline-monitor.ts`, `06-analytics-event-inspector.ts` |
| Session tracing | `src/utils/telemetry/sessionTracing.ts` | `04-session-tracer.ts` |
| Perfetto tracing | `src/utils/telemetry/perfettoTracing.ts` | `observability-agent.sh` (trace file inspection) |
| Event taxonomy | `datadog.ts` DATADOG_ALLOWED_EVENTS | `06-analytics-event-inspector.ts` |
| Diagnostics logger | `src/utils/telemetry/logger.ts` (ClaudeCodeDiagLogger) | `01-structured-logger.ts` |
| Event metadata | `src/services/analytics/metadata.ts` | `06-analytics-event-inspector.ts` |
| Plugin telemetry | `src/utils/telemetry/pluginTelemetry.ts` | `02-metrics-collector.ts` (via tool metrics) |

## Agent Decision Guide

An AI agent can use these scripts to make autonomous decisions:

1. **Before starting work**: Run `obs.init()` and check health. If `health.status !== 'pass'`, address failures first.
2. **During API calls**: Wrap every LLM request with `obs.trace.apiCall()`. Check `diag.telemetry.overallStatus` periodically.
3. **After tool execution**: Record results with `obs.trace.toolCall()`. If success rate drops below 80%, investigate.
4. **On errors**: Check `diag.recommendations` for actionable fixes. The telemetry monitor detects 5+ consecutive failures automatically.
5. **Before exit**: Call `obs.exportAll()` to capture a final snapshot for post-mortem analysis.
