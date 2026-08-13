# CI/CD Troubleshooting Guide

## 🔍 Diagnosis Steps

### Step 1: Check Workflow Status
```bash
# View recent runs
gh run list --branch main --limit 5

# View full logs
gh run view <RUN_ID> --log

# Watch live
gh run watch <RUN_ID>
```

### Step 2: Identify Failed Job
In GitHub UI: Actions → [Workflow] → [Run] → Check which job failed (red X)

### Step 3: View Job Logs
Click on failed job name → Expand each step → Look for error messages

---

## 🐛 Common Issues & Fixes

### ❌ Tests Failing

**Error:** `npm ERR! code ENOENT`

**Cause:** Dependencies not installed or lockfile out of sync

**Fix:**
```bash
# Locally
npm install
npm ci  # Clean install using lockfile

# Check for syntax errors
npm test

# Update package-lock.json
npm install
git add package-lock.json
git commit -m "update: lockfile"
git push
```

---

**Error:** `Cannot find module '@opentelemetry/sdk-node'`

**Cause:** Missing dependency in package.json

**Fix:**
```bash
npm install @opentelemetry/sdk-node
git add package.json package-lock.json
git commit -m "add: missing dependency"
git push
```

---

**Error:** `FAIL: all tests failed`

**Cause:** Test assertions not met

**Fix:**
```bash
# Run locally
npm test

# Add test script to package.json if missing
# "test": "jest"

# Check test output for details
npm test -- --verbose

# Fix failing tests, commit, push
```

---

### ❌ Docker Build Failing

**Error:** `failed to build with image: <image>: not found`

**Cause:** Base image not found or name typo

**Fix:**
```dockerfile
# Check Dockerfile line 1
FROM node:20-alpine  # ✓ Correct
FROM nodejs:20       # ✗ Wrong name
```

**Verify image exists:**
```bash
docker pull node:20-alpine
# If this fails, the image name is wrong
```

---

**Error:** `COPY failed: <path>: no such file or directory`

**Cause:** File path doesn't exist in build context

**Fix:**
```bash
# Check what files exist
ls -la

# Dockerfile example:
COPY package*.json ./           # ✓ Copies package.json + package-lock.json
COPY app.js .                   # ✓ Copies app.js to workdir
COPY src/ src/                  # ✓ Copies directory

# Wrong examples:
COPY nonexistent.js .           # ✗ File doesn't exist
COPY . .                        # ✗ Copies everything (use .dockerignore instead)
```

**Create missing files or fix paths in Dockerfile**

---

**Error:** `permission denied while trying to connect to Docker daemon`

**Cause:** Docker daemon not running or permission issue

**Fix:**
```bash
# On Linux: Add user to docker group
sudo usermod -aG docker $USER

# On macOS: Restart Docker Desktop
# On Windows: Restart Docker Desktop

# Test:
docker ps
```

---

### ❌ Image Not Pushing to Registry

**Error:** `denied: permission denied`

**Cause:** Not logged in or token expired

**Fix:**
```bash
# Login to registry
docker login ghcr.io

# GitHub Container Registry uses GITHUB_TOKEN with packages:write scope
# Workflows auto-have this
# For local testing:
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_ACTOR --password-stdin

# Verify credentials
cat ~/.docker/config.json
```

---

**Error:** `no such host`

**Cause:** Typo in registry URL

**Fix:**
```bash
# Correct: ghcr.io (GitHub)
docker pull ghcr.io/owner/repo:latest

# Not:
docker pull github.io/...
docker pull ghcr.com/...
```

---

### ❌ Deployment Failing

**Error:** `connection refused` when running smoke tests

**Cause:** Service not listening or not started

**Fix:**
```bash
# Check docker-compose.yml
docker compose ps
docker compose logs app

# Manually test
docker compose up -d
sleep 5
curl http://localhost:8080/health

# Check if app is binding to 0.0.0.0:8080
netstat -tlnp | grep 8080
```

---

**Error:** `Health check passed, but metrics endpoint fails`

**Cause:** Service only partially working

**Fix:**
```bash
# Check logs
docker compose logs app

# Test each endpoint
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/ready
curl http://localhost:8080/metrics

# Check for startup errors
docker compose up -d && sleep 2 && docker compose logs app | grep -i error
```

---

**Error:** `Smoke tests passed, but production container crashes after 5 minutes`

**Cause:** Memory leak, resource exhaustion, or initialization issue

**Fix:**
```bash
# Check logs during crash
docker compose logs app --tail 100

# Monitor resources
docker stats

# Check for OOM (Out of Memory)
docker inspect <container> | grep -i oom

# Increase resources if needed
# Edit docker-compose.prod.yml
deploy:
  resources:
    limits:
      memory: 512M
    reservations:
      memory: 256M
```

---

### ❌ Slack Notifications Not Sending

**Error:** No Slack message after deployment

**Cause:** Webhook URL not set or invalid

**Fix:**
```bash
# Verify secret is set
gh secret list | grep SLACK

# If not set:
gh secret set SLACK_WEBHOOK_URL
# Paste your webhook URL and press Enter

# Verify URL is correct:
# https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX

# Test webhook manually
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test from CI/CD"}' \
  YOUR_WEBHOOK_URL
```

---

**Error:** Workflow passes but no Slack notification

**Cause:** Notification step has `if: always()` but SLACK_WEBHOOK_URL not set

**Fix:**
```bash
# Set the secret
gh secret set SLACK_WEBHOOK_URL

# Or remove Slack notification from workflow if not needed
# Delete the "Notify Slack" step from workflow YAML
```

---

### ❌ Branch Protection Blocking PRs

**Error:** `Required checks are still pending` or `Branch is out of date`

**Cause:** CI hasn't completed or branch not updated

**Fix:**
```bash
# Wait for CI to complete
gh run list --branch <your-branch> --limit 1

# Update branch with main
git fetch origin
git rebase origin/main
git push origin <your-branch> --force-with-lease

# View protection rules
gh api repos/<owner>/<repo>/branches/main/protection
```

---

### ❌ Workflow Not Triggering

**Error:** Push to branch but workflow doesn't start

**Cause:** Workflow disabled or trigger conditions not met

**Fix:**
```bash
# Check if workflow is enabled
gh workflow list

# Enable workflow if disabled
gh workflow enable <workflow-id>

# Check trigger conditions in YAML:
on:
  push:
    branches: [main, develop]  # Triggers only on these branches
  pull_request:
    branches: [main, develop]  # Triggers only on PRs to these branches
```

---

## 📋 Debug Checklist

- [ ] Run `npm install` and `npm test` locally first
- [ ] Verify all file paths in Dockerfile exist
- [ ] Check `.dockerignore` isn't excluding needed files
- [ ] Confirm Docker image builds locally: `docker build -t test .`
- [ ] Test deployment locally: `docker compose up`
- [ ] Verify health endpoints respond correctly
- [ ] Check GitHub secrets are set: `gh secret list`
- [ ] Verify branch protection rules: `gh api repos/<owner>/<repo>/branches/main/protection`
- [ ] Confirm service binds to `0.0.0.0:8080` (not `localhost`)

---

## 🔍 Advanced Debugging

### View Raw Workflow Logs
```bash
gh run view <RUN_ID> --log > workflow.log
cat workflow.log | grep -i error
```

### Inspect Docker Build Cache
```bash
docker buildx du
docker buildx prune
```

### Test Image Locally
```bash
# Pull image from registry
docker pull ghcr.io/<owner>/<repo>:latest

# Run and check
docker run -d -p 8080:8080 ghcr.io/<owner>/<repo>:latest
sleep 3
curl http://localhost:8080/health
docker logs <container>
docker stop <container>
```

### SSH into Staging Container
```bash
# If using SSH deployment
ssh user@host

# Then:
docker compose ps
docker compose logs app
docker exec -it app-container bash
```

---

## 📞 Getting Help

### 1. Check Workflow Logs
```bash
gh run view <RUN_ID> --log
```

### 2. Search GitHub Issues
https://github.com/actions/runner/issues

### 3. Check Docker Docs
https://docs.docker.com/

### 4. Check Node.js Docs
https://nodejs.org/docs/

### 5. Create GitHub Discussion
https://github.com/user/repo/discussions

---

## 🛠️ Useful Commands Reference

```bash
# View workflow status
gh run list --branch main

# View specific run (full details)
gh run view <RUN_ID>

# View logs
gh run view <RUN_ID> --log

# Watch live
gh run watch <RUN_ID>

# Retry failed run
gh run rerun <RUN_ID>

# Download artifacts
gh run download <RUN_ID> -n <artifact-name>

# List all workflows
gh workflow list

# Enable/disable workflow
gh workflow enable <workflow-id>
gh workflow disable <workflow-id>

# View recent artifact
gh run view --latest

# Cancel ongoing run
gh run cancel <RUN_ID>

# Delete workflow run
gh run delete <RUN_ID>

# Check docker build locally
docker build -t test:latest .

# Test compose locally
docker compose up -d
sleep 5
curl http://localhost:8080/health
docker compose logs
docker compose down
```

---

## 💡 Pro Tips

1. **Always test locally before pushing**
   ```bash
   npm install && npm test
   docker build -t test .
   docker compose up
   ```

2. **Use descriptive commit messages**
   ```bash
   git commit -m "fix(test): handle edge case in data processor"
   ```

3. **Check logs FIRST**
   - 90% of issues are visible in logs
   - Always run: `gh run view <RUN_ID> --log`

4. **Test health endpoints**
   ```bash
   curl -v http://localhost:8080/health
   ```

5. **Monitor resource usage**
   ```bash
   docker stats
   ```

---

**Last Updated:** $(date)
**Status:** ✅ Reference guide ready
