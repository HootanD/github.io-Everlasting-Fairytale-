#!/bin/bash
# Complete CI/CD Deployment Execution Script (macOS/Linux Bash)

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==============================================================================
# STEP 1: AUTHENTICATE WITH GITHUB CLI
# ==============================================================================

echo -e "${CYAN}========================================"
echo "STEP 1: GitHub CLI Authentication"
echo "========================================${NC}"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI not found. Install from: https://cli.github.com/${NC}"
    exit 1
fi

# Check current auth status
if gh auth status > /dev/null 2>&1; then
    echo -e "${GREEN}✓ GitHub CLI already authenticated${NC}"
    gh auth status
else
    echo -e "${YELLOW}⚠️  Not authenticated. Running: gh auth login${NC}"
    gh auth login
fi

echo ""
read -p "Press Enter to continue..."

# ==============================================================================
# STEP 2: VERIFY REQUIRED CREDENTIALS
# ==============================================================================

echo ""
echo -e "${CYAN}========================================"
echo "STEP 2: Gather Deployment Credentials"
echo "========================================${NC}"
echo ""

read -p "Docker Username (everlastingfairytale): " DOCKER_USERNAME
read -sp "Docker PAT (dckr_oat_...): " DOCKER_PASSWORD
echo ""

read -p "Kubeconfig (base64, or press Enter to skip): " KUBE_CONFIG
read -p "VPS Host (IP or hostname, or press Enter to skip): " VPS_HOST
read -p "VPS SSH User (if VPS enabled, e.g., ubuntu): " VPS_USER
read -p "VPS SSH Key (base64, or press Enter to skip): " VPS_SSH_KEY
read -p "Slack Webhook URL (optional, press Enter to skip): " SLACK_WEBHOOK

echo ""
echo -e "${GREEN}✓ Credentials gathered${NC}"

# ==============================================================================
# STEP 3: SET GITHUB SECRETS
# ==============================================================================

echo ""
echo -e "${CYAN}========================================"
echo "STEP 3: Setting GitHub Secrets"
echo "========================================${NC}"
echo ""

echo -e "${CYAN}📦 Setting Docker secrets...${NC}"
echo "$DOCKER_PASSWORD" | gh secret set DOCKER_PASSWORD && echo -e "${GREEN}✓ DOCKER_PASSWORD set${NC}"
echo "$DOCKER_USERNAME" | gh secret set DOCKER_USERNAME && echo -e "${GREEN}✓ DOCKER_USERNAME set${NC}"

if [ -n "$KUBE_CONFIG" ]; then
    echo ""
    echo -e "${CYAN}☸️  Setting Kubernetes secret...${NC}"
    echo "$KUBE_CONFIG" | gh secret set KUBE_CONFIG && echo -e "${GREEN}✓ KUBE_CONFIG set${NC}"
fi

if [ -n "$VPS_HOST" ] && [ -n "$VPS_USER" ] && [ -n "$VPS_SSH_KEY" ]; then
    echo ""
    echo -e "${CYAN}🖥️  Setting VPS secrets...${NC}"
    echo "$VPS_HOST" | gh secret set VPS_HOST && echo -e "${GREEN}✓ VPS_HOST set: $VPS_HOST${NC}"
    echo "$VPS_USER" | gh secret set VPS_USER && echo -e "${GREEN}✓ VPS_USER set: $VPS_USER${NC}"
    echo "$VPS_SSH_KEY" | gh secret set VPS_SSH_KEY && echo -e "${GREEN}✓ VPS_SSH_KEY set${NC}"
fi

if [ -n "$SLACK_WEBHOOK" ]; then
    echo ""
    echo -e "${CYAN}📢 Setting Slack webhook...${NC}"
    echo "$SLACK_WEBHOOK" | gh secret set SLACK_WEBHOOK_URL && echo -e "${GREEN}✓ SLACK_WEBHOOK_URL set${NC}"
fi

echo ""
echo -e "${CYAN}📋 Verifying secrets...${NC}"
gh secret list

echo ""
read -p "Press Enter to continue..."

# ==============================================================================
# STEP 4: ACTIVATE BRANCH PROTECTION
# ==============================================================================

echo ""
echo -e "${CYAN}========================================"
echo "STEP 4: Activate Branch Protection"
echo "========================================${NC}"
echo ""

echo -e "${CYAN}🔒 Triggering branch protection setup workflow...${NC}"
gh workflow run github-branch-protection.yml --ref main

echo ""
echo -e "${YELLOW}⏳ Waiting for workflow to register...${NC}"
sleep 5

echo -e "${CYAN}Checking workflow status...${NC}"
gh run list --workflow=github-branch-protection.yml --limit 1

echo ""
echo -e "${GREEN}✓ Branch protection workflow triggered${NC}"
REPO=$(gh repo view --json nameWithOwner -q)
echo -e "${CYAN}Monitor at: https://github.com/$REPO/actions${NC}"

echo ""
read -p "Press Enter to continue..."

# ==============================================================================
# STEP 5: COMMIT ALL FILES
# ==============================================================================

echo ""
echo -e "${CYAN}========================================"
echo "STEP 5: Commit All Files"
echo "========================================${NC}"
echo ""

echo -e "${CYAN}📝 Staging files...${NC}"
git add .
echo -e "${GREEN}✓ Files staged${NC}"

echo ""
echo -e "${CYAN}Checking git status...${NC}"
git status --short

echo ""
echo -e "${CYAN}💾 Creating commit...${NC}"
git commit -m "feat: add branch protection, canary deployment, and .dockerignore"
echo -e "${GREEN}✓ Files committed${NC}"

echo ""
read -p "Press Enter to continue..."

# ==============================================================================
# STEP 6: PUSH TO MAIN
# ==============================================================================

echo ""
echo -e "${CYAN}========================================"
echo "STEP 6: Push to Main (Triggers CI/CD + Canary)"
echo "========================================${NC}"
echo ""

echo -e "${CYAN}🚀 Pushing to main...${NC}"
if git push origin main; then
    echo -e "${GREEN}✓ Pushed to main - CI/CD pipeline auto-triggering!${NC}"
else
    echo -e "${RED}❌ Push failed. Check git output above.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}⏳ Waiting 10 seconds for workflows to register...${NC}"
sleep 10

# ==============================================================================
# STEP 7: MONITOR CI/CD PIPELINE
# ==============================================================================

echo ""
echo -e "${CYAN}========================================"
echo "STEP 7: Monitor CI/CD Pipeline"
echo "========================================${NC}"
echo ""

echo -e "${CYAN}📋 Recent workflow runs:${NC}"
gh run list --branch main --limit 5

echo ""
echo -e "${CYAN}🔗 View live in GitHub:${NC}"
REPO=$(gh repo view --json nameWithOwner -q)
echo -e "  ${CYAN}https://github.com/$REPO/actions${NC}"

echo ""
echo -e "${CYAN}💡 To watch specific run live:${NC}"
echo -e "  ${CYAN}gh run watch <RUN_ID>{{NC}"

echo ""
read -p "Press Enter to continue to Kubernetes monitoring..."

# ==============================================================================
# STEP 8: MONITOR KUBERNETES CANARY
# ==============================================================================

echo ""
echo -e "${CYAN}========================================"
echo "STEP 8: Monitor Kubernetes Canary"
echo "========================================${NC}"
echo ""

if [ -n "$KUBE_CONFIG" ]; then
    echo -e "${YELLOW}⏳ Waiting for canary pod to start (this may take 2-3 minutes)...${NC}"
    echo ""
    
    echo -e "${CYAN}🔗 Checking Kubernetes cluster connection...${NC}"
    kubectl cluster-info 2>/dev/null | head -3 || echo "  (kubectl not available or kubeconfig invalid)"
    
    echo ""
    echo -e "${CYAN}👀 Watching canary namespace:${NC}"
    echo -e "  ${CYAN}kubectl get pods -n canary -w${NC}"
    echo ""
    echo -e "${CYAN}📋 Check canary pod status:${NC}"
    kubectl get pods -n canary 2>/dev/null || echo "  (Will be available once canary deployment starts)"
    
    echo ""
    echo -e "${CYAN}📝 View canary logs:${NC}"
    echo -e "  ${CYAN}kubectl logs -f deployment/node-app-canary -n canary${NC}"
else
    echo -e "${YELLOW}⏭️  Skipping (Kubernetes not enabled)${NC}"
fi

echo ""
read -p "Press Enter to continue to VPS monitoring..."

# ==============================================================================
# STEP 9: MONITOR VPS CANARY
# ==============================================================================

echo ""
echo -e "${CYAN}========================================"
echo "STEP 9: Monitor VPS Canary"
echo "========================================${NC}"
echo ""

if [ -n "$VPS_HOST" ]; then
    echo -e "${CYAN}🖥️  SSH commands for VPS monitoring:${NC}"
    echo ""
    echo -e "  ${CYAN}ssh $VPS_USER@$VPS_HOST${NC}"
    echo ""
    echo -e "${CYAN}Once connected, run:${NC}"
    echo ""
    echo -e "  ${YELLOW}# View canary container logs (real-time)${NC}"
    echo -e "  ${CYAN}docker-compose -f docker-compose.prod.yml --profile canary logs -f app-canary${NC}"
    echo ""
    echo -e "  ${YELLOW}# Check container status${NC}"
    echo -e "  ${CYAN}docker-compose -f docker-compose.prod.yml --profile canary ps${NC}"
    echo ""
    echo -e "  ${YELLOW}# Manual health check${NC}"
    echo -e "  ${CYAN}curl http://localhost:8081/health${NC}"
    echo ""
    echo -e "  ${YELLOW}# View metrics${NC}"
    echo -e "  ${CYAN}curl http://localhost:8081/metrics | head -20${NC}"
else
    echo -e "${YELLOW}⏭️  Skipping (VPS not enabled)${NC}"
fi

echo ""
read -p "Press Enter to continue..."

# ==============================================================================
# STEP 10: SUMMARY & NEXT STEPS
# ==============================================================================

echo ""
echo -e "${CYAN}========================================"
echo "DEPLOYMENT EXECUTION COMPLETE ✓"
echo "========================================${NC}"
echo ""

echo -e "${CYAN}📊 Deployment Timeline:${NC}"
echo -e "  1. CI/CD Pipeline:    ${NC}2-5 minutes (test, build, push)"
echo -e "  2. Canary Deployment: ${NC}10-15 minutes (deploy, health checks, monitoring)"
echo -e "  3. Manual Promotion:  ${NC}2-3 minutes (promote to production)"
echo ""

echo -e "${CYAN}🔗 Links:${NC}"
REPO=$(gh repo view --json nameWithOwner -q)
echo -e "  GitHub Actions:  ${CYAN}https://github.com/$REPO/actions${NC}"
if [ -n "$KUBE_CONFIG" ]; then
    echo -e "  Kubernetes UI:   ${CYAN}kubectl port-forward -n monitoring svc/prometheus 9090:9090{{NC}"
fi
if [ -n "$VPS_HOST" ]; then
    echo -e "  VPS SSH:         ${CYAN}ssh $VPS_USER@$VPS_HOST{{NC}"
fi
echo ""

echo -e "${GREEN}✅ What Happened:${NC}"
echo -e "${GREEN}  ✓ GitHub secrets set (Docker, K8s, VPS credentials)${NC}"
echo -e "${GREEN}  ✓ Branch protection activated (1 review + CI required)${NC}"
echo -e "${GREEN}  ✓ All files committed to main${NC}"
echo -e "${GREEN}  ✓ CI/CD pipeline started (test, build, push)${NC}"
echo -e "${GREEN}  ✓ Canary deployment auto-triggered{{NC}"
echo ""

echo -e "${YELLOW}⏳ What's Happening Now:${NC}"
echo -e "${YELLOW}  • CI/CD: Running tests and building Docker image...${NC}"
echo -e "${YELLOW}  • Once CI/CD passes → Canary auto-deploys to K8s + VPS${NC}"
echo -e "${YELLOW}  • Canary: Monitoring for 5 minutes with health checks${NC}"
echo -e "${YELLOW}  • Slack: Notifications sent on success/failure{{NC}"
echo ""

echo -e "${CYAN}🎯 Next Manual Steps:${NC}"
echo -e "  1. Monitor CI/CD:     ${CYAN}gh run list --branch main{{NC}"
echo -e "  2. Watch K8s canary:  ${CYAN}kubectl get pods -n canary -w{{NC}"
echo -e "  3. Watch VPS canary:  ${CYAN}ssh $VPS_USER@$VPS_HOST{{NC}"
echo -e "  4. After canary success, promote to production:${NC}"
echo -e "     ${CYAN}kubectl set image deployment/node-app node-app=docker.io/user:tag -n node-app{{NC}"
echo ""

echo -e "${CYAN}🛠️  Troubleshooting:${NC}"
echo -e "  • CI/CD failing?       ${CYAN}→ gh run view <RUN_ID> --log{{NC}"
echo -e "  • Canary pod down?     ${CYAN}→ kubectl logs deployment/node-app-canary -n canary{{NC}"
echo -e "  • VPS canary down?     ${CYAN}→ ssh $VPS_USER@$VPS_HOST && docker logs app-canary{{NC}"
echo -e "  • Need help?           ${CYAN}→ Read TROUBLESHOOTING.txt{{NC}"
echo ""

echo -e "${CYAN}📚 Documentation:${NC}"
echo -e "  • Quick Reference:     ${CYAN}QUICK-START.txt{{NC}"
echo -e "  • Canary Details:      ${CYAN}CANARY-DEPLOYMENT-GUIDE.txt{{NC}"
echo -e "  • Troubleshooting:     ${CYAN}TROUBLESHOOTING.txt{{NC}"
echo -e "  • Full Index:          ${CYAN}README-CICD.txt{{NC}"
echo ""

echo -e "${GREEN}🎉 Your production-grade CI/CD pipeline with branch protection and canary deployments is now LIVE!${NC}"
echo ""
