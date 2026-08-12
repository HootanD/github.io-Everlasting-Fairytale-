# 🚀 QUICK START: Slack & PagerDuty Integration

Your Alertmanager is ready for webhook integration. Follow these 3 simple steps to enable production notifications.

---

## 📋 STEP 1: Get Your Webhook URLs (10 minutes)

### For Slack:

1. **Open** https://api.slack.com/apps
2. **Click** "Create New App" → "From scratch"
3. **Name:** `Prometheus Alertmanager` | **Workspace:** Select yours
4. **Click** "Incoming Webhooks" on left sidebar
5. **Toggle** "Activate Incoming Webhooks" → ON
6. **Click** "Add New Webhook to Workspace"
7. **Select channel:** `#critical-alerts` (create if needed)
8. **Click** "Allow"
9. **Copy** the Webhook URL that appears (looks like: `https://hooks.slack.com/services/T1234.../B5678.../XXXX...`)
10. **Repeat** for `#warnings` and `#monitoring` channels

### For PagerDuty:

1. **Open** https://app.pagerduty.com (create account if needed)
2. **Go** Services → "Create Service"
3. **Name:** `Everlasting Fairytale` → **Create**
4. **Go to** Integrations tab → "Add an integration"
5. **Select** "Events API v2" → **Name:** `Prometheus Alertmanager` → **Add**
6. **Copy** the Integration Key (looks like: `a1b2c3d4e5f6g7h8...`)

---

## ⚙️ STEP 2: Update Configuration (5 minutes)

**Option A: Edit alertmanager.yml manually**

```bash
# Open alertmanager.yml in your editor
# Find and replace:

# Line ~33: Slack critical channel webhook
- api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK_CRITICAL'
# → Change to your actual webhook URL

# Line ~52: Slack warning channel webhook
- api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK_WARNING'
# → Change to your actual webhook URL

# Line ~65: PagerDuty integration key
- service_key: 'YOUR_PAGERDUTY_INTEGRATION_KEY'
# → Change to your actual integration key
```

**Option B: Use sed (Linux/Mac)**

```bash
# Replace Slack webhook URLs
sed -i 's|YOUR/SLACK/WEBHOOK_CRITICAL|T1A2B3C/B4D5E6F/G7H8I9J0K1L2M3N4O5P6|g' alertmanager.yml

# Replace PagerDuty key
sed -i 's|YOUR_PAGERDUTY_INTEGRATION_KEY|a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6|g' alertmanager.yml
```

**Option C: Use Docker (Windows/Mac/Linux)**

```bash
# Copy file into container and test
docker cp alertmanager.yml alertmanager:/etc/alertmanager/config.yml

# Validate syntax
docker exec alertmanager amtool config
```

---

## ✅ STEP 3: Restart & Test (5 minutes)

### Restart Alertmanager

```bash
docker restart alertmanager

# Verify it started successfully
docker logs alertmanager | tail -5
# Should see: "configuration loaded successfully"
```

### Run Validation Script

**Linux/Mac:**
```bash
bash validate-alertmanager.sh
```

**Windows (PowerShell):**
```powershell
.\validate-alertmanager.ps1
```

This script will:
- ✓ Validate YAML syntax
- ✓ Check webhook URLs are configured
- ✓ Verify Alertmanager is running
- ✓ Show current alerts

### Test Alert Delivery

**Trigger a warning alert:**
```bash
# Generate HTTP errors
for i in {1..100}; do
  curl -s http://localhost:8080/invalid > /dev/null &
done

# Wait 5 minutes for HighErrorRate alert to fire
# Check: Slack #warnings channel should show alert
```

**Trigger a critical alert:**
```bash
# Stop the app
docker stop node-app

# Wait 1 minute
# Check: Slack #critical-alerts AND PagerDuty should show alert

# Restart
docker start node-app
```

---

## 🎯 Alert Routing

Once configured, your alerts automatically route:

| Alert Severity | Destination | Response Time |
|---|---|---|
| 🚨 **Critical** | Slack + PagerDuty | Immediate |
| ⚠️ **Warning** | Slack only | When next batch fires |
| ℹ️ **Info** | Silent | Logged only |

---

## 📊 Slack Message Examples

### Critical Alert (sent to #critical-alerts)
```
🚨 CRITICAL: ServiceDown
Service: everlasting-fairytale
Alert: ServiceDown
Severity: critical

Summary: Everlasting Fairytale service is down
Description: The everlasting-fairytale service has been unreachable for more than 1 minute

[View Prometheus] [View Alertmanager]
```

### Warning Alert (sent to #warnings)
```
⚠️ WARNING: HighErrorRate
Service: everlasting-fairytale
Alert: HighErrorRate

Description: Error rate is 8.5% (threshold: 5%)
```

---

## 🔍 Verify Everything is Working

### Check Alertmanager UI
```
http://localhost:9093
```
- View "Alerts" tab for current firing alerts
- Check "Status" tab to see receiver configuration

### Check Prometheus
```
http://localhost:9090/alerts
```
- View all alert rules
- See which alerts are currently firing

### Manual Alert Testing
```bash
# Create a test alert in Alertmanager
docker exec alertmanager amtool alert add TestAlert severity=critical

# It should appear in Slack immediately
# Then resolves automatically after resolve_timeout
```

### Check Logs
```bash
# View Alertmanager logs
docker logs alertmanager | tail -50

# Look for "Sending ... alerts to receiver" messages
# Should see webhook send confirmations
```

---

## 🆘 Troubleshooting

### Alerts not appearing in Slack?

```bash
# 1. Check Alertmanager logs
docker logs alertmanager 2>&1 | grep -i slack

# 2. Verify webhook URL is correct
grep "api_url" alertmanager.yml | grep -v "YOUR"

# 3. Test webhook manually
curl -X POST \
  -H 'Content-type: application/json' \
  -d '{"text":"Test from Alertmanager"}' \
  YOUR_WEBHOOK_URL

# 4. Check Slack app permissions
# - Has "chat:write" permission
# - App is joined to channel
```

### Alertmanager won't start?

```bash
# Validate YAML syntax
docker exec alertmanager amtool config

# Check for errors
docker logs alertmanager 2>&1 | grep -i error

# Common issues:
# - Invalid webhook URL format
# - Missing quotes in YAML
# - Extra spaces in YAML (indentation)
```

### PagerDuty not creating incidents?

```bash
# 1. Verify integration key
grep "service_key:" alertmanager.yml

# 2. Check PagerDuty service status
# - Service must be "Active"
# - Escalation policy must be assigned

# 3. Check logs for PagerDuty errors
docker logs alertmanager 2>&1 | grep -i pagerduty
```

---

## 📚 Full Documentation

For advanced configuration, see:
- **Full Setup Guide:** `SLACK_PAGERDUTY_SETUP.md`
- **Alerting Rules:** `ALERTING_SETUP.md`
- **Business Metrics:** `BUSINESS_METRICS_AND_ALERTING.md`

---

## 📞 Support

If something isn't working:

1. **Run validation script:**
   ```bash
   # Linux/Mac
   bash validate-alertmanager.sh
   
   # Windows PowerShell
   .\validate-alertmanager.ps1
   ```

2. **Check documentation:**
   - Section "Troubleshooting" in `SLACK_PAGERDUTY_SETUP.md`

3. **Review Alertmanager config:**
   ```bash
   docker exec alertmanager cat /etc/alertmanager/config.yml | less
   ```

4. **Test connectivity to webhooks:**
   ```bash
   # Slack
   curl -X POST -H 'Content-type: application/json' \
     -d '{"text":"Test"}' YOUR_SLACK_WEBHOOK_URL
   
   # PagerDuty API
   curl -X POST https://events.pagerduty.com/v2/enqueue \
     -H 'Content-Type: application/json' \
     -d '{"routing_key":"YOUR_KEY","event_action":"trigger"}'
   ```

---

## ✨ What's Next?

After webhooks are working:

1. **Add email notifications** (optional)
   - Update alertmanager.yml with SMTP config
   - Uncomment email section

2. **Customize alert thresholds**
   - Edit `prometheus-alerts.yml`
   - Adjust severity levels and time windows

3. **Set up PagerDuty escalation policies**
   - Auto-escalate unacknowledged alerts
   - Configure on-call schedules

4. **Create runbooks**
   - Document response procedures for each alert
   - Link in alert annotations

---

## 🎉 Done!

Your Prometheus Alertmanager is now configured to send production alerts to Slack and PagerDuty.

**Verify in Slack:**
- ✓ Channels created: #critical-alerts, #warnings, #monitoring
- ✓ App joined to channels
- ✓ Webhooks in alertmanager.yml

**Verify in PagerDuty:**
- ✓ Service created
- ✓ Integration key in alertmanager.yml
- ✓ Escalation policy assigned

**Test by:**
- ✓ Generating test alert (see above)
- ✓ Checking Slack channels
- ✓ Checking PagerDuty incidents

---

Need help? See full documentation files:
- 📖 `SLACK_PAGERDUTY_SETUP.md` - Complete setup with screenshots
- 📖 `ALERTING_SETUP.md` - Alert rules configuration
- 📖 `BUSINESS_METRICS_AND_ALERTING.md` - Metrics overview
