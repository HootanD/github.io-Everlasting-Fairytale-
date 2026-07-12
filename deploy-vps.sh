#!/bin/bash
set -e

# VPS Deployment Script
# Usage: ./deploy-vps.sh <image-tag> <environment>

IMAGE_TAG=${1:-latest}
ENVIRONMENT=${2:-staging}

REGISTRY="docker.io"
IMAGE_NAME="${DOCKER_USERNAME}/your-repo"
COMPOSE_FILE="docker-compose.prod.yml"

echo "🚀 Starting VPS deployment..."
echo "Image: $REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
echo "Environment: $ENVIRONMENT"

# Login to Docker registry
echo "🔐 Logging into Docker registry..."
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

# Pull latest image
echo "📥 Pulling image..."
docker pull "$REGISTRY/$IMAGE_NAME:$IMAGE_TAG" || {
  echo "❌ Failed to pull image"
  exit 1
}

# Backup current compose state
echo "💾 Backing up current deployment..."
if [ -f "$COMPOSE_FILE" ]; then
  cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup.$(date +%s)"
fi

# Stop old deployment
echo "⛔ Stopping old deployment..."
docker-compose -f "$COMPOSE_FILE" down || true

# Update environment
echo "🔧 Updating configuration..."
export DOCKER_IMAGE="$REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
export REGISTRY="$REGISTRY"
export IMAGE_NAME="$IMAGE_NAME"

# Start new deployment
echo "🚀 Starting new deployment..."
docker-compose -f "$COMPOSE_FILE" up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to become healthy..."
sleep 5

# Verify deployment
echo "✅ Verifying deployment..."
docker-compose -f "$COMPOSE_FILE" ps

# Health checks
echo "🏥 Running health checks..."
for i in {1..5}; do
  if curl -f http://localhost:8080/health > /dev/null 2>&1; then
    echo "✓ Health check passed"
    break
  fi
  if [ $i -eq 5 ]; then
    echo "❌ Health check failed after 5 attempts"
    exit 1
  fi
  echo "⏳ Retry $i/5..."
  sleep 2
done

echo "✓ Ready endpoint check..."
curl -f http://localhost:8080/ready > /dev/null || echo "⚠ Ready endpoint timeout (may be expected)"

# Show logs
echo ""
echo "📋 Recent logs:"
docker-compose -f "$COMPOSE_FILE" logs --tail=20

echo ""
echo "✓ Deployment complete!"
echo "App running at: http://localhost:8080"
