# Installation Guide

**English** | [简体中文](../zh-CN/install.md)

## Prerequisites

- **Docker Engine 24+** (host machine)
- **Docker Compose V2** (`docker compose`)
- **OpenSSL** (for certificate generation)
- A **GitLab** instance (CE or EE) accessible from the host
- A **runner token** from your GitLab project or group

## Quick Install

```bash
git clone https://github.com/realqingtian/gitlab-runner-stack.git gitlab-runner-stack
cd gitlab-runner-stack

cp .env.example .env

# Edit .env — set GITLAB_URL and your runner token
vi .env

./scripts/init.sh

docker compose up -d

./scripts/register-runner.sh
```

## Step-by-Step

### 1. Clone the repository

```bash
git clone https://github.com/realqingtian/gitlab-runner-stack.git gitlab-runner-stack
cd gitlab-runner-stack
```

### 2. Configure environment

```bash
cp .env.example .env
```

Open `.env` and set the required values:

| Variable | What to set |
|---|---|
| `GITLAB_URL` | Your GitLab server URL |
| `RUNNER_AUTH_TOKEN` | Runner authentication token (GitLab 16.0+) |
| `REGISTRATION_TOKEN` | Legacy registration token (GitLab < 16.0) |

### 3. Initialize

```bash
./scripts/init.sh
```

This script:
- Checks prerequisites
- Creates all directories
- Generates TLS certificates (if not present)
- Validates configuration

### 4. Start the stack

```bash
docker compose up -d
```

Verify both containers are running:

```bash
docker compose ps
```

You should see `docker` and `runner` with status `Up`.

### 5. Register the runner

```bash
./scripts/register-runner.sh
```

This renders `config.toml` with your credentials and restarts the runner.

### 6. Verify

```bash
./scripts/verify.sh
```

Check your GitLab UI under **Settings > CI/CD > Runners** — the runner should show as online (green circle).

## Enabling Monitoring (Optional)

```bash
docker compose -f compose.yaml -f compose.monitoring.yaml up -d
```

Access:
- Grafana: http://localhost:3000 (admin/admin by default)
- Prometheus: http://localhost:9090
- AlertManager: http://localhost:9093

## Uninstall

```bash
docker compose down

# Remove all data (irreversible)
rm -rf docker/data/ cache/ certs/ runner/config/config.toml
```
