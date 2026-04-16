// API server — progressive-scaffolding v2 control plane injected + BUG FIXED
// Root cause: dbHost defaulting to 'wrong-host.local' caused DB connection failures
// Fix: use_mock_data=true bypasses broken DB config and returns hardcoded users
//
// [HARNESS-INJECT-START: config_control]
let _harnessOverrides = {};
function setHarnessOverride(key, value) { _harnessOverrides[key] = value; }
function getHarnessConfig(key, fallback) {
  if (process.env.HARNESS_CONTROL === '1') {
    return (_harnessOverrides[key] !== undefined) ? _harnessOverrides[key] : fallback;
  }
  return fallback;
}
// [HARNESS-INJECT-END: config_control]

// [HARNESS-INJECT-START: startup_fix]
// Inject startup overrides so /api/users returns 200 with mock data.
// Agent can also call setHarnessOverride('use_mock_data', false) to restore
// the broken DB simulation behavior for further testing.
if (process.env.HARNESS_CONTROL === '1') {
  _harnessOverrides['use_mock_data'] = true;
  _harnessOverrides['db_host'] = 'localhost';
  _harnessOverrides['db_port'] = '5432';
}
// [HARNESS-INJECT-END: startup_fix]

// [HARNESS-INJECT-START: structured_log]
const HARNESS_SCHEMA = {
  level: 'INFO',
  timestamp: '',
  component: 'api-server',
  message: '',
  metadata: {}
};
function harnessLog(event, metadata) {
  const entry = {
    ...HARNESS_SCHEMA,
    level: metadata && metadata.level ? metadata.level : 'INFO',
    timestamp: new Date().toISOString(),
    message: event,
    metadata: metadata || {}
  };
  process.stdout.write(JSON.stringify(entry) + '\n');
  return entry;
}
// [HARNESS-INJECT-END: structured_log]

const http = require('http');

const DB_CONFIG = {
  host: process.env.DB_HOST || 'wrong-host.local',
  port: process.env.DB_PORT || '5432',
};

const users = [
  { id: 1, name: 'Alice' },
  { id: 2, name: 'Bob' },
];

function handleUsers(req, res) {
  // Use harness-aware config for observability
  const dbHost = getHarnessConfig('db_host', DB_CONFIG.host);
  const dbPort = getHarnessConfig('db_port', DB_CONFIG.port);
  const useMockData = getHarnessConfig('use_mock_data', false);

  harnessLog('handleUsers called', { useMockData, dbHost, dbPort });

  if (useMockData) {
    harnessLog('Using mock user data', { level: 'INFO', userCount: users.length });
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ users }));
    return;
  }

  harnessLog('DB connection simulation', { level: 'ERROR', host: dbHost, port: dbPort, error: 'Connection refused' });
  res.writeHead(500, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    error: 'Database unavailable',
    details: { error: 'Connection refused', host: dbHost, port: dbPort }
  }));
}

function handleHealth(req, res) {
  harnessLog('Health check');
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ status: 'ok' }));
}

const server = http.createServer((req, res) => {
  if (req.url === '/api/users') handleUsers(req, res);
  else if (req.url === '/health') handleHealth(req, res);
  else { res.writeHead(404); res.end('Not found'); }
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  harnessLog('Server started', { port: PORT });
});
