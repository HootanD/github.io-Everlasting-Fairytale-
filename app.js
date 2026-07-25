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

// Middleware: request metrics
app.use((req, res, next) => {
  const startTime = Date.now();
  
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
  });

  next();
});

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
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Ready endpoint
app.get('/ready', (req, res) => {
  res.json({ status: 'ready' });
});

app.listen(port, () => {
  console.log(`Server listening on port ${port} in ${env} mode`);
  console.log(`Metrics: http://localhost:${port}/metrics`);
});
