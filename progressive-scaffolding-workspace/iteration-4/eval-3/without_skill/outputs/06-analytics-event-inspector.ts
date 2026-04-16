/**
 * Analytics Event Inspector for Open-ClaudeCode Observability
 *
 * Captures, inspects, and validates analytics events flowing through the
 * project's event pipeline:
 *   - Datadog events (datadog.ts: DATADOG_ALLOWED_EVENTS)
 *   - 1P event logging (firstPartyEventLogger.ts)
 *   - OTel events (events.ts: logOTelEvent)
 *
 * Useful for an AI agent to verify events are being emitted correctly,
 * check for schema violations, and ensure no PII is leaking.
 *
 * Usage:
 *   const inspector = createEventInspector()
 *   inspector.capture('tengu_api_success', { model: 1, duration_ms: 340 })
 *   const violations = inspector.validateSchema('tengu_api_success', captured)
 *   const report = inspector.report()
 */

// ---------- Types ----------

export type EventSource = 'datadog' | 'first_party' | 'otel' | 'statsig'

export interface CapturedEvent {
  eventName: string
  source: EventSource
  timestamp: string
  metadata: Record<string, boolean | number | undefined>
  /** Whether the event passed validation */
  valid: boolean
  violations: string[]
}

export interface EventInspectionReport {
  timestamp: string
  totalEvents: number
  validEvents: number
  invalidEvents: number
  eventsByName: Record<string, {
    count: number
    sources: EventSource[]
    violationCount: number
    lastSeen: string
  }>
  piiWarnings: string[]
  schemaViolations: string[]
  unknownEvents: string[]
  missingEvents: string[]
}

// ---------- Known event taxonomy (from datadog.ts DATADOG_ALLOWED_EVENTS) ----------

const KNOWN_EVENTS = new Set([
  'chrome_bridge_connection_succeeded',
  'chrome_bridge_connection_failed',
  'chrome_bridge_disconnected',
  'chrome_bridge_tool_call_completed',
  'chrome_bridge_tool_call_error',
  'chrome_bridge_tool_call_started',
  'chrome_bridge_tool_call_timeout',
  'tengu_api_error',
  'tengu_api_success',
  'tengu_brief_mode_enabled',
  'tengu_brief_mode_toggled',
  'tengu_brief_send',
  'tengu_cancel',
  'tengu_compact_failed',
  'tengu_exit',
  'tengu_flicker',
  'tengu_init',
  'tengu_model_fallback_triggered',
  'tengu_oauth_error',
  'tengu_oauth_success',
  'tengu_oauth_token_refresh_failure',
  'tengu_oauth_token_refresh_success',
  'tengu_oauth_token_refresh_lock_acquiring',
  'tengu_oauth_token_refresh_lock_acquired',
  'tengu_oauth_token_refresh_lock_starting',
  'tengu_oauth_token_refresh_lock_completed',
  'tengu_oauth_token_refresh_lock_releasing',
  'tengu_oauth_token_refresh_lock_released',
  'tengu_query_error',
  'tengu_session_file_read',
  'tengu_started',
  'tengu_tool_use_error',
  'tengu_tool_use_granted_in_prompt_permanent',
  'tengu_tool_use_granted_in_prompt_temporary',
  'tengu_tool_use_rejected_in_prompt',
  'tengu_tool_use_success',
  'tengu_uncaught_exception',
  'tengu_unhandled_rejection',
  'tengu_voice_recording_started',
  'tengu_voice_toggled',
  'tengu_team_mem_sync_pull',
  'tengu_team_mem_sync_push',
  'tengu_team_mem_sync_started',
  'tengu_team_mem_entries_capped',
  // Additional OTel and 1P events not in Datadog allowlist
  'tengu_plugin_enabled_for_session',
  'tengu_plugin_load_failed',
  'tengu_skill_loaded',
])

// ---------- PII patterns to detect in metadata values ----------

const PII_PATTERNS: Array<{ pattern: RegExp; label: string }> = [
  { pattern: /-----BEGIN (?:RSA |EC )?PRIVATE KEY-----/, label: 'private_key_detected' },
  { pattern: /sk-[a-zA-Z0-9]{20,}/, label: 'api_key_pattern_detected' },
  { pattern: /(?:password|passwd|secret|token)\s*[:=]\s*\S+/i, label: 'credential_pattern_detected' },
  { pattern: /\/Users\/[^/]+\/\.ssh\//, label: 'ssh_path_detected' },
  { pattern: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/, label: 'email_pattern_detected' },
]

// ---------- Expected events that should fire during a normal session ----------

const EXPECTED_SESSION_EVENTS = [
  'tengu_started',
  'tengu_init',
]

// ---------- Inspector ----------

const MAX_CAPTURED_EVENTS = 5000

export function createEventInspector() {
  const captured: CapturedEvent[] = []
  const piiWarnings: string[] = []

  function capture(
    eventName: string,
    metadata: Record<string, boolean | number | undefined>,
    source: EventSource = 'datadog',
  ): CapturedEvent {
    const violations: string[] = []

    // Check for unknown event names
    if (!KNOWN_EVENTS.has(eventName)) {
      violations.push(`unknown_event_name:${eventName}`)
    }

    // Check for string values in metadata (the project intentionally avoids strings)
    for (const [key, value] of Object.entries(metadata)) {
      if (typeof value === 'string') {
        violations.push(`string_metadata_value:${key}`)

        // Check for PII patterns in string values
        for (const { pattern, label } of PII_PATTERNS) {
          if (pattern.test(value)) {
            violations.push(`pii:${label}:${key}`)
            piiWarnings.push(`${eventName}.${key} contains ${label}`)
          }
        }
      }
    }

    // Check for _PROTO_ keys that should only be in 1P sink
    for (const key of Object.keys(metadata)) {
      if (key.startsWith('_PROTO_') && source !== 'first_party') {
        violations.push(`proto_key_in_non_1p_sink:${key}`)
      }
    }

    const event: CapturedEvent = {
      eventName,
      source,
      timestamp: new Date().toISOString(),
      metadata,
      valid: violations.length === 0,
      violations,
    }

    // Bounded capture (evict oldest half, matching project patterns)
    if (captured.length >= MAX_CAPTURED_EVENTS) {
      captured.splice(0, MAX_CAPTURED_EVENTS / 2)
    }
    captured.push(event)

    return event
  }

  function report(): EventInspectionReport {
    const eventsByName: EventInspectionReport['eventsByName'] = {}
    let invalidCount = 0
    const schemaViolations: string[] = []
    const unknownEvents: string[] = []

    for (const event of captured) {
      if (!eventsByName[event.eventName]) {
        eventsByName[event.eventName] = {
          count: 0,
          sources: [],
          violationCount: 0,
          lastSeen: event.timestamp,
        }
      }
      const entry = eventsByName[event.eventName]
      entry.count++
      entry.lastSeen = event.timestamp
      if (!entry.sources.includes(event.source)) {
        entry.sources.push(event.source)
      }

      if (!event.valid) {
        invalidCount++
        entry.violationCount++
        for (const v of event.violations) {
          if (!schemaViolations.includes(v)) {
            schemaViolations.push(v)
          }
          if (v.startsWith('unknown_event_name:')) {
            const name = v.replace('unknown_event_name:', '')
            if (!unknownEvents.includes(name)) {
              unknownEvents.push(name)
            }
          }
        }
      }
    }

    // Check for expected events that haven't been seen
    const seenEventNames = new Set(captured.map(e => e.eventName))
    const missingEvents = EXPECTED_SESSION_EVENTS.filter(e => !seenEventNames.has(e))

    return {
      timestamp: new Date().toISOString(),
      totalEvents: captured.length,
      validEvents: captured.length - invalidCount,
      invalidEvents: invalidCount,
      eventsByName,
      piiWarnings: [...piiWarnings],
      schemaViolations,
      unknownEvents,
      missingEvents,
    }
  }

  /** Get all captured events for a specific event name. */
  function getEvents(eventName: string): CapturedEvent[] {
    return captured.filter(e => e.eventName === eventName)
  }

  /** Get events that failed validation. */
  function getInvalidEvents(): CapturedEvent[] {
    return captured.filter(e => !e.valid)
  }

  /** Reset all captured events. */
  function reset(): void {
    captured.length = 0
    piiWarnings.length = 0
  }

  return {
    capture,
    report,
    getEvents,
    getInvalidEvents,
    reset,
  }
}
