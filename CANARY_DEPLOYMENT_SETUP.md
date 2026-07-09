# Canary Deployment & Automated Rollback Guide

## Overview

This setup implements a **canary deployment** strategy with **automated rollback** on failure:

- **Stable (Production)**: Current live version, handles 90% traffic
- **Canary**: New version, handles 10% traffic, monitored for 2 minutes
- **Automatic Rollback**: Triggered on health check failure or metric thresholds

## Workflows

### 1. Canary Deployment (canary-deployment.yml)

**Triggered by:** Successful "Deploy with Approval Gates" workflow

**Steps:**
1. Deploy new version to canary (port 8081, 1 replica)
2. Wait for health checks (max 60 seconds)
3. Run smoke tests against canary endpoint
4. Monitor metrics for 2 minutes:
   - CPU usage (fail if > 80%)
   - Memory usage
   - Error rates
   - Response times
5. **If successful**: Promote to stable (replace production)
6. **If failed**: Automatic rollback to previous stable version

### 2. Automated Rollback (rollback-on-failure job)

**Triggered by:** Canary deployment failure or cancellation

**Steps:**
1. Stop canary deployment
2. Pull previous stable image (`latest` tag)
3. Restart production with stable version
4. Verify connectivity
5. Notify via Slack

## Docker Compose Setup

### Production Deployment

```bash
# Start stable production environment
docker compose -f docker-compose.prod.yml up -d

# Start with canary profile (adds canary instance)
docker compose -f docker-compose.prod.yml --profile canary up -d

# Start with load balancer (nginx, splits traffic)
docker compose -f docker-compose.prod.yml --profile lb up -d

# All together
docker compose -f docker-compose.prod.yml --profile canary --profile lb up -d
```

### Services

- **app-stable**: Production instance (port 8080)
- **app-canary**: Canary instance (port 8081, optional)
- **nginx-lb**: Load balancer (port 80, optional)

## Traffic Splitting (Nginx)

**Canary endpoint** (`/canary`):
- Routes to canary instance
- 10 requests/sec rate limit
- Manual traffic steering for testing

**Main endpoint** (`/`):
- Routes to stable instance
- 10 requests/sec rate limit per IP
- Automatic failover to canary if stable unhealthy

**Health endpoint** (`/health`):
- Fast health checks (2s timeout)
- Used for uptime monitoring

## Monitoring Thresholds

Edit `canary-deployment.yml` to adjust:

```yaml
# CPU threshold (default 80%)
if (( $(echo "$cpu_usage > 80" | bc -l) )); then
  # Trigger rollback
fi

# Add custom metrics:
# - Error rates
# - Response times
# - Database connection pools
# - Cache hit rates
```

## Rollback Scenarios

**Automatic rollback triggered if:**
- Canary health checks fail for 30 seconds
- CPU or memory exceeds thresholds
- Smoke tests fail
- Custom metrics exceed limits
- Workflow cancelled or times out

**Manual rollback:**

```bash
# Stop canary, restart stable with latest tag
docker compose -f docker-compose.canary.yml down
docker pull $REGISTRY/$IMAGE_NAME:latest
docker compose -f docker-compose.prod.yml up -d app-stable
```

## Production Checklist

- [ ] Set up Slack webhook for notifications (SLACK_WEBHOOK_URL secret)
- [ ] Configure monitoring thresholds (CPU, memory, errors)
- [ ] Test rollback manually before going live
- [ ] Set up external monitoring (Prometheus, Datadog, etc.)
- [ ] Configure persistent storage for logs
- [ ] Document custom metrics and alerting rules
- [ ] Train team on manual rollback procedures

## Example: Local Testing

```bash
# 1. Start stable production
docker compose -f docker-compose.prod.yml up -d
curl http://localhost:8080  # Should work

# 2. Start canary
docker compose -f docker-compose.prod.yml --profile canary up -d
curl http://localhost:8081  # Should work (canary)

# 3. Start load balancer
docker compose -f docker-compose.prod.yml --profile lb up -d
curl http://localhost       # Routes to stable
curl http://localhost/canary  # Routes to canary

# 4. Simulate canary failure (force rollback)
docker compose -f docker-compose.prod.yml down app-canary
# Workflow would detect failure and rollback
```

## Integration with External Monitoring

Replace in-workflow metrics collection with:

```bash
# Prometheus scrape
curl http://localhost:8080/metrics

# Datadog agent
# DatadogMetric: deployment=canary, environment=production

# CloudWatch
aws cloudwatch put-metric-data --metric-name CanaryErrorRate ...

# New Relic
curl -X POST https://api.newrelic.com/v2/applications/$APP_ID/events ...
```

## CI/CD Pipeline Recap

1. **Build** → multi-platform, tests, security scan
2. **Security** → Docker Scout, policy gates
3. **Approval** → manual gate before production
4. **Deploy** → canary deployment with monitoring
5. **Rollback** → automatic on failure

Next: Set up continuous monitoring, add external alerting (PagerDuty), or implement blue-green deployments.
