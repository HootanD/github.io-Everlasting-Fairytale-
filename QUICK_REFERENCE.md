# Quick Reference: Distributed Tracing Stack

## Service Status
```
✓ node-app     Port 8080   Health: Healthy
✓ Jaeger       Port 16686  Status: Running
✓ Tempo        Port 3200   Storage: Persistent
```

## Quick Commands

### View Logs
```bash
docker compose logs -f node-app
docker compose logs -f tempo
docker compose logs -f jaeger
```

### Generate Test Traces
```bash
# Single trace
curl http://localhost:8080/trace-test

# Bulk generation (100 traces)
for i in {1..100}; do curl -s http://localhost:8080/trace-test > /dev/null & done
```

### View Metrics
```bash
# All metrics
curl http://localhost:8080/metrics

# HTTP request metrics only
curl http://localhost:8080/metrics | grep http_request

# Trace generation count
curl http://localhost:8080/metrics | grep trace_generation
```

### Health Checks
```bash
# App health
curl http://localhost:8080/health

# App readiness
curl http://localhost:8080/ready

# Jaeger status
curl http://localhost:16686/api/services

# Tempo status
curl http://localhost:3200/
```

### View Traces
```bash
# Open Jaeger UI
http://localhost:16686

# Query Tempo API
curl http://localhost:3200/api/traces

# Get services
curl http://localhost:16686/api/services
```

## Docker Compose Operations

### Start
```bash
docker compose up -d
```

### Stop
```bash
docker compose down
```

### Restart
```bash
docker compose restart
docker compose restart node-app
docker compose restart tempo
docker compose restart jaeger
```

### Clean Reset
```bash
docker compose down -v
docker volume prune -f
docker compose up -d
```

## Environment Variables (node-app)

```env
NODE_ENV=production          # Environment mode
PORT=8080                    # App port
JAEGER_ENDPOINT=http://jaeger:6831
TEMPO_ENDPOINT=http://tempo:4318/v1/traces
```

## Volume Management

### Tempo Data Volume
```bash
# List volumes
docker volume ls | grep tempo

# Inspect volume
docker volume inspect everlasting-fairytale_tempo-data

# Remove volume (WARNING: Deletes traces)
docker volume rm everlasting-fairytale_tempo-data

# Backup volume
docker run --rm -v everlasting-fairytale_tempo-data:/data \
  -v $(pwd):/backup alpine tar czf /backup/tempo-backup.tar.gz /data
```

## Troubleshooting

### Service Won't Start
```bash
# Check logs
docker logs [service-name]

# Check ports
docker port [service-name]

# Verify network
docker network ls
docker network inspect everlasting-fairytale_default
```

### Health Check Failures
```bash
# Manual test
docker exec node-app curl -v http://localhost:8080/health

# Check container stats
docker stats node-app

# Test inter-service connectivity
docker exec node-app ping tempo
docker exec node-app ping jaeger
```

### Tempo Storage Issues
```bash
# Check volume space
docker exec tempo df -h /var/tempo

# List trace files
docker exec tempo find /var/tempo -type f

# Clear old traces
docker exec tempo rm -rf /var/tempo/traces/*
```

## Monitoring

### Real-Time Stats
```bash
docker stats node-app tempo jaeger
```

### Container Info
```bash
docker inspect node-app | grep -E "State|Health"
```

### Network Latency
```bash
docker exec node-app ping -c 5 tempo
docker exec node-app ping -c 5 jaeger
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| http://localhost:8080/ | GET | Root (version info) |
| http://localhost:8080/health | GET | Health status |
| http://localhost:8080/ready | GET | Readiness probe |
| http://localhost:8080/metrics | GET | Prometheus metrics |
| http://localhost:8080/trace-test | GET | Generate test trace |
| http://localhost:16686 | GET | Jaeger UI |
| http://localhost:3200 | GET | Tempo API |

## Key Files

| File | Purpose |
|------|---------|
| docker-compose.yml | Stack configuration |
| Dockerfile | Node.js app image |
| app.js | Application source |
| tempo.yml | Tempo configuration |
| DISTRIBUTED_TRACING_SETUP.md | Full setup guide |
| DISTRIBUTED_TRACING_CONFIGURATION.md | Detailed configuration |

## Common Workflows

### Deploy Fresh Stack
```bash
docker compose down -v
docker build -t everlasting-fairytale-app .
docker compose up -d
docker compose logs -f
```

### Load Test & Trace
```bash
# Terminal 1: Watch logs
docker compose logs -f node-app

# Terminal 2: Generate load
for i in {1..50}; do 
  curl -s http://localhost:8080/trace-test | jq .trace_id
done

# Terminal 3: View in Jaeger
open http://localhost:16686
```

### Monitor Metrics Over Time
```bash
watch -n 5 'curl -s http://localhost:8080/metrics | grep -E "trace_generation|http_requests_total"'
```

## Performance Tuning

### Increase Trace Buffer
Edit tempo.yml and restart:
```yaml
ingester:
  max_chunk_age: 2h
  max_chunk_size: 250000000
```

### Adjust App Latency Buckets
Edit app.js buckets array:
```javascript
buckets: [0.001, 0.01, 0.1, 0.5, 1, 2.5, 5, 10]
```

### Memory Limits
Add to docker-compose.yml:
```yaml
services:
  node-app:
    mem_limit: 512m
  tempo:
    mem_limit: 1g
  jaeger:
    mem_limit: 1g
```

## Security Checklist

- [ ] Disable public access to metrics endpoint
- [ ] Implement authentication for Jaeger UI
- [ ] Enable TLS for inter-service communication
- [ ] Set resource limits (memory, CPU)
- [ ] Configure network policies
- [ ] Enable audit logging
- [ ] Rotate trace retention policies
- [ ] Backup trace data regularly

## Support Resources

- Jaeger: https://www.jaegertracing.io/docs/
- Tempo: https://grafana.com/docs/tempo/
- OpenTelemetry: https://opentelemetry.io/docs/
- Docker: https://docs.docker.com/
