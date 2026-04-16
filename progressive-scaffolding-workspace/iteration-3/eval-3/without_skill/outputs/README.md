# Observability Scripts for Open-ClaudeCode

A set of TypeScript observability utilities designed to help an AI agent monitor and understand the Open-ClaudeCode CLI project's behavior. These scripts integrate with the project's existing OpenTelemetry pipeline, analytics sink, and session tracing infrastructure.

## Architecture

The observability layer consists of four interconnected subsystems orchestrated by a central monitor:

```
ObservabilityMonitor (entry point)
  |
  +-- ObservabilityLogger   -- structured JSON logging to console, file, and OTLP
  +-- MetricsCollector      -- counters, gauges, histograms with Prometheus export
  +-- HealthChecker         -- liveness, readiness, and deep health probes
  +-- ObservabilityTracer   -- distributed tracing with OTLP and Chrome Trace export
```

## Files

| File | Purpose |
|------|---------|
| `monitor.ts` | Central orchestrator wiring all subsystems together |
| `observability-logger.ts` | Structured logging with console, file, and OTLP outputs |
| `metrics-collector.ts` | Runtime metrics collection and export |
| `health-check.ts` | Process health probes and HTTP endpoint |
| `tracing.ts` | Distributed tracing with span lifecycle management |

## How Each Script Relates to the Project

### Logging (`observability-logger.ts`)
Aligns with `src/utils/telemetry/events.ts` (logOTelEvent) and `src/utils/telemetry/logger.ts` (ClaudeCodeDiagLogger). Produces NDJSON logs compatible with the project's OTLP log pipeline and includes the same correlation attributes (session_id, trace_id, span_id) used by the existing telemetry infrastructure.

### Metrics (`metrics-collector.ts`)
Mirrors the metrics naming conventions from `src/utils/telemetry/bigqueryExporter.ts` and `src/services/analytics/metadata.ts` (ProcessMetrics). Tracks the same categories the project already monitors:
- LLM request latency (TTFT, TTLT), token throughput, cache hit rates
- Tool invocation counts, durations, success/failure rates
- System resource usage (RSS, heap, CPU%, event loop lag)
- Session-level interaction aggregations

Exports in Prometheus exposition format for scraping, OTLP JSON for collectors, and JSON snapshots for health checks.

### Health Checks (`health-check.ts`)
Validates subsystems specific to this CLI project:
- Telemetry pipeline initialization (mirrors `src/utils/telemetry/instrumentation.ts` bootstrap checks)
- Analytics sink attachment (mirrors `src/services/analytics/sink.ts` initialization)
- Config directory writability (`~/.claude`)
- API connectivity to Anthropic endpoints
- Process memory pressure and event loop responsiveness

Exposes three probe endpoints following Kubernetes conventions: `/health/live`, `/health/ready`, `/health`.

### Tracing (`tracing.ts`)
Follows the same span hierarchy as `src/utils/telemetry/sessionTracing.ts`:
- `interaction` spans wrap full user-request cycles
- `llm_request` spans track API calls with TTFT/TTLT sub-phases
- `tool` spans capture tool invocations with permission decisions
- `hook` spans trace pre/post tool use hooks

Exports in both OTLP JSON (for Jaeger/Zipkin/Tempo) and Chrome Trace Event format (for Perfetto UI), matching the dual-export approach in `src/utils/telemetry/perfettoTracing.ts`.

## Usage

### Minimal Setup

```typescript
import { ObservabilityMonitor } from './monitor'

const monitor = new ObservabilityMonitor({
  component: 'agent-observer',
})

// Record an LLM request
monitor.traceLLMCycle({
  model: 'claude-sonnet-4-20250514',
  ttftMs: 340,
  ttltMs: 2500,
  inputTokens: 1200,
  outputTokens: 450,
  success: true,
})

// Record a tool invocation
monitor.traceToolCycle({
  tool: 'Bash',
  durationMs: 120,
  success: true,
})

// Get diagnostics
const snapshot = await monitor.getDiagnosticSnapshot()

// Shut down
await monitor.shutdown()
```

### Full Setup with HTTP Endpoints

```typescript
const monitor = new ObservabilityMonitor({
  component: 'production-monitor',
  sessionId: 'abc-123',
  enablePrometheus: true,       // GET http://localhost:9464/metrics
  prometheusPort: 9464,
  enableHealthServer: true,     // GET http://localhost:8080/health
  healthPort: 8080,
  enableFileLogging: true,
  enableOTLPLogging: true,
  otlpEndpoint: 'http://localhost:4318',
  traceSampleRate: 0.5,
})
```

### Standalone Subsystem Usage

Each subsystem can be used independently:

```typescript
// Just logging
import { ObservabilityLogger } from './observability-logger'
const logger = new ObservabilityLogger({ component: 'my-script' })

// Just metrics
import { MetricsCollector } from './metrics-collector'
const metrics = new MetricsCollector()
metrics.startPrometheusEndpoint(9464)

// Just health checks
import { HealthChecker } from './health-check'
const health = new HealthChecker()
health.startServer(8080)

// Just tracing
import { ObservabilityTracer } from './tracing'
const tracer = new ObservabilityTracer({ serviceName: 'my-script' })
```

## Environment Variables

The scripts respect the same environment variables used by the project's existing telemetry:

| Variable | Purpose | Default |
|----------|---------|---------|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | Enable telemetry pipeline | unset (disabled) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP collector URL | none |
| `OTEL_LOGS_EXPORTER` | Log exporter type | none |
| `OTEL_TRACES_EXPORTER` | Trace exporter type | none |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | OTLP protocol (grpc, http/json, http/protobuf) | none |
| `OTEL_LOGS_EXPORT_INTERVAL` | Log batch flush interval (ms) | 5000 |
| `OTEL_METRIC_EXPORT_INTERVAL` | Metrics export interval (ms) | 60000 |
| `CLAUDE_CONFIG_DIR` | Config directory path | `~/.claude` |
| `ANTHROPIC_BASE_URL` | API base URL for health checks | `https://api.anthropic.com` |
