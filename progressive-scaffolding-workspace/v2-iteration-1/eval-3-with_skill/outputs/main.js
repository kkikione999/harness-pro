// Broken API server for eval 3
// BUG: DB host is misconfigured — should use env or harness override
const http = require('http');

// [HARNESS-INJECT-START: config_control]
let _harnessOverrides = {};
function setHarnessOverride(key, value) { _harnessOverrides[key] = value; }
function getHarnessConfig(key, fallback) {
  if (process.env.HARNESS_CONTROL === '1') {
    return _harnessOverrides[key] !== undefined ? _harnessOverrides[key] : fallback;
  }
  return fallback;
}
// [HARNESS-INJECT-END: config_control]

// [HARNESS-INJECT-START: observability]
function harnessLog(event, metadata) {
  const entry = {
    level: 'INFO',
    timestamp: new Date().toISOString(),
    correlationId: process.env.HARNESS_CORRELATION_ID || '',
    component: 'harness',
    message: event,
    metadata: metadata || {}
  };
  process.stdout.write(JSON.stringify(entry) + '\n');
  return entry;
}
// [HARNESS-INJECT-END: observability]

// [HARNESS-INJECT-START: feature_flag]
let _featureFlags = {};
function setFeatureFlag(key, value) { _featureFlags[key] = value; }
function isFeatureEnabled(key) {
  if (process.env.HARNESS_CONTROL !== '1') return false;
  return _featureFlags[key] === true;
}
// [HARNESS-INJECT-END: feature_flag]

// [HARNESS-INJECT-START: state_injection]
let _injectedState = {};
function injectState(path, value) {
  _injectedState[path] = value;
  harnessLog('state_injected', { path, value });
}
function queryState(path) {
  return _injectedState[path];
}
function getAllState() {
  return { ..._injectedState };
}
// [HARNESS-INJECT-END: state_injection]

// Export harness API when HARNESS_CONTROL=1
if (process.env.HARNESS_CONTROL === '1') {
  module.exports = {
    setHarnessOverride,
    getHarnessConfig,
    setFeatureFlag,
    isFeatureEnabled,
    injectState,
    queryState,
    getAllState,
    harnessLog
  };
}

function getDbConfig() {
  return {
    host: getHarnessConfig('DB_HOST', process.env.DB_HOST || 'wrong-host.local'),
    port: getHarnessConfig('DB_PORT', process.env.DB_PORT || '5432'),
  };
}

const users = [
  { id: 1, name: 'Alice' },
  { id: 2, name: 'Bob' },
];

function handleUsers(req, res) {
  const DB_CONFIG = getDbConfig();
  harnessLog('db_connect_attempt', { host: DB_CONFIG.host, port: DB_CONFIG.port });
  // Fail for non-localhost hosts (simulating DB connection failure)
  const validHosts = ['localhost', '127.0.0.1', '::1'];
  if (!validHosts.includes(DB_CONFIG.host)) {
    const error = { error: 'Connection refused', host: DB_CONFIG.host };
    harnessLog('db_connection_failed', { host: DB_CONFIG.host, port: DB_CONFIG.port, error: error.error });
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Database unavailable', details: error }));
    return;
  }
  harnessLog('db_connection_success', { host: DB_CONFIG.host, port: DB_CONFIG.port });
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ users }));
}

function handleHealth(req, res) {
  console.log(JSON.stringify({
    level: 'INFO',
    timestamp: new Date().toISOString(),
    component: 'api',
    message: 'Health check',
    metadata: { status: 'ok' }
  }));
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ status: 'ok' }));
}

const server = http.createServer((req, res) => {
  // Harness control endpoint
  if (req.url.startsWith('/harness/')) {
    harnessLog('harness_request', { url: req.url, method: req.method });
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const parsed = body ? JSON.parse(body) : {};
        const action = req.url.slice('/harness/'.length);
        if (action === 'exec') {
          const { fn, args } = parsed;
          const argsArr = Array.isArray(args) ? args : (args !== undefined ? [args] : []);
          const fnMap = {
            setHarnessOverride,
            getHarnessConfig,
            setFeatureFlag,
            isFeatureEnabled,
            injectState,
            queryState,
            getAllState,
            harnessLog
          };
          if (fnMap[fn]) {
            const result = fnMap[fn].apply(null, argsArr);
            harnessLog('harness_exec', { fn, args: argsArr.map(String).map(s => s.slice(0, 100)) });
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: true, result: result !== undefined ? result : null }));
          } else {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Unknown function: ' + fn }));
          }
        } else if (action === 'state') {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ state: getAllState(), overrides: _harnessOverrides }));
        } else {
          res.writeHead(404);
          res.end('Not found');
        }
      } catch (e) {
        harnessLog('harness_error', { error: e.message });
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }
  if (req.url === '/api/users') {
    handleUsers(req, res);
  } else if (req.url === '/health') {
    handleHealth(req, res);
  } else {
    res.writeHead(404);
    res.end('Not found');
  }
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(JSON.stringify({
    level: 'INFO',
    timestamp: new Date().toISOString(),
    component: 'api',
    message: `Server started`,
    metadata: { port: PORT }
  }));
});
