# CI/CD Setup Guide

This project uses GitHub Actions for automated CI/CD with the following workflows:

## Configured Workflows

### 1. **CI/CD Pipeline** (`.github/workflows/ci-cd.yml`)
Main workflow triggered on push/PR to `main` and `develop` branches.

**Stages:**
- **Lint**: Node.js code quality checks
- **Test**: Unit and integration tests
- **Build**: Docker multi-stage build with layer caching
- **Security**: Trivy filesystem and image vulnerability scanning
- **Deploy Staging**: Auto-deploy to staging on `develop` branch
- **Deploy Production**: Auto-deploy to production on `main` or tagged releases

### 2. **Docker Image Security Scan** (`.github/workflows/docker-image-scan.yml`)
Runs daily + on CI/CD completion to scan the latest image for vulnerabilities.

- Trivy: CVE scanning (critical/high severity)
- Optional: Snyk integration (requires `SNYK_TOKEN` secret)

### 3. **Production Deployment with Approval** (`.github/workflows/production-deployment.yml`)
Manual workflow for controlled production deployments with optional rollback.

**Features:**
- Image validation before deployment
- GitHub Environment approval gates
- Deployment strategy selection (rolling, blue-green, canary)
- Automatic rollback on failure

**To trigger:**
```
Actions → Production Deployment with Approval → Run workflow
```

### 4. **Performance & Regression Tests** (`.github/workflows/performance-tests.yml`)
Validates app performance and regression on every push + daily schedule.

**Tests:**
- Load testing (100 concurrent connections, 30s duration)
- P95 latency threshold: < 200ms
- Error rate threshold: < 1%
- Endpoint regression tests (health, ready, metrics, trace)
- Docker Compose service verification

### 5. **Release & Versioning** (`.github/workflows/release.yml`)
Auto-creates GitHub releases when `package.json` version changes.

**On Release:**
- Creates Git tag
- Generates GitHub Release with changelog
- Publishes Dockerfile and quick-start guide
- Triggers new Docker image build via CI/CD

---

## Required Secrets

Add these to **Settings → Secrets and variables → Actions**:

| Secret | Required | Purpose |
|--------|----------|---------|
| `GITHUB_TOKEN` | Auto | GitHub Actions token (auto-provided) |
| `SNYK_TOKEN` | Optional | Snyk vulnerability scanning |
| `DOCKERHUB_USERNAME` | Optional | DockerHub registry push (if using) |
| `DOCKERHUB_TOKEN` | Optional | DockerHub registry authentication |
| `DEPLOY_HOST` | Optional | Deployment server hostname/IP |
| `DEPLOY_KEY` | Optional | SSH private key for deployments |

---

## Required Environments

Add these to **Settings → Environments**:

### 1. **staging**
```
Deployment branches: develop
Reviewers: (optional)
```

### 2. **production**
```
Deployment branches: main
Reviewers: (recommended - require approval)
```

### 3. **production-approval** (for manual deployments)
```
Deployment branches: None (manual only)
Reviewers: Recommended for governance
```

---

## GitHub Container Registry (GHCR)

The workflows push to GHCR automatically using `GITHUB_TOKEN`.

**Image locations:**
- `ghcr.io/<owner>/<repo>:latest` (main branch)
- `ghcr.io/<owner>/<repo>:v1.0.0` (on release tags)
- `ghcr.io/<owner>/<repo>:develop-abc1234` (develop branch)

**To pull locally:**
```bash
docker login ghcr.io -u <username> -p $(gh auth token)
docker pull ghcr.io/<owner>/<repo>:latest
```

---

## Usage Examples

### Trigger Build Manually
```bash
git push origin main
# → Workflow runs automatically
```

### Create Release
Update `package.json` version and push to `main`:
```bash
npm version minor
git push origin main
# → Release workflow auto-triggers
```

### Deploy to Production (Manual)
1. Go to **Actions** → **Production Deployment with Approval**
2. Click **Run workflow**
3. Select deployment strategy (rolling/blue-green/canary)
4. Click **Run workflow**
5. GitHub will request approval if environment requires it
6. Deployment proceeds after approval

### Manual Image Security Scan
1. Go to **Actions** → **Docker Image Security Scan**
2. Click **Run workflow**
3. Results upload to **Security** → **Code scanning**

---

## Customization

### Update Deployment Targets
Edit the deployment jobs in:
- `.github/workflows/ci-cd.yml` (staging/prod auto-deploy)
- `.github/workflows/production-deployment.yml` (manual deploy)

Add your deployment commands (kubectl, SSH, docker-compose, Terraform, etc.)

### Adjust Performance Thresholds
In `.github/workflows/performance-tests.yml`:
- Line 53: Change P95 latency threshold
- Line 62: Change error rate threshold

### Add Linting Rules
In `package.json`, add lint script:
```json
{
  "scripts": {
    "lint": "eslint src/ --max-warnings 0"
  }
}
```

### Add Test Coverage
In `package.json`, add test script:
```json
{
  "scripts": {
    "test": "jest --coverage --threshold=80"
  }
}
```

---

## Troubleshooting

### Build Fails with "Image not found"
- Ensure Dockerfile exists in repo root
- Check `.dockerignore` excludes unnecessary files
- Verify `docker-compose.yml` references correct context

### Security Scan Fails
- Trivy may flag known issues as high severity
- In `.github/workflows/docker-image-scan.yml`, set `exit-code: '0'` to warn without failing

### Performance Tests Timeout
- Increase wait time in `.github/workflows/performance-tests.yml` (line 20: `60` seconds)
- Verify app exposes `/health` endpoint

### Deployment Secrets Missing
- Go to **Settings → Environments → production**
- Add required environment variables/secrets
- Reference them in workflow as: `\${{ secrets.SECRET_NAME }}`

---

## Next Steps

1. ✅ Add repository secrets (SNYK_TOKEN, etc.)
2. ✅ Set up deployment environments with approval gates
3. ✅ Update deployment commands for your infrastructure
4. ✅ Add test/lint scripts to `package.json`
5. ✅ Test workflows with a pull request
6. ✅ Monitor Security → Code scanning for vulnerability reports
