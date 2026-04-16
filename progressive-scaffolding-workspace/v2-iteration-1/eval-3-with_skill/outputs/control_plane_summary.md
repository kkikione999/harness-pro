# Control Plane Summary

## Capabilities Added

### Config Control (C1)
- `setHarnessOverride(key, value)` - Override any config at runtime
- `getHarnessConfig(key, fallback)` - Get config with harness override support
- Activation: Only when `HARNESS_CONTROL=1` is set

### Observability (O1)
- `harnessLog(event, metadata)` - Emit structured JSON logs
- Schema: `{level, timestamp, correlationId, component, message, metadata}`
- All DB operations emit events

### Feature Flags (C2)
- `setFeatureFlag(key, value)` - Toggle features at runtime
- `isFeatureEnabled(key)` - Check feature flag status

### State Injection (C3)
- `injectState(path, value)` - Inject test state
- `queryState(path)` - Query injected state
- `getAllState()` - Get all injected state

### HTTP Control Endpoint
- `POST /harness/exec` - Execute any harness function via HTTP
- `GET /harness/state` - Query current state

## Usage Examples

```bash
# Override DB_HOST via HTTP endpoint
curl -X POST http://localhost:3000/harness/exec \
  -H "Content-Type: application/json" \
  -d '{"fn": "setHarnessOverride", "args": ["DB_HOST", "localhost"]}'

# Or use the Node.js API directly
node -e "
const harness = require('./src/main.js');
harness.setHarnessOverride('DB_HOST', 'localhost');
"

# Query current state
curl http://localhost:3000/harness/state
```

## Intrusion Delta

- Total harness code: ~80 lines
- Tier achieved: Tier 5 (Full Control Plane)
- Zero new files required
- All injections marked with `[HARNESS-INJECT-START:*]` / `[HARNESS-INJECT-END:*]`
