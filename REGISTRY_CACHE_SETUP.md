# Docker Registry Pull-Through Cache Setup

## Quick Start

### Option 1: Local Cache (Development/Testing)
```bash
docker compose -f docker-compose.registry-cache.yml up -d
```

Verify:
```bash
curl http://localhost:5000/v2/
```

### Option 2: CI/CD with Deployment

The `deploy-with-approval.yml` workflow includes:

1. **Deployment Approval Gate**: Requires manual approval before production deployment
2. **Registry Cache Integration**: Pulls images through cache for faster deployments
3. **Image Verification**: Ensures image integrity before tagging
4. **Multi-Tag Deployment**: Tags with both `latest` and `production` for easy rollback

## Configuration

### registry-config.yml
- **Proxy**: Caches layers from Docker Hub for 7 days
- **In-Memory**: Fast blob descriptor caching
- **Health Checks**: Monitors storage driver health
- **Volume**: Persists cached layers in `registry-cache-data`

### Deployment Workflow Steps

1. **Build workflow succeeds** (multi-platform, tests, security scan pass)
2. **Approval gate triggered** — requires manual review/approval from production environment
3. **On approval:**
   - Pull image from registry via cache
   - Verify image integrity
   - Tag for production (`production`, `latest`)
   - Push tagged images

### Enable Approval Gate

1. Go to Settings → Environments → Create "production"
2. Enable "Required reviewers" and add team members
3. (Optional) Restrict branch to `main` only

## Usage in CI/CD

After approval, deployments automatically:
- Use registry cache (faster layer pulls, reduced bandwidth)
- Tag images with `production` and `latest`
- Enable zero-downtime rollback (previous `latest` still available)

## Local Testing

```bash
# Start cache
docker compose -f docker-compose.registry-cache.yml up -d

# Configure Docker to use cache
# Edit /etc/docker/daemon.json (Linux) or Docker Desktop settings (Mac/Windows):
{
  "registry-mirrors": ["http://localhost:5000"]
}

# Restart Docker daemon
# Pull images — now cached!
docker pull node:18-alpine
```

## Production Deployment

For production, deploy `docker-compose.registry-cache.yml` on a dedicated host:
- Map port 5000 to internal network (not internet-facing)
- Use persistent volume for cache (`registry-cache-data`)
- Configure CI/CD agents to point to cache: `export DOCKER_HOST_REGISTRY=localhost:5000`
