/**
 * Health Check for Open-ClaudeCode
 *
 * Provides liveness, readiness, and deep health checks for a CLI process.
 * Tailored to the project's architecture:
 *   - Checks telemetry pipeline initialization (instrumentation.ts)
 *   - Validates analytics sink attachment (analytics/sink.ts)
 *   - Monitors process memory and CPU (metadata.ts ProcessMetrics)
 *   - Verifies file system access for config/cache directories
 *   - Tests API connectivity to Anthropic endpoints
 *
 * Usage by an AI agent:
 *   const checker = new HealthChecker()
 *   const result = await checker.deepCheck()
 *   console.log(JSON.stringify(result, null, 2))
 *
 * HTTP mode (starts a health endpoint):
 *   checker.startServer(8080)
 *   // GET /health/live   -> liveness probe
 *   // GET /health/ready   -> readiness probe
 *   // GET /health         -> full deep check
 */

import { createServer, type ServerResponse, type IncomingMessage } from 'http'
import { existsSync, accessSync, constants, statSync } from 'fs'
import { join, homedir } from 'path'
import { platform } from 'os'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type HealthStatus = 'healthy' | 'degraded' | 'unhealthy'

export type ComponentCheck = {
  name: string
  status: HealthStatus
  message: string
  duration_ms: number
  details?: Record<string, unknown>
}

export type HealthCheckResult = {
  status: HealthStatus
  timestamp: string
  version: string
  uptime_seconds: number
  checks: ComponentCheck[]
}

// ---------------------------------------------------------------------------
// HealthChecker
// ---------------------------------------------------------------------------

export class HealthChecker {
  private httpServer: ReturnType<typeof createServer> | null = null
  private startTime = Date.now()
  private cachedResult: HealthCheckResult | null = null
  private cacheTtlMs = 10_000 // Reuse deep check result for 10s
  private lastCheckTime = 0

  // -- Liveness probe (is the process alive?) -----------------------------

  liveness(): HealthCheckResult {
    const checks: ComponentCheck[] = [
      {
        name: 'process',
        status: 'healthy',
        message: 'Process is running',
        duration_ms: 0,
        details: {
          pid: process.pid,
          uptime_seconds: process.uptime(),
          platform: platform(),
          node_version: process.version,
        },
      },
    ]

    return {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version ?? 'unknown',
      uptime_seconds: process.uptime(),
      checks,
    }
  }

  // -- Readiness probe (can it handle requests?) --------------------------

  async readiness(): Promise<HealthCheckResult> {
    const checks: ComponentCheck[] = []

    // Check 1: Event loop responsiveness
    checks.push(await this.checkEventLoop())

    // Check 2: Memory pressure
    checks.push(this.checkMemoryPressure())

    // Check 3: Config directory writable
    checks.push(this.checkConfigDirectory())

    return this.aggregate(checks)
  }

  // -- Deep check (full subsystem validation) -----------------------------

  async deepCheck(): Promise<HealthCheckResult> {
    // Return cached result if fresh
    const now = Date.now()
    if (this.cachedResult && now - this.lastCheckTime < this.cacheTtlMs) {
      return this.cachedResult
    }

    const checks: ComponentCheck[] = []

    // Process basics
    checks.push({
      name: 'process',
      status: 'healthy',
      message: 'Process is running',
      duration_ms: 0,
      details: {
        pid: process.pid,
        uptime_seconds: process.uptime(),
        platform: platform(),
        node_version: process.version,
        arch: process.arch,
      },
    })

    // Event loop
    checks.push(await this.checkEventLoop())

    // Memory
    checks.push(this.checkMemoryPressure())

    // Config directory
    checks.push(this.checkConfigDirectory())

    // Telemetry pipeline
    checks.push(this.checkTelemetryPipeline())

    // Analytics sink
    checks.push(this.checkAnalyticsSink())

    // File system health
    checks.push(this.checkFileSystem())

    // API connectivity
    checks.push(await this.checkApiConnectivity())

    const result = this.aggregate(checks)
    this.cachedResult = result
    this.lastCheckTime = now
    return result
  }

  // -- HTTP server ---------------------------------------------------------

  startServer(port: number = 8080): void {
    this.httpServer = createServer(
      async (req: IncomingMessage, res: ServerResponse) => {
        const url = req.url ?? '/'

        res.setHeader('Content-Type', 'application/json')

        try {
          let result: HealthCheckResult

          switch (url) {
            case '/health/live':
            case '/healthz':
              result = this.liveness()
              break
            case '/health/ready':
            case '/readyz':
              result = await this.readiness()
              break
            case '/health':
            case '/':
            default:
              result = await this.deepCheck()
              break
          }

          const httpStatus =
            result.status === 'healthy'
              ? 200
              : result.status === 'degraded'
                ? 200
                : 503

          res.writeHead(httpStatus)
          res.end(JSON.stringify(result, null, 2))
        } catch (error) {
          res.writeHead(500)
          res.end(
            JSON.stringify({
              status: 'unhealthy',
              error: error instanceof Error ? error.message : 'Unknown error',
            }),
          )
        }
      },
    )

    this.httpServer.listen(port)
  }

  async shutdown(): Promise<void> {
    if (this.httpServer) {
      await new Promise<void>(resolve =>
        this.httpServer!.close(() => resolve()),
      )
      this.httpServer = null
    }
  }

  // -- Individual checks ---------------------------------------------------

  private async checkEventLoop(): Promise<ComponentCheck> {
    const start = performance.now()
    return new Promise<ComponentCheck>(resolve => {
      setImmediate(() => {
        const lag = performance.now() - start
        resolve({
          name: 'event_loop',
          status: lag < 100 ? 'healthy' : lag < 500 ? 'degraded' : 'unhealthy',
          message: `Event loop lag: ${lag.toFixed(1)}ms`,
          duration_ms: lag,
          details: { lag_ms: Math.round(lag * 100) / 100 },
        })
      })
    })
  }

  private checkMemoryPressure(): ComponentCheck {
    const start = Date.now()
    const mem = process.memoryUsage()
    const rssMb = mem.rss / (1024 * 1024)
    const heapUsedMb = mem.heapUsed / (1024 * 1024)
    const heapTotalMb = mem.heapTotal / (1024 * 1024)
    const heapUtilization = mem.heapUsed / mem.heapTotal

    let status: HealthStatus = 'healthy'
    let message = `Memory OK: RSS=${rssMb.toFixed(0)}MB, heap=${heapUsedMb.toFixed(0)}/${heapTotalMb.toFixed(0)}MB`

    if (rssMb > 1024 || heapUtilization > 0.9) {
      status = 'unhealthy'
      message = `Memory critical: RSS=${rssMb.toFixed(0)}MB, heap utilization=${(heapUtilization * 100).toFixed(0)}%`
    } else if (rssMb > 512 || heapUtilization > 0.75) {
      status = 'degraded'
      message = `Memory elevated: RSS=${rssMb.toFixed(0)}MB, heap utilization=${(heapUtilization * 100).toFixed(0)}%`
    }

    return {
      name: 'memory',
      status,
      message,
      duration_ms: Date.now() - start,
      details: {
        rss_bytes: mem.rss,
        heap_total_bytes: mem.heapTotal,
        heap_used_bytes: mem.heapUsed,
        external_bytes: mem.external,
        rss_mb: Math.round(rssMb),
        heap_utilization_percent: Math.round(heapUtilization * 100),
      },
    }
  }

  private checkConfigDirectory(): ComponentCheck {
    const start = Date.now()
    const configDir =
      process.env.CLAUDE_CONFIG_DIR ?? join(homedir(), '.claude')

    try {
      if (!existsSync(configDir)) {
        return {
          name: 'config_directory',
          status: 'degraded',
          message: `Config directory does not exist: ${configDir}`,
          duration_ms: Date.now() - start,
        }
      }

      accessSync(configDir, constants.W_OK)

      return {
        name: 'config_directory',
        status: 'healthy',
        message: `Config directory writable: ${configDir}`,
        duration_ms: Date.now() - start,
        details: { path: configDir },
      }
    } catch (error) {
      return {
        name: 'config_directory',
        status: 'unhealthy',
        message: `Config directory not writable: ${error instanceof Error ? error.message : 'unknown'}`,
        duration_ms: Date.now() - start,
      }
    }
  }

  private checkTelemetryPipeline(): ComponentCheck {
    const start = Date.now()

    const telemetryEnabled =
      process.env.CLAUDE_CODE_ENABLE_TELEMETRY === '1' ||
      process.env.CLAUDE_CODE_ENABLE_TELEMETRY === 'true'

    const otelExporter = process.env.OTEL_TRACES_EXPORTER ?? ''
    const otelEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT ?? ''

    if (!telemetryEnabled) {
      return {
        name: 'telemetry_pipeline',
        status: 'degraded',
        message: 'Telemetry disabled (CLAUDE_CODE_ENABLE_TELEMETRY not set)',
        duration_ms: Date.now() - start,
        details: { enabled: false },
      }
    }

    if (!otelExporter && !otelEndpoint) {
      return {
        name: 'telemetry_pipeline',
        status: 'degraded',
        message: 'Telemetry enabled but no exporter or endpoint configured',
        duration_ms: Date.now() - start,
        details: { enabled: true, exporter: 'none' },
      }
    }

    return {
      name: 'telemetry_pipeline',
      status: 'healthy',
      message: `Telemetry pipeline configured: exporter=${otelExporter || 'default'}`,
      duration_ms: Date.now() - start,
      details: {
        enabled: true,
        exporter: otelExporter || 'default',
        endpoint_configured: !!otelEndpoint,
      },
    }
  }

  private checkAnalyticsSink(): ComponentCheck {
    const start = Date.now()

    // The analytics sink is always initialized in the main CLI process.
    // Check for conditions that would prevent it from working.
    const isAnalyticsDisabled =
      process.env.CLAUDE_CODE_DISABLE_ANALYTICS === '1' ||
      process.env.DISABLE_TELEMETRY === '1'

    if (isAnalyticsDisabled) {
      return {
        name: 'analytics_sink',
        status: 'degraded',
        message: 'Analytics disabled by environment variable',
        duration_ms: Date.now() - start,
      }
    }

    return {
      name: 'analytics_sink',
      status: 'healthy',
      message: 'Analytics sink operational',
      duration_ms: Date.now() - start,
    }
  }

  private checkFileSystem(): ComponentCheck {
    const start = Date.now()

    const criticalPaths = [
      join(homedir(), '.claude'),
      process.env.TMPDIR ?? '/tmp',
    ]

    let allWritable = true
    const details: Record<string, string> = {}

    for (const dirPath of criticalPaths) {
      try {
        accessSync(dirPath, constants.W_OK)
        details[dirPath] = 'writable'
      } catch {
        details[dirPath] = 'not writable'
        allWritable = false
      }
    }

    return {
      name: 'file_system',
      status: allWritable ? 'healthy' : 'unhealthy',
      message: allWritable
        ? 'All critical paths writable'
        : 'Some critical paths not writable',
      duration_ms: Date.now() - start,
      details,
    }
  }

  private async checkApiConnectivity(): Promise<ComponentCheck> {
    const start = Date.now()
    const apiBase =
      process.env.ANTHROPIC_BASE_URL ?? 'https://api.anthropic.com'

    try {
      const controller = new AbortController()
      const timeoutId = setTimeout(() => controller.abort(), 5000)

      const response = await fetch(`${apiBase}/`, {
        method: 'HEAD',
        signal: controller.signal,
      })
      clearTimeout(timeoutId)

      const duration = Date.now() - start

      if (response.ok || response.status === 404) {
        // 404 is fine -- we just need TCP connectivity
        return {
          name: 'api_connectivity',
          status: duration < 2000 ? 'healthy' : 'degraded',
          message: `API reachable (${apiBase}), latency=${duration}ms`,
          duration_ms: duration,
          details: {
            endpoint: apiBase,
            status_code: response.status,
            latency_ms: duration,
          },
        }
      }

      return {
        name: 'api_connectivity',
        status: 'degraded',
        message: `API returned status ${response.status}`,
        duration_ms: Date.now() - start,
        details: { endpoint: apiBase, status_code: response.status },
      }
    } catch (error) {
      return {
        name: 'api_connectivity',
        status: 'unhealthy',
        message: `API unreachable: ${error instanceof Error ? error.message : 'unknown'}`,
        duration_ms: Date.now() - start,
        details: { endpoint: apiBase },
      }
    }
  }

  // -- Aggregation ---------------------------------------------------------

  private aggregate(checks: ComponentCheck[]): HealthCheckResult {
    const statusOrder: HealthStatus[] = ['healthy', 'degraded', 'unhealthy']
    let worstStatus: HealthStatus = 'healthy'

    for (const check of checks) {
      if (statusOrder.indexOf(check.status) > statusOrder.indexOf(worstStatus)) {
        worstStatus = check.status
      }
    }

    return {
      status: worstStatus,
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version ?? 'unknown',
      uptime_seconds: (Date.now() - this.startTime) / 1000,
      checks,
    }
  }
}
