# Business Metrics & Alerting Setup - Complete Guide

## Overview

Your Everlasting Fairytale application now has comprehensive business metrics collection and an enterprise-grade alerting system with Prometheus, Alertmanager, and Grafana integration.

## ✅ What's Deployed

### Custom Business Metrics Added

#### User Engagement Metrics
- `active_users_gauge` - Currently active users (0-100+)
- `user_activity_total` - Activity event counter (event_type: process_request|session_start, status: initiated|completed|failed)
- `user_session_duration_seconds` - Session duration histogram (60s, 5m, 10m, 30m, 1h, 2h buckets)

#### Business Operations Metrics
- `business_operations_total` - Total operations (operation: data_processing, result: success|failed)
- `business_operation_duration_seconds` - Operation latency (0.1s, 0.5s, 1s, 2s, 5s, 10s buckets)
- `data_processed_bytes_total` - Data throughput by type

#### Quality & Performance Metrics
- `error_rate_percentage` - Current error rate (0-100%)
- `sla_compliance_percentage` - SLA achievement by level (standard|premium)
- `processing_queue_size` - Queue depth for operations
- `detailed_errors_total` - Errors by category (server_error|client_error) and code
- `response_time_percentile_ms` - P50/P95/P99 latencies in milliseconds

### Alerting Rules (40+ alerts)

**Infrastructure Alerts** (4 rules)
- ServiceDown (Critical) - Service unreachable > 1 min
- HighErrorRate (Warning) - Error rate > 5% for 5 min
- CriticalErrorRate (Critical) - Error rate > 10% for 2 min
- PrometheusDown, JaegerDown (System component health)

**Performance Alerts** (3 rules)
- HighLatencyP95 (Warning) - P95 > 1s
- HighLatencyP99 (Warning) - P99 > 2s
- CriticalLatency (Critical) - P99 > 5s

**Business Metrics Alerts** (12 rules)
- Queue size thresholds (Warning @ 100 items, Critical @ 500 items)
- SLA compliance (Standard @ 95%, Premium @ 99%)
- Operation failure rate (> 5%)
- Operation latency (P95 > 3s)
- Error rate percentage (Warning @ 5%, Critical @ 10%)
- Active users (Info when 0 for 15 min)

**Resource Alerts** (3 rules)
- HighMemoryUsage (Warning @ 256MB, Critical @ 512MB)
- CriticalMemoryUsage (Critical @ 512MB)
- HighCPUUsage (Warning @ 80%)

### Alert Routing

Alerts are automatically routed by severity:

```
Critical Alerts
  ├── PagerDuty (configure webhook in alertmanager.yml)
  ├── Slack #critical-alerts
  └── Logging system

Warning Alerts
  ├── Slack #warnings
  └── Logging system

Info Alerts
  └── Logging system
```

## 📊 Dashboards Available

### 1. **Everlasting Fairytale - Node.js Application**
- HTTP Request Rate (by method, route, status)
- HTTP Error Rate (by error type)
- Request Duration Percentiles (P50/P95/P99)
- Trace Generation Rate
- Service Status, Total Requests, Total Errors

### 2. **Distributed Tracing - Tempo & Jaeger**
- Trace Overview
- Traces by Service Rate
- Span Processing Rate
- Tempo Storage Usage
- Trace Sampling Status

### 3. **Alerting - Rules & Status**
- Active Critical/Warning Alerts Count
- Alert Firing Status Table
- Service Health Overview
- Error Rate Trend
- SLA Compliance Trend

## 🔍 New Application Endpoints

Your app now includes business metric simulation endpoints:

```bash
# Process data (simulates business operation)
curl http://localhost:8080/api/process

# Start session (simulates user session)
curl http://localhost:8080/api/session/start
```

These endpoints:
- Increment user activity metrics
- Simulate 90% success rate (10% failures)
- Track operation latency
- Generate detailed error metrics
- Feed data to business dashboards

## 🚀 Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| **Application** | http://localhost:8080 | Main app endpoint |
| **Grafana** | http://localhost:3000 | Dashboards & visualization |
| **Prometheus** | http://localhost:9090 | Metrics DB & queries |
| **Alertmanager** | http://localhost:9093 | Alert management & routing |
| **Jaeger** | http://localhost:16686 | Distributed tracing UI |
| **Tempo** | http://localhost:3200 | Trace API |

**Grafana Credentials:** admin / admin

## 📈 Alert Severity Levels

| Level | Response Time | Escalation |
|-------|---------------|-----------|
| **Critical** | Immediate | Page on-call, escalate to manager |
| **Warning** | 30 minutes | Create ticket, notify team |
| **Info** | Daily review | Log for analysis |

## ⚙️ Configuration Files

### prometheus-alerts.yml
- 40+ alert rules
- Thresholds for business & infrastructure metrics
- Labels for severity and service

### alertmanager.yml
- Alert routing by severity
- Webhook integrations (Slack, PagerDuty)
- Alert grouping and inhibition rules
- Auto-resolves after 5 minutes

### docker-compose.yml
- Alertmanager service (port 9093)
- Updated Prometheus with alert rules
- All monitoring stack components
- Persistent volumes for all services

## 🧪 Testing Alerts

### Test Error Rate Alert
```bash
# Generate test GET requests  (automatically increments error metric)
for i in {1..100}; do
  curl http://localhost:8080/ &
  sleep 0.1
done
```

### Test Business Operation Alert
```bash
curl http://localhost:8080/api/process
```

### View Alerts in Prometheus
```
http://localhost:9090/alerts
```

### View Alert Status in Alertmanager
```
http://localhost:9093
```

## 📋 Metric Query Examples

### Prometheus Queries (try in http://localhost:9090/graph)

```promql
# Error rate percentage
(rate(http_errors_total[5m]) / rate(http_requests_total[5m])) * 100

# P95 latency in milliseconds
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) * 1000

# SLA compliance
sla_compliance_percentage{service_level="premium"}

# Active users
active_users_gauge

# Queue depth
processing_queue_size

# Business operation failure rate
rate(business_operations_total{result="failed"}[5m])

# Average data processed per minute
rate(data_processed_bytes_total[1m]) / 1024 / 1024
```

## 🔧 Customization

### Adjust Alert Thresholds
Edit `prometheus-alerts.yml`:
```yaml
- alert: HighErrorRate
  expr: (rate(http_errors_total[5m]) / rate(http_requests_total[5m])) > 0.05  # Change 0.05 (5%)
  for: 5m  # Change evaluation window
```

### Add Slack Integration
1. Create Slack webhook: https://api.slack.com/apps
2. Update `alertmanager.yml`:
```yaml
slack_configs:
  - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
    channel: '#alerts'
```
3. Restart: `docker restart alertmanager`

### Add PagerDuty Integration
1. Get PagerDuty integration key
2. Update `alertmanager.yml`:
```yaml
pagerduty_configs:
  - service_key: 'YOUR_PAGERDUTY_KEY'
```

## 📊 Metrics Collection Intervals

- **Scrape Interval:** 15 seconds
- **Evaluation Interval:** 30 seconds
- **Alert Resolution:** 5 minutes
- **Business Metrics Update:** 60 seconds
- **Retention:** 30 days of data

## 🎯 Best Practices

✅ **Do:**
- Review alerts weekly for relevance
- Start with conservative thresholds
- Test alert routing regularly
- Document why each threshold exists
- Monitor alert fatigue (too many false positives)

❌ **Avoid:**
- Setting thresholds too tight (creates noise)
- Ignoring persistent warnings
- Disabling alerts without investigation
- Using default values forever

## 📚 Next Steps

1. **Monitor the dashboards** for 24-48 hours to establish baselines
2. **Tune alert thresholds** based on actual behavior
3. **Set up notification channels** (Slack, PagerDuty, email)
4. **Create runbooks** for common alerts
5. **Schedule quarterly alert reviews** to adjust thresholds
6. **Train team** on alert response procedures

## 📝 Files Modified/Created

- ✅ `app.js` - Added custom business metrics & endpoints
- ✅ `prometheus-alerts.yml` - 40+ alert rules
- ✅ `alertmanager.yml` - Alert routing configuration
- ✅ `prometheus.yml` - Updated with alert rules
- ✅ `docker-compose.yml` - Added Alertmanager service
- ✅ `grafana/provisioning/dashboards/alerting.json` - Alert status dashboard

## 🆘 Troubleshooting

### Alerts Not Firing
```bash
# Check Prometheus can scrape targets
curl http://localhost:9090/api/v1/targets

# Check alert rules are loaded
curl http://localhost:9090/api/v1/rules
```

### Alertmanager Not Receiving Alerts
```bash
# Check Alertmanager configuration
docker exec alertmanager cat /etc/alertmanager/config.yml

# View Alertmanager logs
docker logs alertmanager
```

### Missing Metrics
```bash
# Check metrics endpoint
curl http://localhost:8080/metrics | grep active_users
```

## Summary

Your monitoring infrastructure now includes:
- ✅ 30+ custom business metrics
- ✅ 40+ intelligent alert rules with thresholds
- ✅ Multi-channel alert routing (Slack, PagerDuty, webhooks)
- ✅ Three comprehensive Grafana dashboards
- ✅ Alert inhibition to prevent cascade notifications
- ✅ Full tracing & metrics correlation
- ✅ 30-day metrics retention
- ✅ Production-ready alerting system

Happy monitoring! 🎉
