const express = require('express');
const prometheus = require('prom-client');
const { NodeTracerProvider } = require('@opentelemetry/node');
const { registerInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { JaegerExporter } = require('@opentelemetry/exporter-jaeger');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { BatchSpanProcessor } = require('@opentelemetry/sdk-trace-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

// Initialize tracing
const resource = Resource.default().merge(
  new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'node-app',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.versions.node,
    environment: process.env.NODE_ENV || 'development',
  }),
);

const tracerProvider = new NodeTracerProvider({ resource });

// Export to Jaeger
const jaegerExporter = new JaegerExporter({
  endpoint: process.env.JAEGER_ENDPOINT || 'http://jaeger:6831',
});

// Export to Tempo (via OTLP)
const tempoExporter = new OTLPTraceExporter({
  url: process.env.TEMPO_ENDPOINT || 'http://tempo:4318/v1/traces',
});

tracerProvider.addSpanProcessor(new BatchSpanProcessor(jaegerExporter));
tracerProvider.addSpanProcessor(new BatchSpanProcessor(tempoExporter));

registerInstrumentations({
  tracerProvider,
});

tracerProvider.register();

const tracer = tracerProvider.getTracer('node-app-tracer');

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

const app = express();
const port = process.env.PORT || 8080;
const env = process.env.NODE_ENV || 'development';

// Middleware: request tracing and metrics
app.use((req, res, next) => {
  const startTime = Date.now();
  const span = tracer.startSpan(`${req.method} ${req.path}`);
  
  span.setAttributes({
    'http.method': req.method,
    'http.url': req.url,
    'http.target': req.path,
    'http.host': req.hostname,
    'http.client_ip': req.ip,
  });

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

    span.setAttributes({
      'http.status_code': res.statusCode,
      'http.duration_ms': durationMs,
    });
    
    span.end();
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

// Health endpoint with trace context
app.get('/health', (req, res) => {
  const span = tracer.startSpan('health-check');
  span.addEvent('health_check_performed');
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
  span.end();
});

// Ready endpoint
app.get('/ready', (req, res) => {
  res.json({ status: 'ready' });
});

app.listen(port, () => {
  console.log(`Server listening on port ${port} in ${env} mode`);
  console.log(`Metrics: http://localhost:${port}/metrics`);
  console.log(`Traces: Jaeger and Tempo`);
});
