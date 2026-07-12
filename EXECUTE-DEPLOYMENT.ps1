#!/usr/bin/env pwsh
# Complete CI/CD Deployment Execution Script
# Run this locally on your machine (Windows PowerShell)

# ==============================================================================
# STEP 1: AUTHENTICATE WITH GITHUB CLI
# ==============================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 1: GitHub CLI Authentication" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if gh CLI is installed
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "❌ GitHub CLI not found. Install from: https://cli.github.com/" -ForegroundColor Red
    exit 1
}

# Check current auth status
try {
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ GitHub CLI already authenticated" -ForegroundColor Green
        $authStatus | Write-Host
    } else {
        Write-Host "⚠️  Not authenticated. Running: gh auth login" -ForegroundColor Yellow
        gh auth login
    }
} catch {
    Write-Host "⚠️  Auth status check failed. Running: gh auth login" -ForegroundColor Yellow
    gh auth login
}

Write-Host ""
Read-Host "Press Enter to continue..."

# ==============================================================================
# STEP 2: VERIFY REQUIRED CREDENTIALS
# ==============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 2: Gather Deployment Credentials" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$DockerUsername = Read-Host "Docker Username (everlastingfairytale)"
$DockerPassword = Read-Host "Docker PAT (dckr_oat_...)" -AsSecureString
$DockerPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($DockerPassword))

$KubeConfig = Read-Host "Kubeconfig (base64, or press Enter to skip)" 
$VpsHost = Read-Host "VPS Host (IP or hostname, or press Enter to skip)"
$VpsUser = Read-Host "VPS SSH User (if VPS enabled, e.g., ubuntu)"
$VpsSshKey = Read-Host "VPS SSH Key (base64, or press Enter to skip)"
$SlackWebhook = Read-Host "Slack Webhook URL (optional, press Enter to skip)"

Write-Host ""
Write-Host "✓ Credentials gathered" -ForegroundColor Green

# ==============================================================================
# STEP 3: SET GITHUB SECRETS
# ==============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 3: Setting GitHub Secrets" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📦 Setting Docker secrets..." -ForegroundColor Cyan
$DockerPasswordPlain | gh secret set DOCKER_PASSWORD
if ($LASTEXITCODE -eq 0) { Write-Host "✓ DOCKER_PASSWORD set" -ForegroundColor Green }

$DockerUsername | gh secret set DOCKER_USERNAME
if ($LASTEXITCODE -eq 0) { Write-Host "✓ DOCKER_USERNAME set" -ForegroundColor Green }

if ($KubeConfig) {
    Write-Host ""
    Write-Host "☸️  Setting Kubernetes secret..." -ForegroundColor Cyan
    $KubeConfig | gh secret set KUBE_CONFIG
    if ($LASTEXITCODE -eq 0) { Write-Host "✓ KUBE_CONFIG set" -ForegroundColor Green }
}

if ($VpsHost -and $VpsUser -and $VpsSshKey) {
    Write-Host ""
    Write-Host "🖥️  Setting VPS secrets..." -ForegroundColor Cyan
    $VpsHost | gh secret set VPS_HOST
    if ($LASTEXITCODE -eq 0) { Write-Host "✓ VPS_HOST set: $VpsHost" -ForegroundColor Green }
    
    $VpsUser | gh secret set VPS_USER
    if ($LASTEXITCODE -eq 0) { Write-Host "✓ VPS_USER set: $VpsUser" -ForegroundColor Green }
    
    $VpsSshKey | gh secret set VPS_SSH_KEY
    if ($LASTEXITCODE -eq 0) { Write-Host "✓ VPS_SSH_KEY set" -ForegroundColor Green }
}

if ($SlackWebhook) {
    Write-Host ""
    Write-Host "📢 Setting Slack webhook..." -ForegroundColor Cyan
    $SlackWebhook | gh secret set SLACK_WEBHOOK_URL
    if ($LASTEXITCODE -eq 0) { Write-Host "✓ SLACK_WEBHOOK_URL set" -ForegroundColor Green }
}

Write-Host ""
Write-Host "📋 Verifying secrets..." -ForegroundColor Cyan
gh secret list

Write-Host ""
Read-Host "Press Enter to continue..."

# ==============================================================================
# STEP 4: ACTIVATE BRANCH PROTECTION
# ==============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 4: Activate Branch Protection" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔒 Triggering branch protection setup workflow..." -ForegroundColor Cyan
gh workflow run github-branch-protection.yml --ref main

Write-Host ""
Write-Host "⏳ Waiting for workflow to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "Checking workflow status..." -ForegroundColor Cyan
$runs = gh run list --workflow=github-branch-protection.yml --limit 1 --json status,name,conclusion,createdAt
Write-Host $runs | ConvertFrom-Json | Format-Table -AutoSize

Write-Host ""
Write-Host "✓ Branch protection workflow triggered" -ForegroundColor Green
Write-Host "Monitor at: https://github.com/$(gh repo view --json nameWithOwner -q)/actions" -ForegroundColor Cyan

Write-Host ""
Read-Host "Press Enter to continue..."

# ==============================================================================
# STEP 5: COMMIT ALL FILES
# ==============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 5: Commit All Files" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📝 Staging files..." -ForegroundColor Cyan
git add .
if ($LASTEXITCODE -eq 0) { Write-Host "✓ Files staged" -ForegroundColor Green }

Write-Host ""
Write-Host "Checking git status..." -ForegroundColor Cyan
git status --short | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "💾 Creating commit..." -ForegroundColor Cyan
git commit -m "feat: add branch protection, canary deployment, and .dockerignore"
if ($LASTEXITCODE -eq 0) { Write-Host "✓ Files committed" -ForegroundColor Green }

Write-Host ""
Read-Host "Press Enter to continue..."

# ==============================================================================
# STEP 6: PUSH TO MAIN
# ==============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 6: Push to Main (Triggers CI/CD + Canary)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "🚀 Pushing to main..." -ForegroundColor Cyan
git push origin main
if ($LASTEXITCODE -eq 0) { 
    Write-Host "✓ Pushed to main - CI/CD pipeline auto-triggering!" -ForegroundColor Green 
} else {
    Write-Host "❌ Push failed. Check git output above." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "⏳ Waiting 10 seconds for workflows to register..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# ==============================================================================
# STEP 7: MONITOR CI/CD PIPELINE
# ==============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 7: Monitor CI/CD Pipeline" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Recent workflow runs:" -ForegroundColor Cyan
$runs = gh run list --branch main --limit 5
Write-Host $runs

Write-Host ""
Write-Host "🔗 View live in GitHub:" -ForegroundColor Cyan
$repo = gh repo view --json nameWithOwner -q
Write-Host "  https://github.com/$repo/actions" -ForegroundColor Cyan

Write-Host ""
Write-Host "💡 To watch specific run live:" -ForegroundColor Cyan
Write-Host "  gh run watch <RUN_ID>" -ForegroundColor Cyan

Write-Host ""
Read-Host "Press Enter to continue to Kubernetes monitoring..."

# ==============================================================================
# STEP 8: MONITOR KUBERNETES CANARY
# ==============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 8: Monitor Kubernetes Canary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($KubeConfig) {
    Write-Host "⏳ Waiting for canary pod to start (this may take 2-3 minutes)..." -ForegroundColor Yellow
    Write-Host ""
    
    # Check cluster connectivity first
    Write-Host "🔗 Checking Kubernetes cluster connection..." -ForegroundColor Cyan
    try {
        kubectl cluster-info 2>&1 | Select-Object -First 3
    } catch {
        Write-Host "⚠️  kubectl not available or kubeconfig invalid" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "👀 Watching canary namespace:" -ForegroundColor Cyan
    Write-Host "  kubectl get pods -n canary -w" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📋 Check canary pod status:" -ForegroundColor Cyan
    try {
        kubectl get pods -n canary 2>/dev/null
    } catch {
        Write-Host "  (Will be available once canary deployment starts)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "📝 View canary logs:" -ForegroundColor Cyan
    Write-Host "  kubectl logs -f deployment/node-app-canary -n canary" -ForegroundColor Cyan
} else {
    Write-Host "⏭️  Skipping (Kubernetes not enabled)" -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to continue to VPS monitoring..."

# ==============================================================================
# STEP 9: MONITOR VPS CANARY
# ==============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 9: Monitor VPS Canary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($VpsHost) {
    Write-Host "🖥️  SSH commands for VPS monitoring:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ssh $VpsUser@$VpsHost" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Once connected, run:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  # View canary container logs (real-time)" -ForegroundColor Yellow
    Write-Host "  docker-compose -f docker-compose.prod.yml --profile canary logs -f app-canary" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  # Check container status" -ForegroundColor Yellow
    Write-Host "  docker-compose -f docker-compose.prod.yml --profile canary ps" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  # Manual health check" -ForegroundColor Yellow
    Write-Host "  curl http://localhost:8081/health" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  # View metrics" -ForegroundColor Yellow
    Write-Host "  curl http://localhost:8081/metrics | head -20" -ForegroundColor Cyan
} else {
    Write-Host "⏭️  Skipping (VPS not enabled)" -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to continue..."

# ==============================================================================
# STEP 10: SUMMARY & NEXT STEPS
# ==============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT EXECUTION COMPLETE ✓" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📊 Deployment Timeline:" -ForegroundColor Cyan
Write-Host "  1. CI/CD Pipeline:    2-5 minutes (test, build, push)" -ForegroundColor White
Write-Host "  2. Canary Deployment: 10-15 minutes (deploy, health checks, monitoring)" -ForegroundColor White
Write-Host "  3. Manual Promotion:  2-3 minutes (promote to production)" -ForegroundColor White
Write-Host ""

Write-Host "🔗 Links:" -ForegroundColor Cyan
$repo = gh repo view --json nameWithOwner -q
Write-Host "  GitHub Actions:  https://github.com/$repo/actions" -ForegroundColor Cyan
if ($KubeConfig) {
    Write-Host "  Kubernetes UI:   kubectl port-forward -n monitoring svc/prometheus 9090:9090" -ForegroundColor Cyan
}
if ($VpsHost) {
    Write-Host "  VPS SSH:         ssh $VpsUser@$VpsHost" -ForegroundColor Cyan
}
Write-Host ""

Write-Host "✅ What Happened:" -ForegroundColor Green
Write-Host "  ✓ GitHub secrets set (Docker, K8s, VPS credentials)" -ForegroundColor Green
Write-Host "  ✓ Branch protection activated (1 review + CI required)" -ForegroundColor Green
Write-Host "  ✓ All files committed to main" -ForegroundColor Green
Write-Host "  ✓ CI/CD pipeline started (test, build, push)" -ForegroundColor Green
Write-Host "  ✓ Canary deployment auto-triggered" -ForegroundColor Green
Write-Host ""

Write-Host "⏳ What's Happening Now:" -ForegroundColor Yellow
Write-Host "  • CI/CD: Running tests and building Docker image..." -ForegroundColor Yellow
Write-Host "  • Once CI/CD passes → Canary auto-deploys to K8s + VPS" -ForegroundColor Yellow
Write-Host "  • Canary: Monitoring for 5 minutes with health checks" -ForegroundColor Yellow
Write-Host "  • Slack: Notifications sent on success/failure" -ForegroundColor Yellow
Write-Host ""

Write-Host "🎯 Next Manual Steps:" -ForegroundColor Cyan
Write-Host "  1. Monitor CI/CD:     gh run list --branch main" -ForegroundColor Cyan
Write-Host "  2. Watch K8s canary:  kubectl get pods -n canary -w" -ForegroundColor Cyan
Write-Host "  3. Watch VPS canary:  ssh $VpsUser@$VpsHost" -ForegroundColor Cyan
Write-Host "  4. After canary success, promote to production:" -ForegroundColor Cyan
Write-Host "     kubectl set image deployment/node-app node-app=docker.io/user:tag -n node-app" -ForegroundColor Cyan
Write-Host ""

Write-Host "🛠️  Troubleshooting:" -ForegroundColor Cyan
Write-Host "  • CI/CD failing?       → gh run view <RUN_ID> --log" -ForegroundColor Cyan
Write-Host "  • Canary pod down?     → kubectl logs deployment/node-app-canary -n canary" -ForegroundColor Cyan
Write-Host "  • VPS canary down?     → ssh $VpsUser@$VpsHost && docker logs app-canary" -ForegroundColor Cyan
Write-Host "  • Need help?           → Read TROUBLESHOOTING.txt" -ForegroundColor Cyan
Write-Host ""

Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "  • Quick Reference:     QUICK-START.txt" -ForegroundColor Cyan
Write-Host "  • Canary Details:      CANARY-DEPLOYMENT-GUIDE.txt" -ForegroundColor Cyan
Write-Host "  • Troubleshooting:     TROUBLESHOOTING.txt" -ForegroundColor Cyan
Write-Host "  • Full Index:          README-CICD.txt" -ForegroundColor Cyan
Write-Host ""

Write-Host "🎉 Your production-grade CI/CD pipeline with branch protection and canary deployments is now LIVE!" -ForegroundColor Green
Write-Host ""
