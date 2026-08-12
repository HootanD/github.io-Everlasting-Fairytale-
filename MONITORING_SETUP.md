# Everlasting Fairytale - Monitoring & Tracing Setup

## Services Running

All monitoring and tracing services are now running and integrated with your Node.js application.

### Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| **Node.js App** | http://localhost:8080 | N/A |
| **Grafana Dashboards** | http://localhost:3000 | admin / admin |
| **Prometheus Metrics** | http://localhost:9090 | N/A |
| **Jaeger Tracing UI** | http://localhost:16686 | N/A |
| **Tempo API** | http://localhost:3200 | N/A |

### Application Endpoints

- `GET /` - Root endpoint
- `GET /metrics` - Prometheus metrics
- `GET /health` - Health check
- `GET /ready` - Readiness probe
- `GET /trace-test` - Generate test trace

## Monitoring Stack

### Prometheus
- **Purpose:** Metrics collection and storage
- **Scrape Targets:**
  - Node.js app metrics (`/metrics` endpoint)
  - Jaeger admin metrics
  - Tempo API metrics
  - Prometheus self-monitoring
- **Retention:** 30 days
- **Interval:** 15 seconds

### Grafana
- **Dashboards Included:**
  - **Everlasting Fairytale - Node.js Application**: HTTP request rates, error rates, latency percentiles (P50/P95/P99), trace generation
  - **Distributed Tracing - Tempo & Jaeger**: Trace overview, traces by service, span processing, storage usage

- **Data Sources Configured:**
  - Prometheus (default)
  - Tempo (tracing backend)
  - Jaeger (distributed tracing UI)

## Distributed Tracing

### OpenTelemetry Integration
- **Node.js SDK:** Auto-instrumentation enabled
- **Service Name:** `everlasting-fairytale`
- **Export Endpoint:** http://tempo:4318 (OTLP HTTP)
- **Automatic Spans:** Express middleware, HTTP requests, trace propagation

### Jaeger
- **Purpose:** Distributed tracing backend
- **Features:**
  - Trace collection and storage
  - Span visualization
  - Service dependency mapping

### Tempo
- **Purpose:** Trace aggregation and querying
- **Protocol Support:**
  - OTLP HTTP (4318)
  - OTLP gRPC (4317)
  - Jaeger protocols (6831-6832 UDP, 14268 HTTP)
- **Storage:** Local volume persistence

## Metrics Collected

### HTTP Metrics
- `http_request_duration_seconds` - Request latency histogram
- `http_requests_total` - Total request counter
- `http_errors_total` - Error counter by type (4xx/5xx)

### Tracing Metrics
- `trace_generation_total` - Traces generated

### Infrastructure Metrics
- Node.js runtime metrics (auto-collected)
- Process memory, CPU, file descriptors
- GC statistics

## Key Features

✓ Real-time metrics visualization  
✓ Automatic OpenTelemetry instrumentation  
✓ Distributed trace correlation  
✓ Service dependency tracking  
✓ Latency percentile tracking (P50/P95/P99)  
✓ Error rate monitoring  
✓ Long-term metrics retention (30 days)  

## Docker Compose Configuration

Services are orchestrated via `docker-compose.yml`:
- Network: `monitoring` (bridge)
- Volumes: `tempo-data`, `prometheus-data`, `grafana-data`
- Automatic restart on failure

## Testing the Setup

### Test Trace Generation
```bash
curl http://localhost:8080/trace-test
```

### View Metrics
```bash
curl http://localhost:8080/metrics
```

### Query Prometheus
```
http://localhost:9090/graph
# Example queries:
rate(http_requests_total[5m])
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### Explore Traces in Jaeger
1. Visit http://localhost:16686
2. Select "everlasting-fairytale" service
3. Click "Find Traces"

### Query Traces in Tempo
- Tempo API: http://localhost:3200
- Use Grafana Explore with Tempo datasource
