#!/bin/bash

# Alertmanager Configuration Validator & Setup Helper
# Validates webhook URLs and tests alert routing

set -e

echo "========================================"
echo "Alertmanager Webhook Configuration Tool"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if alertmanager.yml exists
if [ ! -f "alertmanager.yml" ]; then
    echo -e "${RED}✗ alertmanager.yml not found${NC}"
    echo "  Use alertmanager-template.yml as a template"
    exit 1
fi

echo -e "${BLUE}Step 1: Checking YAML syntax...${NC}"
if docker exec alertmanager amtool config > /dev/null 2>&1; then
    echo -e "${GREEN}✓ YAML syntax is valid${NC}"
else
    echo -e "${RED}✗ YAML syntax error${NC}"
    docker exec alertmanager amtool config 2>&1 | head -20
    exit 1
fi

echo ""
echo -e "${BLUE}Step 2: Checking for webhook configurations...${NC}"

# Check Slack webhooks
if grep -q "https://hooks.slack.com" alertmanager.yml; then
    SLACK_COUNT=$(grep -c "https://hooks.slack.com" alertmanager.yml)
    echo -e "${GREEN}✓ Found ${SLACK_COUNT} Slack webhook(s)${NC}"
else
    echo -e "${YELLOW}⚠ No Slack webhooks found${NC}"
fi

# Check PagerDuty keys
if grep -q "service_key:" alertmanager.yml; then
    PD_KEYS=$(grep "service_key:" alertmanager.yml | grep -v "YOUR_" | wc -l)
    if [ "$PD_KEYS" -gt 0 ]; then
        echo -e "${GREEN}✓ Found ${PD_KEYS} PagerDuty integration key(s)${NC}"
    else
        echo -e "${YELLOW}⚠ PagerDuty key(s) not configured (placeholder only)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No PagerDuty configuration found${NC}"
fi

echo ""
echo -e "${BLUE}Step 3: Checking for placeholder values...${NC}"

PLACEHOLDERS=$(grep -c "YOUR_" alertmanager.yml || true)
if [ "$PLACEHOLDERS" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Warning: Found ${PLACEHOLDERS} placeholder(s) in config:${NC}"
    grep "YOUR_" alertmanager.yml | sed 's/^/  /'
    echo ""
    echo -e "${YELLOW}  ⚠ These must be replaced before alerts will be sent${NC}"
else
    echo -e "${GREEN}✓ No placeholder values found${NC}"
fi

echo ""
echo -e "${BLUE}Step 4: Checking Alertmanager connectivity...${NC}"

if curl -s http://localhost:9093/-/healthy > /dev/null; then
    echo -e "${GREEN}✓ Alertmanager is running and healthy${NC}"
else
    echo -e "${RED}✗ Alertmanager is not responding${NC}"
    echo "  Start it with: docker start alertmanager"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 5: Viewing current alerts...${NC}"

ALERT_COUNT=$(docker exec alertmanager amtool alert | wc -l || true)
echo -e "${GREEN}✓ Active alerts: ${ALERT_COUNT}${NC}"
docker exec alertmanager amtool alert | head -10

echo ""
echo -e "${BLUE}Step 6: Configuration Summary${NC}"

echo "Receivers configured:"
grep "name:" alertmanager.yml | grep -E "slack|pagerduty|email|webhook" | sed "s/^/  /" | sed "s/  - name: /  ✓ /"

echo ""
echo "Routes configured:"
docker exec alertmanager amtool config routes | head -10

echo ""
echo "========================================"
echo "NEXT STEPS:"
echo "========================================"
echo ""

if grep -q "YOUR_" alertmanager.yml; then
    echo -e "${YELLOW}1. Update alertmanager.yml with real webhook URLs:${NC}"
    echo "   - Follow SLACK_PAGERDUTY_SETUP.md for instructions"
    echo "   - Replace all YOUR_* placeholders with actual values"
    echo ""
    echo -e "${YELLOW}2. Validate the changes:${NC}"
    echo "   - docker cp alertmanager.yml alertmanager:/etc/alertmanager/config.yml"
    echo "   - docker restart alertmanager"
    echo "   - Run this script again"
    echo ""
else
    echo -e "${GREEN}✓ Configuration appears to be complete${NC}"
    echo ""
    echo -e "${BLUE}To test alerting:${NC}"
    echo "  1. Generate an error: curl http://localhost:8080/invalid"
    echo "  2. Wait for alert to fire (5 minutes)"
    echo "  3. Check Slack channels & PagerDuty"
    echo ""
    echo -e "${BLUE}To manually trigger alert:${NC}"
    echo "  docker exec alertmanager amtool alert add TestAlert severity=critical"
    echo ""
fi

echo -e "${BLUE}Useful commands:${NC}"
echo "  View alerts:        docker exec alertmanager amtool alert"
echo "  View config:        docker exec alertmanager amtool config"
echo "  View routes:        docker exec alertmanager amtool config routes"
echo "  View receivers:     docker exec alertmanager amtool config receivers"
echo "  Check logs:         docker logs alertmanager"
echo "  Reload config:      docker restart alertmanager"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "  Setup guide: SLACK_PAGERDUTY_SETUP.md"
echo "  Alerting guide: ALERTING_SETUP.md"
echo "  Business metrics: BUSINESS_METRICS_AND_ALERTING.md"
echo ""
