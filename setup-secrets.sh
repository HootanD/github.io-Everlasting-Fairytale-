#!/bin/bash
# GitHub Secrets Setup Script (Linux/macOS)
# Run this locally after authenticating with: gh auth login

set -e

usage() {
  cat << EOF
Usage: $0 \\
  --docker-username USERNAME \\
  --docker-password PASSWORD \\
  [--vps-host HOST] \\
  [--vps-user USER] \\
  [--vps-ssh-key KEY] \\
  [--kube-config CONFIG] \\
  [--slack-webhook URL]

Example:
  $0 \\
    --docker-username myuser \\
    --docker-password 'dckr_pat_xxxxx' \\
    --vps-host 192.168.1.100 \\
    --vps-user ubuntu \\
    --vps-ssh-key "$(cat ~/.ssh/id_rsa | base64 -w 0)"
EOF
  exit 1
}

# Parse arguments
DOCKER_USERNAME=""
DOCKER_PASSWORD=""
VPS_HOST=""
VPS_USER=""
VPS_SSH_KEY=""
KUBE_CONFIG=""
SLACK_WEBHOOK=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --docker-username) DOCKER_USERNAME="$2"; shift 2 ;;
    --docker-password) DOCKER_PASSWORD="$2"; shift 2 ;;
    --vps-host) VPS_HOST="$2"; shift 2 ;;
    --vps-user) VPS_USER="$2"; shift 2 ;;
    --vps-ssh-key) VPS_SSH_KEY="$2"; shift 2 ;;
    --kube-config) KUBE_CONFIG="$2"; shift 2 ;;
    --slack-webhook) SLACK_WEBHOOK="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Validate required arguments
if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
  echo "❌ Docker credentials are required"
  usage
fi

echo "🔐 Setting up GitHub Secrets..." 

# Verify gh CLI is authenticated
if ! gh auth status > /dev/null 2>&1; then
  echo "❌ Not authenticated. Run: gh auth login"
  exit 1
fi

USER=$(gh auth status --json login --jq '.login' 2>/dev/null)
echo "✓ Authenticated as: $USER"

# Set Docker secrets
echo ""
echo "📦 Setting Docker Registry secrets..."
echo "$DOCKER_PASSWORD" | gh secret set DOCKER_PASSWORD
echo "✓ DOCKER_PASSWORD set"

echo "$DOCKER_USERNAME" | gh secret set DOCKER_USERNAME
echo "✓ DOCKER_USERNAME set"

# Set VPS secrets if provided
if [ -n "$VPS_HOST" ] && [ -n "$VPS_USER" ] && [ -n "$VPS_SSH_KEY" ]; then
  echo ""
  echo "🖥️  Setting VPS deployment secrets..."
  echo "$VPS_HOST" | gh secret set VPS_HOST
  echo "✓ VPS_HOST set: $VPS_HOST"
  
  echo "$VPS_USER" | gh secret set VPS_USER
  echo "✓ VPS_USER set: $VPS_USER"
  
  echo "$VPS_SSH_KEY" | gh secret set VPS_SSH_KEY
  echo "✓ VPS_SSH_KEY set"
else
  echo ""
  echo "⚠️  Skipping VPS secrets (not all provided)"
fi

# Set Kubernetes secret if provided
if [ -n "$KUBE_CONFIG" ]; then
  echo ""
  echo "☸️  Setting Kubernetes secrets..."
  echo "$KUBE_CONFIG" | gh secret set KUBE_CONFIG
  echo "✓ KUBE_CONFIG set"
else
  echo ""
  echo "⚠️  Skipping Kubernetes secret (not provided)"
fi

# Set Slack webhook if provided
if [ -n "$SLACK_WEBHOOK" ]; then
  echo ""
  echo "📢 Setting Slack notification webhook..."
  echo "$SLACK_WEBHOOK" | gh secret set SLACK_WEBHOOK_URL
  echo "✓ SLACK_WEBHOOK_URL set"
else
  echo ""
  echo "⚠️  Skipping Slack webhook (not provided)"
fi

# Verify secrets
echo ""
echo "📋 Verifying secrets..."
gh secret list

echo ""
echo "✓ GitHub Secrets Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Verify all secrets listed above"
echo "2. Run: gh workflow run github-branch-protection.yml --ref main"
echo "3. Push changes to main to trigger CI/CD + Canary"
