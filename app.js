const express = require('express');
const prometheus = require('prom-client');

const app = express();
const port = process.env.PORT || 8080;
const env = process.env.NODE_ENV || 'development';

// Prometheus metrics
const register = new prometheus.Registry();
prometheus.collectDefaultMetrics({ register });

const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.001, 0.01, 0.1, 0.5, 1, 2.5, 5],
  registers: [register],
});

const httpRequestTotal = new prometheus.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

const httpErrorsTotal = new prometheus.Counter({
  name: 'http_errors_total',
  help: 'Total number of HTTP errors',
  labelNames: ['method', 'route', 'error_type'],
  registers: [register],
});

const traceCount = new prometheus.Counter({
  name: 'trace_generation_total',
  help: 'Total traces generated',
  registers: [register],
});

// Latency percentile tracking
let requestLatencies = [];
setInterval(() => {
  if (requestLatencies.length > 0) {
    requestLatencies.sort((a, b) => a - b);
    const p50 = requestLatencies[Math.floor(requestLatencies.length * 0.5)];
    const p95 = requestLatencies[Math.floor(requestLatencies.length * 0.95)];
    const p99 = requestLatencies[Math.floor(requestLatencies.length * 0.99)];
    console.log(`Latencies - P50: ${p50}ms, P95: ${p95}ms, P99: ${p99}ms`);
    requestLatencies = [];
  }
}, 60000);

// Middleware: request metrics and tracing headers
app.use((req, res, next) => {
  const startTime = Date.now();
  
  // Generate trace ID if not present
  const traceId = req.headers['x-trace-id'] || generateTraceId();
  const spanId = generateSpanId();
  
  // Add trace headers to response
  res.setHeader('X-Trace-ID', traceId);
  res.setHeader('X-Span-ID', spanId);

  res.on('finish', () => {
    const duration = (Date.now() - startTime) / 1000;
    const durationMs = Date.now() - startTime;

    // Track latencies for percentiles
    requestLatencies.push(durationMs);

    // Record metrics
    httpRequestDuration.observe(
      { method: req.method, route: req.path, status_code: res.statusCode },
      duration
    );

    httpRequestTotal.inc({
      method: req.method,
      route: req.path,
      status_code: res.statusCode,
    });

    // Record errors
    if (res.statusCode >= 400) {
      httpErrorsTotal.inc({
        method: req.method,
        route: req.path,
        error_type: res.statusCode >= 500 ? '5xx' : '4xx',
      });
    }

    console.log(`[${traceId}] ${req.method} ${req.path} - ${res.statusCode} (${durationMs}ms)`);
  });

  next();
});

function generateTraceId() {
  return 'trace-' + Math.random().toString(36).substr(2, 9) + '-' + Date.now();
}

function generateSpanId() {
  return 'span-' + Math.random().toString(36).substr(2, 9);
}

app.get('/', (req, res) => {
  const message = 'It works!';
  const version = 'NodeJS ' + process.versions.node;
  const environment = 'Environment: ' + env;
  const response = [message, version, environment].join('\n');
  res.type('text/plain').send(response);
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Health endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString(), service: 'everlasting-fairytale' });
});

// Ready endpoint
app.get('/ready', (req, res) => {
  res.json({ status: 'ready', service: 'everlasting-fairytale' });
});

// Trace generation endpoint for testing
app.get('/trace-test', (req, res) => {
  traceCount.inc();
  const traceId = generateTraceId();

  res.json({
    message: 'Trace test generated',
    timestamp: new Date().toISOString(),
    trace_id: traceId,
    span_id: generateSpanId()
  });
});

app.listen(port, () => {
  console.log(`\n========================================`);
  console.log(`Server listening on port ${port} in ${env} mode`);
  console.log(`Service: everlasting-fairytale`);
  console.log(`========================================\n`);
  console.log(`Endpoints:`);
  console.log(`  Root:       http://localhost:${port}/`);
  console.log(`  Metrics:    http://localhost:${port}/metrics`);
  console.log(`  Health:     http://localhost:${port}/health`);
  console.log(`  Ready:      http://localhost:${port}/ready`);
  console.log(`  Trace Test: http://localhost:${port}/trace-test\n`);
  console.log(`External Services:`);
  console.log(`  Jaeger UI:  http://localhost:16686`);
  console.log(`  Tempo API:  http://localhost:3200`);
  console.log(`========================================\n`);
});
