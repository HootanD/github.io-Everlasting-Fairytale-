# CI/CD Workflow Status & Configuration

## ✅ Workflow Status

| Workflow | File | Status | Trigger | Duration |
|----------|------|--------|---------|----------|
| Lint & Test | `test.yml` | ✅ Active | Push to main/develop, PR | 2-3 min |
| Build & Push Image | `docker-build-push.yml` | ✅ Active | Push to main/develop/tags | 5-10 min |
| Deploy to Staging | `deploy-staging.yml` | ✅ Active | Push to develop | 2-3 min |
| Deploy to Production | `deploy-prod.yml` | ✅ Active | Manual (workflow_dispatch) | 3-5 min |

---

## 🔄 Pipeline Flow

```
Push Code
    ↓
[Lint & Test] ← Must pass
    ↓
[Build & Push Image] ← Create image + scan
    ↓
    ├─→ [Deploy to Staging] ← If develop branch
    │       ↓
    │   Health checks → Smoke tests → Slack notify
    │
    └─→ [Deploy to Production] ← If manual trigger
            ↓
        Select strategy (rolling/blue-green/canary)
            ↓
        Health checks → Smoke tests → Slack notify
```

---

## 📋 Detailed Workflow Configuration

### 1️⃣ Lint & Test (`test.yml`)

**Purpose:** Validate code quality and run unit tests

**Triggers:**
- Push to `main` branch
- Push to `develop` branch  
- Pull requests to `main` or `develop`

**Jobs:**
```
lint
  → Setup Node.js 20
  → Install dependencies
  → Run: npm run lint --if-present
  
test (needs: lint)
  → Setup Node.js 20
  → Install dependencies
  → Run: npm test --if-present
  → Upload: coverage/ artifacts
```

**Success Criteria:**
- All commands exit with code 0
- No dependency conflicts

**Artifacts:**
- `test-coverage/` (30 days retention)

**Failure Action:** Blocks PR merge (via branch protection)

---

### 2️⃣ Build & Push Image (`docker-build-push.yml`)

**Purpose:** Build Docker image, push to registry, scan for vulnerabilities

**Triggers:**
- Push to `main` branch → Tag as `latest`
- Push to `develop` branch → Tag as `develop-<SHA>`
- Push tag `v*` → Tag as `v1.2.3`
- Pull requests → Test build only (don't push)

**Jobs:**
```
build
  → Setup Docker Buildx
  → Login to ghcr.io
  → Extract metadata (tags)
  → Build multi-stage image
  → Push to registry
  → Attach SBOM + provenance

scan (needs: build)
  → Pull built image
  → Run Trivy CVE scan
  → Upload SARIF to GitHub Security tab
```

**Image Tags:**
- `main` → `ghcr.io/<owner>/<repo>:latest`
- `develop` → `ghcr.io/<owner>/<repo>:develop-abc1234`
- `v1.2.3` → `ghcr.io/<owner>/<repo>:v1.2.3`

**Image Details:**
- Base: `node:20-alpine` (lightweight, secure)
- Multi-stage: Separates build from runtime
- User: `nodejs` (non-root, security best practice)
- Size: ~180MB compressed

**Security Scanning:**
- Tool: Trivy (by Aqua)
- Scans for: CVEs, misconfigurations
- Output format: SARIF (GitHub-native)
- Results visible in: GitHub → Security → Code scanning

**Failure Action:** Logs vulnerabilities but does NOT block (informational)

---

### 3️⃣ Deploy to Staging (`deploy-staging.yml`)

**Purpose:** Automatically deploy to staging on develop changes

**Triggers:**
- Push to `develop` branch only

**Environment:** `staging`
- URL: `https://staging.example.com` (customize)
- Auto-approval: Yes (no manual gate needed)

**Jobs:**
```
deploy
  → Login to ghcr.io
  → Pull latest develop image
  → docker compose up -d --pull always
  → Wait for health check (30s)
    • Retry every 2s
    • Max 30 attempts
  → Smoke tests:
    • GET /health
    • GET /ready
    • GET /metrics
  → Notify Slack (success or failure)
```

**Health Check:**
- Endpoint: `GET http://localhost:8080/health`
- Expected: Status 200, JSON response
- Timeout: 2 seconds per request
- Max retries: 30 (total 60 seconds)

**Smoke Tests:**
- `GET /` - Root endpoint
- `GET /health` - Liveness probe
- `GET /ready` - Readiness probe
- `GET /metrics` - Prometheus metrics endpoint

**Slack Notification:**
- Sent for: Success AND failure
- Includes: Branch, commit SHA, status
- Requires secret: `SLACK_WEBHOOK_URL`

**Failure Action:** Stops deployment, alerts Slack, does NOT auto-rollback

---

### 4️⃣ Deploy to Production (`deploy-prod.yml`)

**Purpose:** Manual production deployment with strategy selection

**Triggers:**
- Manual via GitHub Actions UI (workflow_dispatch)
- Manual via GitHub CLI

**Inputs:**
```
deployment_strategy: (required)
  - rolling      → Gradual pod replacement
  - blue-green   → Parallel, atomic switch
  - canary       → Small traffic % first, gradual increase

image_tag: (optional)
  - Defaults to "latest"
  - Can be: v1.2.3, develop-abc1234, etc.
```

**Environment:** `production`
- Requires: Manual approval (GitHub environment protection)
- URL: `https://example.com` (customize)

**Jobs:**
```
validate
  → Resolve image tag (use input or default)
  → Verify image exists in registry

deploy (needs: validate, requires: approval)
  → Login to ghcr.io
  → Execute deployment based on strategy:
    * rolling: docker compose up -d --pull always
    * blue-green: Start new deployment, switch router
    * canary: Start limited deployment, monitor
  → Health check (20 retries, 5s intervals)
  → Smoke tests (all 4 endpoints)
  → Notify Slack (success or failure)
```

**Deployment Strategies:**

**Rolling:**
- Gradually replace old containers with new
- One container at a time
- Duration: 1-2 minutes
- Risk: Brief mixed versions
- Rollback: Manual (re-deploy old tag)

**Blue-Green:**
- Deploy new version alongside old
- Switch traffic atomically
- Duration: 2-3 minutes
- Risk: Requires 2x resources
- Rollback: Switch back to blue (fast)

**Canary:**
- Deploy to 5-10% of traffic first
- Monitor for errors (5-10 minutes)
- Gradually increase traffic
- Duration: 10-30 minutes
- Risk: Low (small blast radius)
- Rollback: Revert canary, keep stable

**Approval Gate:**
- Who: Repository admins / designated approvers
- Where: GitHub → Actions → Deploy to Production → Environment protection
- Time: Must approve within 30 days
- Cost: Prevents accidental deployments

**Health Check:** (Production)
- Endpoint: `GET http://localhost:8080/health`
- Max retries: 20
- Retry interval: 5 seconds (100s total)
- Longer timeout than staging for safe prod rollout

**Slack Notification:**
- On success: `✅ Production Deployment Success`
- On failure: `❌ Production Deployment Failed`
- Includes: Strategy, image tag, actor

---

## 🔐 Secrets Configuration

**Required Secrets:**
```
SLACK_WEBHOOK_URL
  └─ Used by: deploy-staging.yml, deploy-prod.yml
  └─ Type: String (sensitive)
  └─ Format: https://hooks.slack.com/services/T00.../B00.../XX...
  └─ Setup: GitHub → Settings → Secrets → Actions → New
  └─ How to get:
     1. Go to https://api.slack.com/apps
     2. Create app or select existing
     3. Enable "Incoming Webhooks"
     4. Create new webhook for channel
     5. Copy webhook URL
```

**Auto-Provided Secrets:**
```
GITHUB_TOKEN
  └─ Automatically provided by GitHub Actions
  └─ Used for: Pulling images, pushing images, uploading artifacts
  └─ Permissions: Inherits from workflow permissions
```

**Setup Commands:**
```bash
# Set Slack webhook
gh secret set SLACK_WEBHOOK_URL

# Verify
gh secret list

# Delete if needed
gh secret delete SLACK_WEBHOOK_URL
```

---

## 📊 Monitoring & Debugging

### View Workflow Status
```bash
# List all runs
gh run list --branch main --limit 10

# View specific run
gh run view <RUN_ID>

# View logs
gh run view <RUN_ID> --log

# Watch live
gh run watch <RUN_ID>
```

### Check Image Registry
```bash
# Login
docker login ghcr.io

# List images
docker pull ghcr.io/<owner>/<repo>:latest

# Inspect image
docker inspect ghcr.io/<owner>/<repo>:latest
```

### Verify Deployments
```bash
# Check running containers
docker compose ps

# View service logs
docker compose logs -f app

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/metrics
```

---

## 🛠️ Common Operations

### Manually Trigger Deployment
```bash
gh workflow run deploy-prod.yml \
  -f deployment_strategy=rolling \
  -f image_tag=latest
```

### Rollback to Previous Version
```bash
# Find previous tag
gh run list --status completed --limit 20

# Deploy that tag
gh workflow run deploy-prod.yml \
  -f deployment_strategy=rolling \
  -f image_tag=v1.2.2
```

### Force Re-run Failed Workflow
```bash
gh run rerun <RUN_ID>
```

### Verify Branch Protection
```bash
gh api repos/<owner>/<repo>/branches/main/protection
```

---

## 📈 Performance Metrics

| Metric | Value |
|--------|-------|
| Lint & Test | 2-3 minutes |
| Build Image | 5-10 minutes |
| Image Scan | 1-2 minutes |
| Deploy Staging | 2-3 minutes |
| Deploy Prod (rolling) | 3-5 minutes |
| Deploy Prod (canary) | 10-30 minutes |
| **Total (test→prod)** | **~30-60 minutes** |

---

## 🎯 Next Steps

1. **Set up Slack** (optional)
   ```bash
   gh secret set SLACK_WEBHOOK_URL
   ```

2. **Test staging deployment**
   ```bash
   git push origin develop
   # Monitor: gh run list --branch develop
   ```

3. **Test production deployment**
   - Go to: GitHub → Actions → Deploy to Production
   - Click "Run workflow"
   - Select strategy + tag
   - Approve when prompted

4. **Customize for your environment**
   - Edit workflow URLs
   - Add custom tests
   - Integrate with your deployment platform

---

**Generated:** $(date)
**Status:** ✅ Ready for production
