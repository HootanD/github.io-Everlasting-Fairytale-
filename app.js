// Initialize OpenTelemetry tracing first, before other imports
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { trace } = require('@opentelemetry/api');

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'everlasting-fairytale',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'production',
  }),
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://tempo:4318',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
console.log('✓ OpenTelemetry Tracing initialized');

process.on('SIGTERM', () => {
  sdk
    .shutdown()
    .then(() => console.log('SDK shut down successfully'))
    .catch((err) => console.log('Error shutting down SDK', err))
    .finally(() => process.exit(0));
});

// Application code
const express = require('express');
const prometheus = require('prom-client');

const tracer = trace.getTracer('everlasting-fairytale', '1.0.0');

const app = express();
const port = process.env.PORT || 8080;
const env = process.env.NODE_ENV || 'development';

// Middleware: parse JSON
app.use(express.json());

// Prometheus metrics
const register = new prometheus.Registry();
prometheus.collectDefaultMetrics({ register });

// ==================== INFRASTRUCTURE METRICS ====================

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

// ==================== CUSTOM BUSINESS METRICS ====================

// User engagement metrics
const userActivityCounter = new prometheus.Counter({
  name: 'user_activity_total',
  help: 'Total user activity events',
  labelNames: ['event_type', 'status'],
  registers: [register],
});

const userSessionDuration = new prometheus.Histogram({
  name: 'user_session_duration_seconds',
  help: 'User session duration in seconds',
  buckets: [60, 300, 600, 1800, 3600, 7200],
  registers: [register],
});

const activeUsers = new prometheus.Gauge({
  name: 'active_users_gauge',
  help: 'Number of currently active users',
  registers: [register],
});

// Business operation metrics
const operationLatency = new prometheus.Histogram({
  name: 'business_operation_duration_seconds',
  help: 'Duration of business operations',
  labelNames: ['operation', 'result'],
  buckets: [0.1, 0.5, 1, 2, 5, 10],
  registers: [register],
});

const operationCounter = new prometheus.Counter({
  name: 'business_operations_total',
  help: 'Total business operations executed',
  labelNames: ['operation', 'result'],
  registers: [register],
});

// Data processing metrics
const dataProcessed = new prometheus.Counter({
  name: 'data_processed_bytes_total',
  help: 'Total bytes of data processed',
  labelNames: ['type'],
  registers: [register],
});

const processingQueueSize = new prometheus.Gauge({
  name: 'processing_queue_size',
  help: 'Current size of processing queue',
  registers: [register],
});

// SLA and performance metrics
const slaCompliance = new prometheus.Gauge({
  name: 'sla_compliance_percentage',
  help: 'SLA compliance percentage (0-100)',
  labelNames: ['service_level'],
  registers: [register],
});

const responseTimePercentile = new prometheus.Gauge({
  name: 'response_time_percentile_ms',
  help: 'Response time percentiles in milliseconds',
  labelNames: ['percentile'],
  registers: [register],
});

// Error categorization
const detailedErrors = new prometheus.Counter({
  name: 'detailed_errors_total',
  help: 'Errors categorized by type',
  labelNames: ['error_category', 'error_code'],
  registers: [register],
});

const errorRate = new prometheus.Gauge({
  name: 'error_rate_percentage',
  help: 'Error rate as percentage',
  registers: [register],
});

// Latency percentile tracking
let requestLatencies = [];
let operationQueue = [];
let totalRequests = 0;
let totalErrors = 0;

setInterval(() => {
  if (requestLatencies.length > 0) {
    requestLatencies.sort((a, b) => a - b);
    const p50 = requestLatencies[Math.floor(requestLatencies.length * 0.5)];
    const p95 = requestLatencies[Math.floor(requestLatencies.length * 0.95)];
    const p99 = requestLatencies[Math.floor(requestLatencies.length * 0.99)];
    
    responseTimePercentile.set({ percentile: 'p50' }, p50);
    responseTimePercentile.set({ percentile: 'p95' }, p95);
    responseTimePercentile.set({ percentile: 'p99' }, p99);
    
    console.log(`Latencies - P50: ${p50}ms, P95: ${p95}ms, P99: ${p99}ms`);
    requestLatencies = [];
  }
  
  // Update active users (simulate 5-50 users)
  activeUsers.set(Math.floor(Math.random() * 45) + 5);
  
  // Update SLA compliance
  slaCompliance.set({ service_level: 'standard' }, 99.2);
  slaCompliance.set({ service_level: 'premium' }, 99.8);
  
  // Update queue size
  processingQueueSize.set(operationQueue.length);
  
  // Calculate error rate
  if (totalRequests > 0) {
    errorRate.set((totalErrors / totalRequests) * 100);
  }
}, 60000);

// Middleware: request metrics and tracing
app.use((req, res, next) => {
  const span = tracer.startSpan(`${req.method} ${req.path}`);
  const startTime = Date.now();
  
  // Generate trace ID if not present
  const traceId = req.headers['x-trace-id'] || generateTraceId();
  const spanId = generateSpanId();
  
  // Add trace IDs to span
  span.setAttributes({
    'http.method': req.method,
    'http.url': req.url,
    'http.target': req.path,
    'trace.id': traceId,
    'span.id': spanId,
  });
  
  // Add trace headers to response
  res.setHeader('X-Trace-ID', traceId);
  res.setHeader('X-Span-ID', spanId);

  res.on('finish', () => {
    const duration = (Date.now() - startTime) / 1000;
    const durationMs = Date.now() - startTime;

    // Track latencies for percentiles
    requestLatencies.push(durationMs);
    totalRequests++;

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
      totalErrors++;
      httpErrorsTotal.inc({
        method: req.method,
        route: req.path,
        error_type: res.statusCode >= 500 ? '5xx' : '4xx',
      });
      
      detailedErrors.inc({
        error_category: res.statusCode >= 500 ? 'server_error' : 'client_error',
        error_code: res.statusCode.toString(),
      });
      
      span.setAttributes({
        'http.status_code': res.statusCode,
        'error.type': res.statusCode >= 500 ? '5xx' : '4xx',
      });
    } else {
      span.setAttributes({
        'http.status_code': res.statusCode,
      });
    }

    span.end();
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

// Helper to track business operations
function trackBusinessOperation(operationName, result = 'success', durationMs = 0) {
  operationCounter.inc({ operation: operationName, result });
  if (durationMs > 0) {
    operationLatency.observe({ operation: operationName, result }, durationMs / 1000);
  }
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
  const span = tracer.startSpan('trace-test');
  traceCount.inc();
  const traceId = generateTraceId();
  
  span.addEvent('Test trace generated', {
    'trace.id': traceId,
    'timestamp': new Date().toISOString(),
  });

  res.json({
    message: 'Trace test generated',
    timestamp: new Date().toISOString(),
    trace_id: traceId,
    span_id: generateSpanId()
  });
  
  span.end();
});

// Business operation simulation endpoint
app.get('/api/process', (req, res) => {
  const operationName = 'data_processing';
  const startOp = Date.now();
  
  userActivityCounter.inc({ event_type: 'process_request', status: 'initiated' });
  
  // Simulate operation
  setTimeout(() => {
    const durationMs = Date.now() - startOp;
    const success = Math.random() > 0.1; // 90% success rate
    
    trackBusinessOperation(operationName, success ? 'success' : 'failed', durationMs);
    dataProcessed.inc({ type: 'json' }, Math.floor(Math.random() * 1000) + 100);
    
    if (success) {
      userActivityCounter.inc({ event_type: 'process_request', status: 'completed' });
      res.json({ status: 'completed', duration_ms: durationMs });
    } else {
      detailedErrors.inc({ error_category: 'operation_failure', error_code: '5000' });
      userActivityCounter.inc({ event_type: 'process_request', status: 'failed' });
      res.status(500).json({ status: 'failed', error: 'Operation failed' });
    }
  }, Math.random() * 2000);
});

// User session simulation
app.get('/api/session/start', (req, res) => {
  const sessionId = generateTraceId();
  const duration = Math.floor(Math.random() * 7200);
  
  userSessionDuration.observe(duration);
  userActivityCounter.inc({ event_type: 'session_start', status: 'initiated' });
  
  res.json({ session_id: sessionId, duration_seconds: duration });
});

app.listen(port, () => {
  console.log(`\n========================================`);
  console.log(`Server listening on port ${port} in ${env} mode`);
  console.log(`Service: everlasting-fairytale`);
  console.log(`========================================\n`);
  console.log(`Endpoints:`);
  console.log(`  Root:           http://localhost:${port}/`);
  console.log(`  Metrics:        http://localhost:${port}/metrics`);
  console.log(`  Health:         http://localhost:${port}/health`);
  console.log(`  Ready:          http://localhost:${port}/ready`);
  console.log(`  Trace Test:     http://localhost:${port}/trace-test`);
  console.log(`  Process Data:   POST http://localhost:${port}/api/process`);
  console.log(`  Start Session:  POST http://localhost:${port}/api/session/start\n`);
  console.log(`Monitoring & Tracing:`);
  console.log(`  Grafana:        http://localhost:3000 (admin/admin)`);
  console.log(`  Prometheus:     http://localhost:9090`);
  console.log(`  Jaeger UI:      http://localhost:16686`);
  console.log(`  Tempo API:      http://localhost:3200`);
  console.log(`  Alertmanager:   http://localhost:9093`);
  console.log(`========================================\n`);
});
