#!/bin/bash
# CI/CD Quick Reference - Copy & paste commands

# ============================================================================
# SETUP
# ============================================================================

# Set Slack webhook (optional but recommended for notifications)
gh secret set SLACK_WEBHOOK_URL

# View all secrets
gh secret list

# ============================================================================
# TRIGGER WORKFLOWS
# ============================================================================

# Lint & Test (automatic on push to main/develop)
git push origin develop

# Build & Push Image (automatic on push to main/develop/tags)
git push origin main

# Deploy to Staging (automatic when pushing to develop)
git push origin develop

# Deploy to Production (manual, via GitHub UI or CLI)
gh workflow run deploy-prod.yml \
  -f deployment_strategy=rolling \
  -f image_tag=latest

# ============================================================================
# MONITOR WORKFLOWS
# ============================================================================

# List recent runs (main branch)
gh run list --branch main --limit 10

# View specific run
gh run view <RUN_ID>

# View run logs (full)
gh run view <RUN_ID> --log

# Watch run live
gh run watch <RUN_ID>

# Get run status
gh run view <RUN_ID> --json status -q

# ============================================================================
# IMAGE MANAGEMENT
# ============================================================================

# Log in to container registry
docker login ghcr.io

# Pull image
docker pull ghcr.io/<owner>/<repo>:latest

# List images
gh api repos/<owner>/<repo>/packages --paginate

# View image tags
gh api repos/<owner>/<repo>/packages | jq '.[] | select(.package_type=="container") | .name'

# ============================================================================
# DEPLOYMENT
# ============================================================================

# Deploy with rolling strategy
gh workflow run deploy-prod.yml \
  -f deployment_strategy=rolling \
  -f image_tag=latest

# Deploy with blue-green strategy
gh workflow run deploy-prod.yml \
  -f deployment_strategy=blue-green \
  -f image_tag=latest

# Deploy with canary strategy
gh workflow run deploy-prod.yml \
  -f deployment_strategy=canary \
  -f image_tag=latest

# Deploy specific version
gh workflow run deploy-prod.yml \
  -f deployment_strategy=rolling \
  -f image_tag=v1.2.3

# ============================================================================
# TROUBLESHOOTING
# ============================================================================

# Show failed workflows
gh run list --branch main --status failure --limit 5

# Show last 5 runs on develop
gh run list --branch develop --limit 5

# Detailed failure info
gh run view <RUN_ID> --log | grep -i error

# Retry failed workflow
gh run rerun <RUN_ID>

# ============================================================================
# BRANCH PROTECTION
# ============================================================================

# View branch protection rules
gh api repos/<owner>/<repo>/branches/main/protection

# Require CI/CD for main
gh api repos/<owner>/<repo>/branches/main/protection \
  -f required_status_checks='{"strict":true,"contexts":["test","docker-build-push"]}' \
  -f require_code_reviews='{"dismissal_restrictions":{},"require_code_owner_reviews":true}'

# ============================================================================
# ARTIFACT MANAGEMENT
# ============================================================================

# Download test coverage
gh run download <RUN_ID> -n test-coverage

# List artifacts from recent run
gh run view <RUN_ID> --json artifacts

# ============================================================================
# GITHUB CLI SETUP
# ============================================================================

# Install GitHub CLI: https://cli.github.com/

# Authenticate
gh auth login

# Check auth status
gh auth status

# ============================================================================
# USEFUL ALIASES
# ============================================================================

# Add to ~/.bashrc or ~/.zshrc

alias gh-runs='gh run list --branch main --limit 10'
alias gh-failed='gh run list --branch main --status failure --limit 5'
alias gh-watch='gh run watch'
alias gh-logs='gh run view --log'

# Usage: 
# source this file: source ci-cd-quick-ref.sh
# Then use: gh-runs, gh-failed, etc.
