# Alerting Rules & Configuration

## Overview

Comprehensive alerting system with Prometheus, Alertmanager, and Grafana integration for the Everlasting Fairytale service.

## Alert Severity Levels

| Severity | Response Time | Example |
|----------|---------------|---------|
| **Critical** | Immediate | Service down, >10% error rate, SLA violation |
| **Warning** | 30 minutes | >5% error rate, P95 latency > 1s, queue building |
| **Info** | Daily review | No active users, routine notifications |

## Infrastructure Alerts

### ServiceDown
- **Severity:** Critical
- **Condition:** Service unreachable for 1+ minutes
- **Action:** Page on-call engineer

### HighErrorRate
- **Severity:** Warning
- **Condition:** Error rate > 5% for 5 minutes
- **Action:** Investigate root cause, check logs

### CriticalErrorRate
- **Severity:** Critical
- **Condition:** Error rate > 10% for 2+ minutes
- **Action:** Immediate escalation, rollback assessment

## Performance Alerts

### HighLatencyP95
- **Severity:** Warning
- **Condition:** P95 latency > 1 second for 5 minutes
- **Action:** Check database queries, external service latency

### HighLatencyP99
- **Severity:** Warning
- **Condition:** P99 latency > 2 seconds for 5 minutes
- **Action:** Analyze slow queries, increase resources

### CriticalLatency
- **Severity:** Critical
- **Condition:** P99 latency > 5 seconds for 2+ minutes
- **Action:** Immediate investigation, consider failover

## Business Metrics Alerts

### HighProcessingQueueSize
- **Severity:** Warning
- **Condition:** Queue > 100 items for 5 minutes
- **Metric:** `processing_queue_size`
- **Action:** Scale workers, investigate bottlenecks

### CriticalProcessingQueueSize
- **Severity:** Critical
- **Condition:** Queue > 500 items for 2+ minutes
- **Metric:** `processing_queue_size`
- **Action:** Emergency scaling, bypass optional processing

### SLA Compliance Alerts

#### LowSLACompliance (Standard)
- **Severity:** Warning
- **Condition:** Standard SLA < 95% for 10 minutes
- **Metric:** `sla_compliance_percentage{service_level="standard"}`

#### CriticalSLACompliance (Premium)
- **Severity:** Critical
- **Condition:** Premium SLA < 99% for 5+ minutes
- **Metric:** `sla_compliance_percentage{service_level="premium"}`
- **Action:** Notify premium customers, activate incident response

### Business Operation Alerts

#### BusinessOperationFailureRate
- **Severity:** Warning
- **Condition:** Operation failure rate > 5% for 5 minutes
- **Metric:** `business_operations_total{result="failed"}`
- **Action:** Review operation logs, check dependencies

#### OperationLatencyHigh
- **Severity:** Warning
- **Condition:** P95 operation latency > 3 seconds
- **Metric:** `business_operation_duration_seconds`
- **Action:** Profile operations, optimize slowest paths

## Resource Alerts

### HighMemoryUsage
- **Severity:** Warning
- **Condition:** Memory > 256 MB for 5 minutes
- **Action:** Review memory leaks, increase heap size

### CriticalMemoryUsage
- **Severity:** Critical
- **Condition:** Memory > 512 MB for 2+ minutes
- **Action:** Restart service, investigate memory leak

### HighCPUUsage
- **Severity:** Warning
- **Condition:** CPU > 80% for 5 minutes
- **Action:** Scale horizontally, profile CPU usage

## System Alerts

### PrometheusDown
- **Severity:** Critical
- **Condition:** Prometheus unreachable for 1+ minute
- **Impact:** Monitoring system offline
- **Action:** Restart Prometheus, check disk space

### JaegerDown
- **Severity:** Warning
- **Condition:** Jaeger unreachable for 2+ minutes
- **Impact:** Distributed tracing offline
- **Action:** Restart Jaeger, verify network connectivity

## Alert Routing

### Alertmanager Configuration

Alerts are routed based on severity and component:

```
Critical Alerts → PagerDuty, Slack #critical-alerts
Warning Alerts → Slack #warnings
Info Alerts → Logging system
```

## Custom Metrics for Alerting

### User Engagement
- `active_users_gauge` - Currently active users
- `user_activity_total` - Activity events
- `user_session_duration_seconds` - Session time tracking

### Business Operations
- `business_operations_total` - Operation counts with result labels
- `business_operation_duration_seconds` - Operation latency histogram
- `data_processed_bytes_total` - Data throughput

### Quality Metrics
- `error_rate_percentage` - Current error rate %
- `sla_compliance_percentage` - SLA achievement %
- `detailed_errors_total` - Categorized errors

## Testing Alerts

### Generate Test Alert (HighErrorRate)
```bash
curl -X POST http://localhost:8080/api/process?fail=true -d '{}' &
# Repeat to trigger error rate alert
for i in {1..50}; do curl http://localhost:8080/api/process; done
```

### Generate Test Alert (HighProcessingQueueSize)
```bash
# Simulate queue buildup
for i in {1..600}; do curl -X POST http://localhost:8080/api/process > /dev/null; done
```

### Generate Test Alert (ServiceDown)
```bash
# Stop service temporarily
docker stop node-app
# Alert fires after 1 minute
# Restart
docker start node-app
```

## Alert Thresholds

| Metric | Warning | Critical | Notes |
|--------|---------|----------|-------|
| Error Rate | 5% | 10% | Per 5-minute window |
| Latency P95 | 1.0s | - | For HTTP requests |
| Latency P99 | 2.0s | 5.0s | For HTTP requests |
| Queue Size | 100 | 500 | Processing queue |
| Memory | 256 MB | 512 MB | Process memory |
| CPU | 80% | - | CPU utilization |
| SLA (Standard) | < 95% | - | Over 10 minutes |
| SLA (Premium) | - | < 99% | Over 5 minutes |

## Alert Inhibition Rules

Prevents noise from lower-priority alerts when higher-priority ones are firing:

1. **Critical → Warning:** If critical alert fires, suppress warnings for same service
2. **Warning → Info:** If warning fires, suppress info-level alerts
3. Keeps focus on most urgent issues

## Accessing Alerts

| Service | URL | Purpose |
|---------|-----|---------|
| Prometheus Alerts | http://localhost:9090/alerts | View all alert rules |
| Alertmanager | http://localhost:9093 | Alert status & routing |
| Grafana Alerting | http://localhost:3000 → Alerting → Rules | Grafana-managed rules |

## Notification Channels

### Current Configuration
- **Webhook:** Local logging endpoint (default)
- **Slack Integration:** Configure webhook URL in alertmanager.yml

### Setup Slack Notifications

1. Create Slack webhook at: https://api.slack.com/apps
2. Update alertmanager.yml:
   ```yaml
   slack_configs:
     - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
   ```
3. Restart Alertmanager: `docker restart alertmanager`

### Setup PagerDuty Integration

1. Create PagerDuty integration key
2. Add to alertmanager.yml:
   ```yaml
   pagerduty_configs:
     - service_key: 'YOUR_PAGERDUTY_KEY'
   ```

## Maintenance

### Alert Rules Review
- Review quarterly for relevance
- Adjust thresholds based on business needs
- Archive obsolete rules

### Tuning
- Start with conservative thresholds
- Gradually tighten based on experience
- Avoid alert fatigue (too many false positives)

### Alert Drill Schedule
- Weekly: Test ServiceDown alert
- Monthly: Test critical path
- Quarterly: Full alerting system test
