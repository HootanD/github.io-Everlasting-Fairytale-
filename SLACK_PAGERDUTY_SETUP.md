# Slack & PagerDuty Integration Setup Guide

## Overview

This guide provides step-by-step instructions to integrate Slack and PagerDuty notifications with your Prometheus Alertmanager. Alerts will automatically route to Slack channels and PagerDuty incidents based on severity.

---

## 🎯 Integration Architecture

```
Prometheus Alerts
      ↓
Alertmanager (Decision Engine)
      ├→ Critical: PagerDuty + Slack #critical-alerts
      ├→ Warning: Slack #warnings
      └→ Info: Slack #monitoring
```

---

## PART 1: SLACK INTEGRATION SETUP

### Step 1: Create Slack Channels

First, create dedicated channels in your Slack workspace for alert routing:

1. **Open Slack** → Click workspace name → **Create channel**
2. Create these channels:
   - `#critical-alerts` - For critical severity alerts (🚨)
   - `#warnings` - For warning severity alerts (⚠️)
   - `#monitoring` - For info-level alerts and general monitoring (ℹ️)

### Step 2: Create Slack Webhook URLs

Follow these steps to generate Slack Incoming Webhooks:

1. **Go to Slack App Directory**
   - Open: https://api.slack.com/apps
   - Click **Create New App** → **From scratch**
   - Name: `Prometheus Alertmanager`
   - Workspace: Select your workspace
   - Click **Create App**

2. **Enable Incoming Webhooks**
   - Left sidebar → **Incoming Webhooks**
   - Toggle: **Activate Incoming Webhooks** → ON
   - Click **Add New Webhook to Workspace**
   - Select channel: `#critical-alerts` (for first webhook)
   - Click **Allow**

3. **Copy Webhook URL**
   - You'll see a Webhook URL like:
   ```
   https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
   ```
   - Copy this URL

4. **Repeat for other channels**
   - Repeat steps 2-3 for:
     - `#warnings` - Save second webhook URL
     - `#monitoring` - Save third webhook URL

### Step 3: Update Alertmanager Configuration

Edit `alertmanager.yml` and replace webhook placeholders:

```yaml
# Line 1: Global Slack API (optional, for Slack integration)
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK_URL'

# Line ~30: Critical alerts receiver
receivers:
  - name: 'slack-critical'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXX1'  # Critical alerts webhook
        channel: '#critical-alerts'
        ...

  - name: 'slack-warning'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXX2'  # Warnings webhook
        channel: '#warnings'
        ...

  - name: 'slack-info'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXX3'  # Info webhook
        channel: '#monitoring'
        ...
```

### Step 4: Test Slack Integration

1. **Restart Alertmanager**
   ```bash
   docker restart alertmanager
   docker logs alertmanager | tail -20
   ```

2. **Trigger a test alert**
   ```bash
   # Generate HTTP errors to trigger HighErrorRate alert
   for i in {1..50}; do
     curl -s http://localhost:8080/invalid > /dev/null
   done
   ```

3. **Check Slack channels**
   - Open your Slack workspace
   - Navigate to `#critical-alerts` or `#warnings`
   - You should see alert messages appear

### Slack Message Format

Your alerts will appear like:

```
🚨 CRITICAL: HighErrorRate
Service: everlasting-fairytale
Alert: HighErrorRate
Severity: critical

Summary: High error rate detected
Description: Error rate is 12.5% (threshold: 5%)
Status: firing

[View in Prometheus]  [View Alerts]
```

---

## PART 2: PAGERDUTY INTEGRATION SETUP

### Step 1: Access PagerDuty

1. **Sign in to PagerDuty**
   - Go to: https://app.pagerduty.com
   - Login with your account (create one if needed)

### Step 2: Create a Service

1. **Navigate to Services**
   - Left sidebar → **Services** → **Service Directory**
   - Click **Create Service**

2. **Configure Service**
   - **Name:** `Everlasting Fairytale`
   - **Description:** Alerts from Prometheus Alertmanager
   - **Escalation Policy:** Choose your existing policy or create new
   - **Alert Creation:** Select appropriate setting
   - Click **Create Service**

### Step 3: Create Integration Key

1. **View Service Details**
   - Click your newly created service
   - Go to **Integrations** tab

2. **Add Integration**
   - Click **Add an integration**
   - Select **Events API v2** from the dropdown
   - Name: `Prometheus Alertmanager`
   - Click **Add**

3. **Copy Integration Key**
   - You'll see **Integration Key** (looks like):
   ```
   a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
   ```
   - Copy this key

### Step 4: Get Your PagerDuty Account/Integration IDs

For webhook-based integrations, you'll also need:

1. **Account ID**
   - Account Settings → **Account** tab → Copy **Account ID**

2. **Service ID**
   - From service page, look in URL: `https://app.pagerduty.com/services/P1A2B3C4D`
   - Service ID = `P1A2B3C4D`

### Step 5: Update Alertmanager Configuration

Edit `alertmanager.yml` and update PagerDuty section:

```yaml
receivers:
  - name: 'critical-pagerduty'
    pagerduty_configs:
      # Replace with your PagerDuty Integration Key from Step 3
      - service_key: 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6'
        description: '{{ .GroupLabels.alertname }} - {{ .CommonLabels.severity }}'
        details:
          firing: '{{ template "pagerduty.default.instances" .Alerts.Firing }}'
          service: '{{ .GroupLabels.service }}'
          environment: '{{ .CommonLabels.environment }}'
        client: 'Prometheus Alertmanager'
        client_url: 'http://alertmanager:9093'
        links:
          - href: 'http://prometheus:9090/graph'
            text: 'Prometheus Graph'
        severity: '{{ if eq .Status "firing" }}critical{{ else }}info{{ end }}'
```

### Step 6: Test PagerDuty Integration

1. **Restart Alertmanager**
   ```bash
   docker restart alertmanager
   docker logs alertmanager | tail -20
   ```

2. **Verify configuration loaded**
   - Check for any errors in logs
   - Should see: "loaded configuration"

3. **Create test incident**
   - Trigger critical alert (see Slack test above)
   - Check PagerDuty: **Incidents** → Should see new incident
   - Click incident to view details

---

## PART 3: ADVANCED CONFIGURATION

### Slack Rich Formatting

Your alertmanager.yml already includes:
- 🚨 **Critical** alerts with red (danger) color
- ⚠️ **Warning** alerts with yellow (warning) color
- ℹ️ **Info** alerts with green (good) color
- Buttons linking to Prometheus and Alertmanager UI
- Timestamps for alert triggering
- Service and environment labels

### PagerDuty Escalation Policy

Configure escalation for critical alerts:

1. **In PagerDuty:**
   - Settings → **Escalation Policies**
   - Create policy or select existing
   - Assign users who should be paged
   - Set escalation timings (e.g., 15 min → manager)

2. **Link to Service:**
   - Service settings → Set **Escalation Policy** to your policy

### Custom Webhook Integration

For custom integrations (Opsgenie, VictorOps, Mattermost, etc.):

```yaml
receivers:
  - name: 'custom-webhook'
    webhook_configs:
      - url: 'https://your-webhook-endpoint.com/alerts'
        send_resolved: true
        headers:
          Authorization: 'Bearer YOUR_TOKEN'
        # Optional: Custom request body template
        # See Alertmanager docs for full templating
```

---

## PART 4: TESTING & VALIDATION

### Test Alert Routes

#### Generate Critical Alert
```bash
# Stop the app to trigger ServiceDown alert
docker stop node-app

# Wait 1+ minute (alert fires after 1 min)
# Check:
# - Slack: #critical-alerts (should see alert)
# - PagerDuty: Incidents (should see new incident)

# Restart
docker start node-app
```

#### Generate Warning Alert
```bash
# Generate errors to trigger HighErrorRate alert
for i in {1..100}; do curl -s http://localhost:8080/invalid > /dev/null & done

# Check:
# - Slack: #warnings (should see alert)
# - PagerDuty: No incident (warning doesn't create incidents by default)
```

### Verify Configuration

```bash
# Check Alertmanager config is valid
docker exec alertmanager amtool config

# View current alerts
docker exec alertmanager amtool alert

# View receiver configuration
docker exec alertmanager cat /etc/alertmanager/config.yml | grep -A 20 "receivers:"
```

### Monitor Webhook Delivery

```bash
# Check Alertmanager logs for webhook sends
docker logs alertmanager 2>&1 | grep -E "webhook|pagerduty|slack"

# Look for entries like:
# "Sending alert batch to..." - indicates webhook was sent
```

---

## PART 5: PRODUCTION CONFIGURATION

### Security Best Practices

1. **Rotate Webhook URLs**
   - Change webhook URLs every 90 days
   - Document rotation dates

2. **Use Secrets Manager**
   - Store webhook URLs in Docker secrets (if using Swarm)
   - Or use environment variables in production

3. **Rate Limiting**
   - Alertmanager already has:
     - `group_wait: 10s` - Wait 10s to group similar alerts
     - `group_interval: 10s` - Group alerts from last 10s
     - `repeat_interval: 12h` - Don't repeat resolved alerts for 12h

4. **IP Allowlisting**
   - If behind firewall, allowlist Slack & PagerDuty IP ranges
   - PagerDuty: https://status.pagerduty.com/pages/incidents.json

### Monitoring Alertmanager Health

```bash
# Check Alertmanager is healthy
curl http://localhost:9093/-/healthy

# View metrics
curl http://localhost:9093/metrics | grep -E "alertmanager_|notification"
```

### Alert Fatigue Mitigation

The current configuration includes:

| Aspect | Setting | Purpose |
|--------|---------|---------|
| Group Wait | 10s | Hold alerts before first notification |
| Group Interval | 10s | Group similar alerts together |
| Repeat Interval | 12h | Only repeat unresolved alerts every 12h |
| Inhibition | Enabled | Suppress lower severity when higher fires |

**Adjust if needed:**
- Increase `group_wait` to 30s for high-volume environments
- Increase `repeat_interval` to 24h to reduce notification noise
- Fine-tune alert thresholds in `prometheus-alerts.yml`

---

## TROUBLESHOOTING

### Slack Messages Not Appearing

```bash
# 1. Check webhook URL is correct
docker logs alertmanager | grep -i slack

# 2. Verify Slack channel exists and is not archived
# 3. Check Slack app permissions:
#    - Has "chat:write" permission
#    - Joined the #critical-alerts channel

# 4. Test webhook manually
curl -X POST \
  -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  YOUR_WEBHOOK_URL
```

### PagerDuty Incidents Not Creating

```bash
# 1. Verify Integration Key is correct
grep -i "service_key" alertmanager.yml

# 2. Check PagerDuty service is active
#    - Service → Settings → Status should be "Active"

# 3. View PagerDuty logs
docker logs alertmanager | grep -i pagerduty

# 4. Test integration key with PagerDuty API
curl -X POST https://events.pagerduty.com/v2/enqueue \
  -H 'Content-Type: application/json' \
  -d '{
    "routing_key": "YOUR_INTEGRATION_KEY",
    "event_action": "trigger",
    "payload": {
      "summary": "Test incident",
      "severity": "critical",
      "source": "Alertmanager Test"
    }
  }'
```

### Configuration Validation Failed

```bash
# Validate YAML syntax
docker exec alertmanager amtool config

# Look for parse errors
docker logs alertmanager 2>&1 | grep -i error

# Common issues:
# - Indentation errors in YAML
# - Unclosed quotes in URLs
# - Invalid template syntax
```

---

## QUICK REFERENCE

### Webhook URLs to Update

In `alertmanager.yml`, find and replace:
- ✏️ Line ~13: `slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK_URL'`
- ✏️ Line ~50: `api_url: 'https://hooks.slack.com/services/T00.../XXXXXXX1'` (critical)
- ✏️ Line ~66: `api_url: 'https://hooks.slack.com/services/T00.../XXXXXXX2'` (warning)
- ✏️ Line ~82: `api_url: 'https://hooks.slack.com/services/T00.../XXXXXXX3'` (info)
- ✏️ Line ~102: `service_key: 'YOUR_PAGERDUTY_INTEGRATION_KEY'`

### Restart Alertmanager

```bash
# After updating alertmanager.yml
docker cp alertmanager.yml alertmanager:/etc/alertmanager/config.yml
docker restart alertmanager

# Verify
docker logs alertmanager | tail -5
```

### View Current Alerts

```bash
# Prometheus UI
http://localhost:9090/alerts

# Alertmanager UI
http://localhost:9093/#/alerts

# Command line
docker exec alertmanager amtool alert
```

---

## SUPPORT & DOCUMENTATION

- **Slack API Docs:** https://api.slack.com/messaging/webhooks
- **PagerDuty Events API:** https://developer.pagerduty.com/docs/events-api-v2
- **Alertmanager Docs:** https://prometheus.io/docs/alerting/latest/configuration/
- **Alertmanager Templates:** https://prometheus.io/docs/alerting/latest/notification_template_examples/

---

## Next Steps

1. ✅ Create Slack channels
2. ✅ Generate Slack webhook URLs
3. ✅ Update `alertmanager.yml` with Slack webhooks
4. ✅ Restart Alertmanager
5. ✅ Test Slack alerts
6. ✅ (Optional) Setup PagerDuty
7. ✅ Update `alertmanager.yml` with PagerDuty key
8. ✅ Restart Alertmanager
9. ✅ Test PagerDuty incidents
10. ✅ Configure escalation policies & on-call schedules

**Once configured, your alerting system will automatically:**
- Send critical alerts to Slack + PagerDuty
- Send warnings to Slack
- Create incidents for ops team
- Escalate to on-call staff after time threshold
- Include actionable links and context

🎉 Production-grade alerting is ready!
