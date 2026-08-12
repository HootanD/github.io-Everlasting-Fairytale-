# Alertmanager Configuration Validator & Setup Helper (PowerShell)
# Validates webhook URLs and tests alert routing

$ErrorActionPreference = "Stop"

# Colors (Windows 10+ Terminal)
function Write-Header {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Alertmanager Webhook Configuration Tool" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$message)
    Write-Host "✓ $message" -ForegroundColor Green
}

function Write-Error {
    param([string]$message)
    Write-Host "✗ $message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$message)
    Write-Host "⚠ $message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$message)
    Write-Host "ℹ $message" -ForegroundColor Blue
}

# Main script
Write-Header

# Check if alertmanager.yml exists
if (-not (Test-Path "alertmanager.yml")) {
    Write-Error "alertmanager.yml not found"
    Write-Host "  Use alertmanager-template.yml as a template"
    exit 1
}

# Step 1: Check YAML syntax
Write-Info "Step 1: Checking YAML syntax..."
try {
    $null = docker exec alertmanager amtool config 2>$null
    Write-Success "YAML syntax is valid"
} catch {
    Write-Error "YAML syntax error"
    docker exec alertmanager amtool config 2>&1 | Select-Object -First 20
    exit 1
}

Write-Host ""

# Step 2: Check for webhook configurations
Write-Info "Step 2: Checking for webhook configurations..."

$slackWebhooks = @(Select-String -Path "alertmanager.yml" -Pattern "https://hooks.slack.com" | Measure-Object).Count
if ($slackWebhooks -gt 0) {
    Write-Success "Found $slackWebhooks Slack webhook(s)"
} else {
    Write-Warning "No Slack webhooks found"
}

$pdKeys = @(Select-String -Path "alertmanager.yml" -Pattern "service_key:" | Measure-Object).Count
$pdPlaceholders = @(Select-String -Path "alertmanager.yml" -Pattern "YOUR_PAGERDUTY" | Measure-Object).Count
if ($pdKeys -gt $pdPlaceholders) {
    Write-Success "Found $($pdKeys - $pdPlaceholders) PagerDuty integration key(s)"
} else {
    Write-Warning "PagerDuty key(s) not configured (placeholder only)"
}

Write-Host ""

# Step 3: Check for placeholder values
Write-Info "Step 3: Checking for placeholder values..."

$placeholders = @(Select-String -Path "alertmanager.yml" -Pattern "YOUR_" | Measure-Object).Count
if ($placeholders -gt 0) {
    Write-Warning "Found $placeholders placeholder(s) in config:"
    Select-String -Path "alertmanager.yml" -Pattern "YOUR_" | ForEach-Object {
        Write-Host "  $_"
    }
    Write-Host ""
    Write-Warning "These must be replaced before alerts will be sent"
} else {
    Write-Success "No placeholder values found"
}

Write-Host ""

# Step 4: Check Alertmanager connectivity
Write-Info "Step 4: Checking Alertmanager connectivity..."

try {
    $response = Invoke-WebRequest -Uri "http://localhost:9093/-/healthy" -UseBasicParsing -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Success "Alertmanager is running and healthy"
    } else {
        throw "Invalid response"
    }
} catch {
    Write-Error "Alertmanager is not responding"
    Write-Host "  Start it with: docker start alertmanager"
    exit 1
}

Write-Host ""

# Step 5: Viewing current alerts
Write-Info "Step 5: Viewing current alerts..."

$alerts = docker exec alertmanager amtool alert 2>$null
$alertCount = @($alerts | Measure-Object).Count
Write-Success "Active alerts: $alertCount"
$alerts | Select-Object -First 10

Write-Host ""

# Step 6: Configuration Summary
Write-Info "Step 6: Configuration Summary"

Write-Host "Receivers configured:"
Select-String -Path "alertmanager.yml" -Pattern "name:" | Where-Object { $_ -match "slack|pagerduty|email|webhook" } | ForEach-Object {
    Write-Host "  ✓ $_" 
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($placeholders -gt 0) {
    Write-Warning "1. Update alertmanager.yml with real webhook URLs:"
    Write-Host "   - Follow SLACK_PAGERDUTY_SETUP.md for instructions"
    Write-Host "   - Replace all YOUR_* placeholders with actual values"
    Write-Host ""
    Write-Warning "2. Validate the changes:"
    Write-Host "   - docker cp alertmanager.yml alertmanager:/etc/alertmanager/config.yml"
    Write-Host "   - docker restart alertmanager"
    Write-Host "   - Run this script again"
    Write-Host ""
} else {
    Write-Success "Configuration appears to be complete"
    Write-Host ""
    Write-Info "To test alerting:"
    Write-Host "  1. Generate an error: Invoke-WebRequest http://localhost:8080/invalid"
    Write-Host "  2. Wait for alert to fire (5 minutes)"
    Write-Host "  3. Check Slack channels & PagerDuty"
    Write-Host ""
    Write-Info "To manually trigger alert:"
    Write-Host "  docker exec alertmanager amtool alert add TestAlert severity=critical"
    Write-Host ""
}

Write-Info "Useful commands:"
Write-Host "  View alerts:        docker exec alertmanager amtool alert"
Write-Host "  View config:        docker exec alertmanager amtool config"
Write-Host "  View routes:        docker exec alertmanager amtool config routes"
Write-Host "  View receivers:     docker exec alertmanager amtool config receivers"
Write-Host "  Check logs:         docker logs alertmanager"
Write-Host "  Reload config:      docker restart alertmanager"
Write-Host ""
Write-Info "Documentation:"
Write-Host "  Setup guide: SLACK_PAGERDUTY_SETUP.md"
Write-Host "  Alerting guide: ALERTING_SETUP.md"
Write-Host "  Business metrics: BUSINESS_METRICS_AND_ALERTING.md"
Write-Host ""
