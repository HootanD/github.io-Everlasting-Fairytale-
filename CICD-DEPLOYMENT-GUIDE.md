# CI/CD Deployment Guide

## Overview
This project uses GitHub Actions for automated CI/CD with Docker builds, testing, security scanning, and deployment stages.

## Pipeline Stages

### 1. **Lint** (Runs on every push/PR)
- Validates code with ESLint
- Optional but recommended

### 2. **Test** (Depends on Lint)
- Runs unit and integration tests
- Blocks build on failure

### 3. **Build** (Depends on Test)
- Builds Docker image with multi-stage build
- Pushes to GitHub Container Registry (ghcr.io)
- Tags with:
  - `latest` (main branch)
  - Branch name (develop)
  - Semantic version (on tags)
  - Git SHA (all pushes)

### 4. **Security** (After Build)
- Scans code and dependencies with Trivy
- Reports vulnerabilities to GitHub Security tab

### 5. **Deploy Staging** (On develop branch push)
- Deploys to staging environment
- Use for testing before production

### 6. **Deploy Production** (On main branch or version tags)
- Deploys to production environment
- Triggered by pushing to main or creating release tags

## Setup Instructions

### 1. Enable GitHub Actions
- Go to **Settings → Actions → General**
- Ensure **Actions permissions** are enabled

### 2. Configure Secrets (if using external registry)
For Docker Hub or private registry, add to **Settings → Secrets and variables → Actions**:
- `DOCKER_USERNAME`: Your Docker Hub username
- `DOCKER_PASSWORD`: Your Docker Hub access token
- `REGISTRY_URL`: Your registry URL (default: ghcr.io)

### 3. Add Deployment Scripts
Update the deployment steps in `.github/workflows/ci-cd.yml`:

**For Docker Compose (VPS/VM):**
```bash
ssh user@host 'cd /app && docker-compose -f docker-compose.yml pull && docker-compose up -d'
```

**For Kubernetes:**
```bash
kubectl set image deployment/node-app app=$IMAGE_TAG -n production
kubectl rollout status deployment/node-app -n production
```

**For Docker Swarm:**
```bash
docker service update --image $IMAGE_TAG node-app
```

### 4. Trigger Builds
- **Automatic**: Push to `main` or `develop` branches
- **Manual**: Use GitHub Actions UI → Run workflow
- **Version Release**: Create a git tag `v1.0.0` and push

## Image Tagging Strategy

Examples for branch `main`, commit `abc123`:
- `ghcr.io/username/repo:latest` (main only)
- `ghcr.io/username/repo:main` (all main pushes)
- `ghcr.io/username/repo:main-abc123` (unique SHA)

For version tag `v1.2.3`:
- `ghcr.io/username/repo:1.2.3`
- `ghcr.io/username/repo:1.2`
- `ghcr.io/username/repo:latest`

## Monitoring & Debugging

### Check Workflow Status
1. Go to **Actions** tab in GitHub
2. Click workflow run to see detailed logs
3. Each job shows start/end time and status

### Common Failures
- **Test fails**: Check test script in `package.json`
- **Build fails**: Review `docker build` logs in job output
- **Security scan fails**: Review Trivy report (non-blocking)
- **Deployment fails**: Check SSH keys or registry credentials

### View Trivy Scan Results
- Go to **Security → Code scanning alerts**
- Review and dismiss false positives as needed

## Best Practices

1. **Tag releases**: Use semantic versioning (`v1.0.0`)
2. **Branch strategy**:
   - `main`: Production-ready code
   - `develop`: Integration branch
   - `feature/*`: Feature branches (PR to develop)
3. **Keep secrets safe**: Never commit `.env` or API keys
4. **Monitor image size**: Use `docker buildx du` to check layer sizes
5. **Automate rollbacks**: Consider adding canary deployments

## Disable/Modify Pipeline
- Edit `.github/workflows/ci-cd.yml`
- Comment out jobs or conditions as needed
- Push to test changes
