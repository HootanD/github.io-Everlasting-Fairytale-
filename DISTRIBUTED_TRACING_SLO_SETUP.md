# Distributed Tracing & SLO/SLI Setup

## Overview

Implements complete observability:
- **Distributed Tracing**: Jaeger + Tempo for request tracking across services
- **Metrics**: Prometheus with OpenTelemetry instrumentation
- **SLO/SLI**: Service Level Objectives and Indicators with automated alerts
- **Logs**: Loki integration for log aggregation
- **Visualization**: Grafana dashboards for SLO compliance

## Architecture

### Distributed Tracing Stack

```
Application (OpenTelemetry)
    ↓
  Jaeger (real-time UI)
  Tempo (long-term storage)
    ↓
Grafana (trace visualization)
```

**Services:**
- **Jaeger** (port 16686): Real-time trace UI, local storage
- **Tempo** (port 3200): Trace aggregation, long-term storage
- **Application**: Exports spans via Jaeger exporter (UDP) + OTLP/HTTP

### Application Instrumentation

OpenTelemetry auto-instrumentation:
- All HTTP requests traced
- Automatic latency, errors, status codes
- Custom events (health checks, business metrics)
- Full request context across services

Metrics collected:
- `http_request_duration_seconds` (histogram with buckets)
- `http_requests_total` (counter by method/route/status)
- `http_errors_total` (counter by error type)
- Latency percentiles (P50, P95, P99)

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Start Tracing Stack

```bash
docker compose up -d  # Jaeger + Tempo + app
```

### 3. Start SLO/Metrics Stack

```bash
docker compose -f docker-compose.slo.yml up -d  # Prometheus + Grafana + Loki
```

### 4. Access UIs

- **Jaeger**: http://localhost:16686
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **App**: http://localhost:8080

### 5. Generate Traffic

```bash
# Simple load
for i in {1..100}; do curl http://localhost:8080; sleep 0.1; done

# With Apache Bench
ab -n 1000 -c 10 http://localhost:8080/
```

## Service Level Objectives (SLOs)

### Defined SLOs

1. **Availability**: 99.9% (allowable downtime: ~22 minutes/month)
   - Threshold: Error rate < 0.1%
   - Alert: AvailabilitySLOBreach

2. **Latency**: P99 < 500ms
   - Threshold: 99th percentile under 500ms
   - Alert: LatencySLOBreach

3. **Error Rate**: < 0.1%
   - Threshold: Server errors < 0.1% of requests
   - Alert: ErrorRateSLOBreach

4. **Canary Availability**: > 99%
   - Threshold: Canary deployment errors < 1%
   - Alert: CanaryAvailabilityLow (triggers auto-rollback)

### SLI (Service Level Indicators)

Recorded metrics (prometheus-rules.yml):

```
sli:request:availability         # % successful requests
sli:request:latency              # % requests under 500ms
sli:request:latency_p95          # 95th percentile latency
sli:request:latency_p99          # 99th percentile latency
sli:request:error_rate           # % error rate
sli:request:throughput           # requests/sec
```

## Grafana SLO Dashboard

Pre-built dashboard (`slo-dashboard.json`):

**Gauges:**
- Availability SLI (target: 99.9%)
- Error Rate (target: < 0.1%)
- Latency P95 (target: < 300ms)
- Latency P99 (target: < 500ms)

**Graphs:**
- Availability SLO Trend (99.9% threshold line)
- Error Rate Trend (0.1% threshold line)
- Latency Distribution (P50, P95, P99)
- SLO Compliance Summary (1 = compliant, 0 = breach)

**Import Dashboard:**
1. Grafana → Dashboards → New → Import
2. Upload `slo-dashboard.json`
3. Select Prometheus datasource

## Tracing in Jaeger

### Navigate Traces

1. Open http://localhost:16686
2. Service: `node-app`
3. Filter by:
   - Operation: `GET /`, `GET /health`, `GET /metrics`
   - Status: Success/Error
   - Latency: Min/Max range

### Trace Details

Each span shows:
- Duration
- Status (OK/error)
- HTTP attributes (method, URL, status code)
- Custom events

### Trace Search

```
service.name=node-app
duration >= 100ms
status=error
```

## Connecting Grafana to Traces

### Add Tempo Datasource

1. Grafana → Data Sources → Add
2. Type: Tempo
3. URL: http://tempo:3200
4. Save & test

### Link Traces from Metrics

In Grafana dashboards:
- Click on trace in panel
- Tempo integration shows related traces
- Jump from metrics to traces

## SLO Alerting

### Alert Rules

In `slo-rules.yml`:
- Availability breach (< 99.9% for 5 min)
- Latency breach (P99 > 500ms for 5 min)
- Error rate breach (> 0.1% for 5 min)
- Canary availability low (< 99% for 2 min → triggers rollback)

### Alert Routing

→ AlertManager → PagerDuty (critical) / Slack (warning)

## Custom SLOs

Modify `slo-rules.yml`:

```yaml
# Add custom SLI
- record: sli:custom:metric
  expr: |
    custom_query_here

# Add custom alert
- alert: CustomSLOBreach
  expr: sli:custom:metric < threshold
  for: 5m
```

## Production Checklist

- [ ] Configure persistent storage for Tempo traces (S3/GCS)
- [ ] Set Prometheus retention to 30+ days for SLO trending
- [ ] Export Grafana dashboards to version control
- [ ] Configure Loki retention policy
- [ ] Test trace sampling (start at 10%, scale down)
- [ ] Document SLO/SLI definitions with team
- [ ] Set up error budget tracking
- [ ] Create runbooks for SLO breaches
- [ ] Configure notification channels (email, Slack, PagerDuty)
- [ ] Monitor observability stack itself (disk, CPU, memory)

## Performance Impact

- Tracing overhead: ~1-2% latency increase
- Memory per span: ~1KB
- Disable in non-critical paths: `span.setAttributes({...})` optional

## Troubleshooting

**Traces not appearing in Jaeger:**
```bash
docker logs jaeger
# Check if app sends spans to localhost:6831
curl -s http://localhost:16686/api/services
```

**SLI metrics missing:**
```bash
docker logs prometheus
# Check http://localhost:9090/graph
# Query: sli:request:availability
```

**Grafana datasource not working:**
```bash
docker logs grafana
# Verify http://localhost:3200 is accessible
curl http://tempo:3200/ready
```

## Next Steps

- Implement error budget tracking
- Add cost monitoring to SLI dashboard
- Integrate with incident response (auto-page on SLO breach)
- Set up trace sampling policies
- Configure distributed context propagation for multi-service setups
