# CI/CD Setup Complete

Your GitHub Actions CI/CD pipeline is now fully configured. This guide walks through what's set up and how to use it.

## 🏗️ Architecture Overview

```
Code Push → Lint/Test → Build Image → Push Registry → Deploy (Staging/Prod)
                                              ↓
                                         Security Scan
```

## 📋 Workflows

### 1. **test.yml** - Lint & Unit Tests
- **Trigger:** Push to `main` or `develop`, Pull Requests
- **Jobs:** 
  - Lint code
  - Run tests
  - Upload coverage artifacts
- **Duration:** ~2-3 minutes
- **Failure:** Blocks PR merges (via branch protection)

### 2. **docker-build-push.yml** - Build & Push Docker Image
- **Trigger:** Push to branches/tags, PR reviews
- **Jobs:**
  - Build multi-stage Docker image (Node.js alpine)
  - Push to GitHub Container Registry (ghcr.io)
  - Generate SBOM + provenance attestations
  - Security scan with Trivy (CVE detection)
- **Image Tags:**
  - `main` → `latest`
  - `develop` → `develop-<SHA>`
  - Tags → `v1.2.3`
- **Duration:** ~5-10 minutes
- **Storage:** GitHub Container Registry (ghcr.io)

### 3. **deploy-staging.yml** - Deploy to Staging
- **Trigger:** Push to `develop` branch only
- **Environment:** Staging
- **Steps:**
  - Pull latest `develop` image
  - Deploy with `docker compose`
  - Health checks (30s timeout)
  - Smoke tests (health, ready, metrics endpoints)
  - Slack notification
- **Duration:** ~2-3 minutes
- **Failure:** Notifies Slack, does NOT auto-rollback

### 4. **deploy-prod.yml** - Deploy to Production
- **Trigger:** Manual workflow dispatch (GitHub UI)
- **Inputs:**
  - Deployment strategy: `rolling`, `blue-green`, `canary`
  - Image tag: optional (defaults to `latest`)
- **Environment:** Production (requires approval)
- **Steps:**
  - Validate image exists
  - Deploy using selected strategy
  - Health checks (20 retries, 5s intervals)
  - Smoke tests
  - Slack notifications
- **Duration:** ~3-5 minutes
- **Approval Gate:** GitHub Environment Protection

## 🔐 Required GitHub Secrets

Set these in **Settings → Secrets and variables → Actions**:

| Secret | Description | Example |
|--------|-------------|---------|
| `SLACK_WEBHOOK_URL` | Slack incoming webhook | `https://hooks.slack.com/services/...` |

*Note: `GITHUB_TOKEN` is automatically provided by GitHub Actions*

## 🚀 Quick Start

### 1. Deploy to Staging (Automatic)
```bash
# Push to develop branch
git checkout develop
git commit -m "feature: add new feature"
git push origin develop
```
Staging automatically deploys and tests. View status: **Actions** tab in GitHub.

### 2. Deploy to Production (Manual)
```bash
# Via GitHub UI:
# 1. Go to Actions → Deploy to Production
# 2. Click "Run workflow"
# 3. Select strategy + image tag
# 4. Click "Run workflow"
```

Or via GitHub CLI:
```bash
gh workflow run deploy-prod.yml -f deployment_strategy=rolling -f image_tag=latest
```

## 📊 Monitoring

### GitHub Actions Dashboard
- **URL:** `https://github.com/<owner>/<repo>/actions`
- Shows all workflow runs, status, logs, artifacts

### View Specific Workflow
```bash
gh run list --branch main --limit 10
gh run view <RUN_ID> --log
```

### Watch Live
```bash
gh run watch <RUN_ID>
```

### Check Secrets
```bash
gh secret list
```

## 🔄 Deployment Strategies

### Rolling Updates
- Gradually replace old pods/containers with new ones
- **Best for:** Zero-downtime updates, stable services
- **Risk:** Brief period with mixed versions

### Blue-Green
- Deploy new version alongside old one
- Switch traffic atomically
- **Best for:** Quick rollback if needed
- **Trade-off:** Requires 2x resources temporarily

### Canary
- Deploy to small % of traffic first
- Monitor for errors
- Gradually increase traffic
- **Best for:** High-risk deployments, early detection
- **Duration:** Usually 5-30 minutes

## 🛡️ Security Features

### 1. Image Scanning
- Every image scanned with Trivy for CVEs
- Results uploaded to GitHub Security tab
- Vulnerabilities tracked in Security → Code scanning

### 2. SBOM (Software Bill of Materials)
- Generated automatically for every build
- Track all dependencies/layers
- Available in image metadata

### 3. Provenance Attestation
- Cryptographically signed build metadata
- Proves where image came from
- Can be verified for supply chain security

### 4. Branch Protection
- Require passing CI/CD before merge
- Require PR review
- Enforce up-to-date branches

## 📝 Common Tasks

### Trigger All Workflows for Develop
```bash
git checkout develop
git commit --allow-empty -m "trigger: CI/CD workflows"
git push origin develop
```

### Deploy Specific Image Tag
```bash
gh workflow run deploy-prod.yml \
  -f deployment_strategy=rolling \
  -f image_tag=v1.2.3
```

### Check Recent Deployments
```bash
gh run list --branch main --limit 5
```

### View Deployment Logs
```bash
gh run view <RUN_ID> --log
```

### Rollback (Re-deploy Previous Version)
```bash
# Find previous tag/image
gh workflow run deploy-prod.yml \
  -f deployment_strategy=rolling \
  -f image_tag=v1.2.2
```

## 🔧 Customization

### Change Node.js Version
Edit `.github/workflows/test.yml`:
```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '20'  # Change here
```

### Add Custom Tests
Add to `package.json`:
```json
{
  "scripts": {
    "test": "jest",
    "lint": "eslint src/"
  }
}
```

### Change Staging Environment
Edit `.github/workflows/deploy-staging.yml`:
```yaml
environment:
  name: staging
  url: https://your-staging-url.com
```

### Add Slack Notifications to All Workflows
Add step to workflows:
```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "Workflow: ${{ job.status }}"
      }
```

## 🐛 Troubleshooting

### Tests Failing
```bash
# View logs
gh run view <RUN_ID> --log

# Run locally
npm install
npm test
```

### Image Not Pushing
- Check `GITHUB_TOKEN` permissions
- Verify repository is public or token has `packages:write`
- Check image name is lowercase

### Deployment Not Starting
- Verify `SLACK_WEBHOOK_URL` is set (optional but needed if workflow uses Slack)
- Check environment protection rules
- Confirm image tag exists: `docker pull ghcr.io/<owner>/<repo>:latest`

### Health Checks Timing Out
- Check service is binding to `0.0.0.0:8080`
- Verify health endpoint exists: `GET /health`
- Increase timeout in workflow if service is slow

## 📚 Files Generated

```
.github/workflows/
├── test.yml                    # Lint & tests
├── docker-build-push.yml       # Build & push image
├── deploy-staging.yml          # Deploy to staging
└── deploy-prod.yml             # Deploy to production
```

## 🎯 Next Steps

1. **Set Slack Webhook** (optional but recommended)
   ```bash
   gh secret set SLACK_WEBHOOK_URL
   ```

2. **Create a test PR** to verify CI/CD
   ```bash
   git checkout -b test/ci-cd
   git commit --allow-empty -m "test: verify CI/CD"
   git push origin test/ci-cd
   # Create PR via GitHub UI
   ```

3. **Deploy to staging**
   ```bash
   git checkout develop
   git commit --allow-empty -m "test: trigger staging deployment"
   git push origin develop
   ```

4. **Deploy to production** (via GitHub UI Actions tab)

## 📖 Documentation

- **GitHub Actions Docs:** https://docs.github.com/en/actions
- **Docker Build Docs:** https://docs.docker.com/build/
- **Container Registry:** https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry

---

**Last Updated:** $(date)
**Status:** ✅ Ready to deploy
