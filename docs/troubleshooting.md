# Troubleshooting

[English](troubleshooting.md) | [简体中文](troubleshooting.zh-CN.md)

## Runner Not Appearing in GitLab

### Symptoms
Runner shows as "never contacted" or is offline in GitLab UI.

### Fixes

1. Verify your token and URL in `.env`:
```bash
grep -E 'GITLAB_URL|RUNNER_AUTH_TOKEN|REGISTRATION_TOKEN' .env
```

2. Re-register the runner:
```bash
./scripts/register-runner.sh
```

3. Check runner logs:
```bash
docker compose logs runner
```

4. Verify from inside the container:
```bash
docker compose exec runner gitlab-runner verify
```

---

## "Cannot connect to the Docker daemon"

### Symptoms
CI jobs fail with `Cannot connect to the Docker daemon at tcp://docker:2376`.

### Fixes

1. Check the Docker daemon container is healthy:
```bash
docker compose ps
```

2. Check Docker daemon logs:
```bash
docker compose logs docker
```

3. Verify TLS certificates:
```bash
openssl verify -CAfile certs/ca/ca.pem certs/server/server-cert.pem certs/client/cert.pem
```

4. Regenerate certificates if corrupted:
```bash
rm -rf certs/ca/* certs/server/* certs/client/*
./scripts/generate-certs.sh
docker compose restart
```

---

## Certificate Errors (x509)

### Symptoms
`x509: certificate signed by unknown authority` or `x509: certificate has expired`.

### Fixes

Regenerate all certificates:
```bash
./scripts/generate-certs.sh
docker compose restart
```

If connecting from a custom hostname, update `DOCKER_TLS_HOST` in `.env` first.

---

## Docker Daemon Won't Start

### Symptoms
The `docker` container exits or stays unhealthy.

### Fixes

1. Check if `overlay2` is supported on your filesystem:
```bash
docker compose logs docker | grep -i storage
```

2. Try `vfs` storage driver:
```bash
# In .env
DOCKER_DRIVER=vfs
```

3. Check for permission issues:
```bash
ls -la docker/data/
```

---

## Out of Disk Space

### Symptoms
Builds fail, containers won't start, `no space left on device`.

### Fixes

Run garbage collection:
```bash
./scripts/prune.sh
```

Check disk usage:
```bash
docker compose exec docker docker system df
```

Adjust retention policy in `.env`:
```bash
# Keep less build cache history
PRUNE_CACHE_RETENTION=24h
```

---

## High Memory Usage

### Symptoms
Host is running out of memory, OOM kills.

### Fixes

1. Reduce concurrency:
```bash
# In .env
RUNNER_CONCURRENT=2
```
Then re-register:
```bash
./scripts/register-runner.sh
```

2. Limit Docker daemon memory:
```bash
# In .env
DOCKER_MEMORY=4g
```

---

## Stale CI Job Containers

### Symptoms
Leftover containers accumulate after failed jobs.

### Fixes

```bash
./scripts/prune.sh
```

Or manually:
```bash
docker compose exec docker docker container prune -f
```

---

## Full Verification

Run the health check script for a complete diagnosis:

```bash
./scripts/verify.sh
```

If everything fails, a clean restart often helps:
```bash
docker compose down
docker compose up -d
./scripts/register-runner.sh
```
