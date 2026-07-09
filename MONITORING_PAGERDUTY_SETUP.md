# External Monitoring & PagerDuty Integration Guide

## Overview

This setup provides comprehensive monitoring with:
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization dashboards
- **Datadog**: APM and infrastructure monitoring
- **PagerDuty**: Incident management and on-call escalation
- **AlertManager**: Alert routing and deduplication

## Quick Start

### 1. Start Monitoring Stack

```bash
# Set environment variables
export DD_API_KEY=your_datadog_api_key
export DD_SITE=datadoghq.com
export PAGERDUTY_SERVICE_KEY=your_pagerduty_service_key
export SLACK_WEBHOOK_URL=your_slack_webhook_url

# Start all services
docker compose -f docker-compose.monitoring.yml up -d

# Or with profiles
docker compose -f docker-compose.monitoring.yml --profile lb --profile canary up -d
```

### 2. Access UIs

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)
- **AlertManager**: http://localhost:9093
- **cAdvisor**: http://localhost:8888
- **Node Exporter**: http://localhost:9100/metrics

## Prometheus Configuration

### Scrape Jobs

- `prometheus`: Prometheus self-monitoring
- `node`: Host CPU, memory, disk metrics
- `cadvisor`: Container resource metrics
- `app-stable`: Application metrics (port 8080)
- `app-canary`: Canary metrics (port 8081)

### Alert Rules (prometheus-rules.yml)

**Critical Alerts (trigger PagerDuty):**
- Container down (immediate)
- Canary deployment unhealthy (30s threshold)

**Warning Alerts (Slack only):**
- High CPU (> 80% for 2 min)
- High memory (> 85% for 2 min)
- High error rate (> 5% for 2 min)
- Node exporter down
- Prometheus scrape errors

## Datadog Integration

### Setup

1. Get your Datadog API key: https://app.datadoghq.com/account/settings/agent/advanced
2. Add secrets to GitHub:
   - `DD_API_KEY`: Your API key
   - `DD_SITE`: `datadoghq.com` (or `datadoghq.eu` for EU)

### Features

- **Container monitoring**: CPU, memory, network per container
- **APM traces**: Automatic tracing of HTTP requests
- **Logs**: Container logs collected automatically
- **Metrics**: Custom deployment metrics sent from CI/CD

### Datadog Container Labels

Containers include auto-discovery labels for Datadog Agent:

```yaml
labels:
  com.datadoghq.ad.check_names: '["http_check"]'
  com.datadoghq.ad.init_configs: '[{}]'
  com.datadoghq.ad.instances: '[{"name": "app-stable", "url": "http://localhost:8080", "timeout": 3}]'
```

## AlertManager Routing

### Alert Flow

```
Prometheus Alert
    ↓
AlertManager (evaluates labels)
    ↓
├─ severity: critical → PagerDuty (+ Slack)
├─ severity: warning → Slack only
└─ default → Default receiver
```

### PagerDuty Integration

**Setup:**

1. Create PagerDuty service: https://app.pagerduty.com/services
2. Get integration key (Events API v2)
3. Add to GitHub secrets:
   - `PAGERDUTY_SERVICE_KEY`: For AlertManager routing
   - `PAGERDUTY_INTEGRATION_KEY`: For GitHub Actions workflow

**Alert Severity Mapping:**
- `critical` → High urgency (immediate)
- `warning` → Low urgency (escalates after 30 min)

## GitHub Actions - Monitoring Alerts

Workflow: `.github/workflows/monitoring-alerts.yml`

Triggers on deployment failure:
1. **Creates PagerDuty incident** with deployment details
2. **Sends Datadog event** with workflow status
3. **Sends custom metric** for dashboard tracking
4. **Resolves incident** on recovery

## Grafana Dashboards

### Pre-configured Dashboards

- **Docker Host**: CPU, memory, disk, network
- **Container Metrics**: Per-container resource usage
- **Prometheus**: Scrape health, metrics volume
- **Deployment Status**: Canary vs stable comparison

### Create Custom Dashboard

1. Go to http://localhost:3000
2. New Dashboard → Add Panel
3. Select Prometheus data source
4. Example query: `up{job="app-stable"}`
5. Save

### Example Queries

```promql
# Request rate
rate(http_requests_total[5m])

# Error rate percentage
(rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]))

# Container CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Memory usage percentage
(container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100

# Deployment uptime
up{job=~"app-.*"}
```

## Environment Variables (.env)

```bash
# Datadog
DD_API_KEY=<your_api_key>
DD_SITE=datadoghq.com

# PagerDuty
PAGERDUTY_SERVICE_KEY=<events_api_v2_key>

# Slack
SLACK_WEBHOOK_URL=<slack_webhook_url>

# Registry
REGISTRY=docker.io
IMAGE_NAME=username/repo
```

## Local Testing

```bash
# 1. Start monitoring
docker compose -f docker-compose.monitoring.yml up -d

# 2. Verify Prometheus can scrape
curl http://localhost:9090/api/v1/query?query=up

# 3. View AlertManager
curl http://localhost:9093/api/v1/alerts

# 4. Trigger a test alert
docker stop app-stable
# Wait 1-2 min for alert to fire

# 5. Check Prometheus alerts
curl http://localhost:9090/api/v1/alerts

# 6. Recover service
docker start app-stable
```

## Production Deployment Checklist

- [ ] Create Datadog service account (read-only for metrics)
- [ ] Create PagerDuty service and escalation policy
- [ ] Configure on-call rotations in PagerDuty
- [ ] Set up Slack channels (#alerts, #warnings, #incidents)
- [ ] Configure Prometheus retention policy (current: 7 days)
- [ ] Backup Prometheus volume regularly
- [ ] Configure Grafana authentication (OAuth2/SAML)
- [ ] Export Grafana dashboards for version control
- [ ] Set up Grafana alerting rules
- [ ] Test PagerDuty incident creation manually
- [ ] Test escalation policies
- [ ] Document runbooks for each alert
- [ ] Configure mobile notifications in PagerDuty

## Troubleshooting

**Prometheus not scraping:**
```bash
docker logs prometheus
# Check targets: http://localhost:9090/targets
```

**Datadog agent not collecting:**
```bash
docker logs datadog-agent
# Verify API key: echo $DD_API_KEY
```

**PagerDuty not receiving alerts:**
```bash
# Check AlertManager logs
docker logs alertmanager

# Test webhook manually
curl -X POST https://events.pagerduty.com/v2/enqueue \
  -H 'Content-Type: application/json' \
  -d '{
    "routing_key": "your_service_key",
    "event_action": "trigger",
    "payload": {
      "summary": "Test alert",
      "severity": "critical",
      "source": "test"
    }
  }'
```

## Next Steps

- Integrate with ServiceNow for change management
- Set up synthetic monitoring (uptime checks)
- Configure log aggregation (ELK, Splunk)
- Implement distributed tracing (Jaeger, DataDog APM)
- Create SLO/SLI dashboards
