#!/usr/bin/env pwsh
# GitHub Secrets Setup Script
# Run this locally after authenticating with: gh auth login

param(
    [Parameter(Mandatory=$true)]
    [string]$DockerUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$DockerPassword,
    
    [Parameter(Mandatory=$false)]
    [string]$VpsHost,
    
    [Parameter(Mandatory=$false)]
    [string]$VpsUser,
    
    [Parameter(Mandatory=$false)]
    [string]$VpsSshKey,
    
    [Parameter(Mandatory=$false)]
    [string]$KubeConfig,
    
    [Parameter(Mandatory=$false)]
    [string]$SlackWebhook
)

Write-Host "🔐 Setting up GitHub Secrets..." -ForegroundColor Cyan

# Verify gh CLI is authenticated
try {
    $user = gh auth status --json login --jq '.login' 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Not authenticated. Run: gh auth login" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Authenticated as: $user" -ForegroundColor Green
} catch {
    Write-Host "❌ gh CLI error: $_" -ForegroundColor Red
    exit 1
}

# Set Docker secrets
Write-Host "`n📦 Setting Docker Registry secrets..." -ForegroundColor Cyan
gh secret set DOCKER_USERNAME --body "$DockerUsername" 2>&1
if ($LASTEXITCODE -eq 0) { Write-Host "✓ DOCKER_USERNAME set" -ForegroundColor Green } else { Write-Host "✗ Failed to set DOCKER_USERNAME" -ForegroundColor Red }

gh secret set DOCKER_PASSWORD --body "$DockerPassword" 2>&1
if ($LASTEXITCODE -eq 0) { Write-Host "✓ DOCKER_PASSWORD set" -ForegroundColor Green } else { Write-Host "✗ Failed to set DOCKER_PASSWORD" -ForegroundColor Red }

# Set VPS secrets if provided
if ($VpsHost -and $VpsUser -and $VpsSshKey) {
    Write-Host "`n🖥️  Setting VPS deployment secrets..." -ForegroundColor Cyan
    
    gh secret set VPS_HOST --body "$VpsHost" 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Host "✓ VPS_HOST set: $VpsHost" -ForegroundColor Green } else { Write-Host "✗ Failed to set VPS_HOST" -ForegroundColor Red }
    
    gh secret set VPS_USER --body "$VpsUser" 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Host "✓ VPS_USER set: $VpsUser" -ForegroundColor Green } else { Write-Host "✗ Failed to set VPS_USER" -ForegroundColor Red }
    
    gh secret set VPS_SSH_KEY --body "$VpsSshKey" 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Host "✓ VPS_SSH_KEY set" -ForegroundColor Green } else { Write-Host "✗ Failed to set VPS_SSH_KEY" -ForegroundColor Red }
} else {
    Write-Host "`n⚠️  Skipping VPS secrets (not all provided)" -ForegroundColor Yellow
}

# Set Kubernetes secret if provided
if ($KubeConfig) {
    Write-Host "`n☸️  Setting Kubernetes secrets..." -ForegroundColor Cyan
    
    gh secret set KUBE_CONFIG --body "$KubeConfig" 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Host "✓ KUBE_CONFIG set" -ForegroundColor Green } else { Write-Host "✗ Failed to set KUBE_CONFIG" -ForegroundColor Red }
} else {
    Write-Host "`n⚠️  Skipping Kubernetes secret (not provided)" -ForegroundColor Yellow
}

# Set Slack webhook if provided
if ($SlackWebhook) {
    Write-Host "`n📢 Setting Slack notification webhook..." -ForegroundColor Cyan
    
    gh secret set SLACK_WEBHOOK_URL --body "$SlackWebhook" 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Host "✓ SLACK_WEBHOOK_URL set" -ForegroundColor Green } else { Write-Host "✗ Failed to set SLACK_WEBHOOK_URL" -ForegroundColor Red }
} else {
    Write-Host "`n⚠️  Skipping Slack webhook (not provided)" -ForegroundColor Yellow
}

# Verify secrets
Write-Host "`n📋 Verifying secrets..." -ForegroundColor Cyan
gh secret list

Write-Host "`n✓ GitHub Secrets Setup Complete!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Verify all secrets listed above"
Write-Host "2. Run: gh workflow run github-branch-protection.yml --ref main"
Write-Host "3. Push changes to main to trigger CI/CD + Canary"
