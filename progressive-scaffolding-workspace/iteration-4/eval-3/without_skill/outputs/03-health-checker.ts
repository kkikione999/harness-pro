/**
 * Health Checker for Open-ClaudeCode Observability
 *
 * Provides runtime health assessment for a CLI process, checking subsystems
 * that the project depends on: API connectivity, auth state, telemetry pipeline,
 * disk space for traces, memory pressure, and process responsiveness.
 *
 * Aligned with project subsystems:
 *   - Auth: src/utils/auth.ts (getSubscriptionType, isClaudeAISubscriber, is1PApiCustomer)
 *   - Telemetry: src/utils/telemetry/instrumentation.ts (isTelemetryEnabled, flushTelemetry)
 *   - API: src/services/api/ (API key, rate limits)
 *   - Config: src/utils/config.ts (getClaudeConfigHomeDir)
 *   - Perfetto: src/utils/telemetry/perfettoTracing.ts (trace file writes)
 *
 * Usage by AI agents:
 *   const health = await runHealthCheck()
 *   if (health.status !== 'healthy') {
 *     console.error('Unhealthy subsystems:', health.checks.filter(c => c.status !== 'pass'))
 *   }
 */

// ---------- Types ----------

export type HealthStatus = 'pass' | 'warn' | 'fail'

export interface HealthCheck {
  name: string
  status: HealthStatus
  message: string
  durationMs: number
  metadata?: Record<string, unknown>
}

export interface HealthReport {
  status: HealthStatus
  timestamp: string
  uptimeSeconds: number
  checks: HealthCheck[]
  process: {
    pid: number
    nodeVersion: string
    platform: string
    arch: string
    memoryUsage: {
      rssBytes: number
      heapTotalBytes: number
      heapUsedBytes: number
      externalBytes: number
    }
    cpuUsage: {
      userMicros: number
      systemMicros: number
    }
  }
}

// ---------- Individual check implementations ----------

async function timeCheck<T>(
  name: string,
  fn: () => Promise<T>,
  evaluate: (result: T) => { status: HealthStatus; message: string; metadata?: Record<string, unknown> },
): Promise<HealthCheck> {
  const start = Date.now()
  try {
    const result = await fn()
    const eval_ = evaluate(result)
    return {
      name,
      status: eval_.status,
      message: eval_.message,
      durationMs: Date.now() - start,
      metadata: eval_.metadata,
    }
  } catch (err) {
    return {
      name,
      status: 'fail',
      message: err instanceof Error ? err.message : String(err),
      durationMs: Date.now() - start,
    }
  }
}

// ---------- Checks ----------

async function checkProcessMemory(): Promise<HealthCheck> {
  return timeCheck(
    'process.memory',
    async () => process.memoryUsage(),
    (mem) => {
      const heapUsedMB = mem.heapUsed / (1024 * 1024)
      const rssMB = mem.rss / (1024 * 1024)

      // Thresholds tuned for a long-running CLI session
      if (rssMB > 2048) {
        return {
          status: 'fail',
          message: `RSS memory exceeds 2GB: ${rssMB.toFixed(0)}MB`,
          metadata: { rssMB: Math.round(rssMB), heapUsedMB: Math.round(heapUsedMB) },
        }
      }
      if (heapUsedMB > 1024) {
        return {
          status: 'warn',
          message: `Heap usage high: ${heapUsedMB.toFixed(0)}MB`,
          metadata: { rssMB: Math.round(rssMB), heapUsedMB: Math.round(heapUsedMB) },
        }
      }
      return {
        status: 'pass',
        message: `Memory healthy: RSS ${rssMB.toFixed(0)}MB, heap ${heapUsedMB.toFixed(0)}MB`,
        metadata: { rssMB: Math.round(rssMB), heapUsedMB: Math.round(heapUsedMB) },
      }
    },
  )
}

async function checkEventLoopLag(): Promise<HealthCheck> {
  return timeCheck(
    'process.event_loop',
    async () => new Promise<number>((resolve) => {
      const start = Date.now()
      setImmediate(() => resolve(Date.now() - start))
    }),
    (lag) => {
      if (lag > 100) {
        return { status: 'fail', message: `Event loop lag: ${lag}ms`, metadata: { lagMs: lag } }
      }
      if (lag > 50) {
        return { status: 'warn', message: `Event loop lag: ${lag}ms`, metadata: { lagMs: lag } }
      }
      return { status: 'pass', message: `Event loop responsive: ${lag}ms lag`, metadata: { lagMs: lag } }
    },
  )
}

async function checkDiskSpace(configDir: string): Promise<HealthCheck> {
  return timeCheck(
    'disk.config_dir',
    async () => {
      const fs = await import('fs/promises')
      const stat = await fs.stat(configDir)
      return { exists: true, isDirectory: stat.isDirectory() }
    },
    (result) => {
      if (!result.exists || !result.isDirectory) {
        return { status: 'fail', message: `Config dir inaccessible: ${configDir}` }
      }
      return { status: 'pass', message: `Config dir accessible: ${configDir}` }
    },
  )
}

async function checkApiConnectivity(apiBaseUrl: string): Promise<HealthCheck> {
  return timeCheck(
    'api.connectivity',
    async () => {
      // Attempt a lightweight HTTP request to the API base
      const controller = new AbortController()
      const timeout = setTimeout(() => controller.abort(), 5000)
      try {
        const response = await fetch(`${apiBaseUrl}/api/health`, {
          method: 'GET',
          signal: controller.signal,
        })
        return { status: response.status, ok: response.ok }
      } finally {
        clearTimeout(timeout)
      }
    },
    (result) => {
      if (result.ok) {
        return { status: 'pass', message: `API reachable (HTTP ${result.status})` }
      }
      return {
        status: 'fail',
        message: `API returned HTTP ${result.status}`,
        metadata: { httpStatus: result.status },
      }
    },
  )
}

async function checkAuthState(): Promise<HealthCheck> {
  return timeCheck(
    'auth.state',
    async () => {
      // Check for auth-related env vars and config files
      const hasApiKey = !!process.env.ANTHROPIC_API_KEY
      const hasOauthToken = !!process.env.CLAUDE_CODE_OAUTH_TOKEN
      const userType = process.env.USER_TYPE
      return { hasApiKey, hasOauthToken, userType }
    },
    (result) => {
      if (result.hasApiKey || result.hasOauthToken) {
        return {
          status: 'pass',
          message: `Auth configured (${result.userType || 'api'} mode)`,
          metadata: {
            authMethod: result.hasApiKey ? 'api_key' : 'oauth',
            userType: result.userType || 'unknown',
          },
        }
      }
      return { status: 'warn', message: 'No API key or OAuth token detected in environment' }
    },
  )
}

async function checkTelemetryPipeline(): Promise<HealthCheck> {
  return timeCheck(
    'telemetry.pipeline',
    async () => {
      const telemetryEnabled = process.env.CLAUDE_CODE_ENABLE_TELEMETRY
      const enhancedBeta = process.env.CLAUDE_CODE_ENHANCED_TELEMETRY_BETA
        ?? process.env.ENABLE_ENHANCED_TELEMETRY_BETA
      const perfetto = process.env.CLAUDE_CODE_PERFETTO_TRACE
      const otlpEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT
      const metricsExporter = process.env.OTEL_METRICS_EXPORTER
      const logsExporter = process.env.OTEL_LOGS_EXPORTER
      const tracesExporter = process.env.OTEL_TRACES_EXPORTER

      return {
        telemetryEnabled: !!telemetryEnabled,
        enhancedBeta: !!enhancedBeta,
        perfetto: !!perfetto,
        otlpConfigured: !!otlpEndpoint,
        metricsExporter,
        logsExporter,
        tracesExporter,
      }
    },
    (result) => {
      const activeSignals: string[] = []
      if (result.metricsExporter) activeSignals.push(`metrics=${result.metricsExporter}`)
      if (result.logsExporter) activeSignals.push(`logs=${result.logsExporter}`)
      if (result.tracesExporter) activeSignals.push(`traces=${result.tracesExporter}`)

      if (result.telemetryEnabled) {
        return {
          status: 'pass',
          message: `Telemetry active: ${activeSignals.join(', ') || 'none configured'}`,
          metadata: result,
        }
      }
      return {
        status: 'warn',
        message: 'Telemetry disabled (CLAUDE_CODE_ENABLE_TELEMETRY not set)',
        metadata: result,
      }
    },
  )
}

async function checkTraceFileWrite(configDir: string): Promise<HealthCheck> {
  return timeCheck(
    'traces.file_write',
    async () => {
      const fs = await import('fs/promises')
      const path = await import('path')
      const tracesDir = path.join(configDir, 'traces')
      const testFile = path.join(tracesDir, `.health-check-${Date.now()}.tmp`)

      try {
        await fs.mkdir(tracesDir, { recursive: true })
        await fs.writeFile(testFile, 'health-check')
        const content = await fs.readFile(testFile, 'utf-8')
        await fs.unlink(testFile)
        return { writable: content === 'health-check' }
      } catch {
        return { writable: false }
      }
    },
    (result) => {
      if (result.writable) {
        return { status: 'pass', message: 'Trace directory writable' }
      }
      return { status: 'fail', message: 'Cannot write to trace directory' }
    },
  )
}

async function checkNodeVersion(): Promise<HealthCheck> {
  return timeCheck(
    'runtime.node_version',
    async () => process.version,
    (version) => {
      const major = parseInt(version.replace('v', '').split('.')[0], 10)
      if (major < 18) {
        return { status: 'fail', message: `Node.js ${version} is below minimum (v18)`, metadata: { version } }
      }
      if (major < 20) {
        return { status: 'warn', message: `Node.js ${version} is below recommended (v20+)`, metadata: { version } }
      }
      return { status: 'pass', message: `Node.js ${version} meets requirements`, metadata: { version } }
    },
  )
}

// ---------- Main health check runner ----------

export interface HealthCheckOptions {
  /** Base URL for the API (default: https://api.anthropic.com) */
  apiBaseUrl?: string
  /** Config home dir (default: ~/.claude) */
  configDir?: string
  /** Skip individual checks by name */
  skip?: string[]
}

export async function runHealthCheck(options: HealthCheckOptions = {}): Promise<HealthReport> {
  const apiBaseUrl = options.apiBaseUrl ?? 'https://api.anthropic.com'
  const configDir = options.configDir ?? `${process.env.HOME}/.claude`
  const skip = new Set(options.skip ?? [])

  const allChecks: Array<() => Promise<HealthCheck>> = [
    () => checkProcessMemory(),
    () => checkEventLoopLag(),
    () => checkDiskSpace(configDir),
    () => checkApiConnectivity(apiBaseUrl),
    () => checkAuthState(),
    () => checkTelemetryPipeline(),
    () => checkTraceFileWrite(configDir),
    () => checkNodeVersion(),
  ]

  // Run all checks in parallel
  const checks = await Promise.all(
    allChecks
      .filter((_, i) => !skip.has(allChecks[i].name))
      .map(fn => fn()),
  )

  // Determine overall status: worst status wins
  let overallStatus: HealthStatus = 'pass'
  for (const check of checks) {
    if (check.status === 'fail') {
      overallStatus = 'fail'
      break
    }
    if (check.status === 'warn' && overallStatus !== 'fail') {
      overallStatus = 'warn'
    }
  }

  const mem = process.memoryUsage()
  const cpu = process.cpuUsage()

  return {
    status: overallStatus,
    timestamp: new Date().toISOString(),
    uptimeSeconds: process.uptime(),
    checks,
    process: {
      pid: process.pid,
      nodeVersion: process.version,
      platform: process.platform,
      arch: process.arch,
      memoryUsage: {
        rssBytes: mem.rss,
        heapTotalBytes: mem.heapTotal,
        heapUsedBytes: mem.heapUsed,
        externalBytes: mem.external,
      },
      cpuUsage: {
        userMicros: cpu.user,
        systemMicros: cpu.system,
      },
    },
  }
}

/**
 * Format a health report as a human-readable summary.
 * Useful for CLI output or agent decision-making.
 */
export function formatHealthReport(report: HealthReport): string {
  const lines: string[] = [
    `Health Status: ${report.status.toUpperCase()}`,
    `Timestamp: ${report.timestamp}`,
    `Uptime: ${report.uptimeSeconds.toFixed(0)}s`,
    `PID: ${report.process.pid}`,
    '',
    'Checks:',
  ]

  for (const check of report.checks) {
    const icon = check.status === 'pass' ? '[PASS]' : check.status === 'warn' ? '[WARN]' : '[FAIL]'
    lines.push(`  ${icon} ${check.name}: ${check.message} (${check.durationMs}ms)`)
  }

  const mem = report.process.memoryUsage
  lines.push('')
  lines.push(`Memory: RSS=${(mem.rssBytes / 1024 / 1024).toFixed(0)}MB, Heap=${(mem.heapUsedBytes / 1024 / 1024).toFixed(0)}MB / ${(mem.heapTotalBytes / 1024 / 1024).toFixed(0)}MB`)

  return lines.join('\n')
}
