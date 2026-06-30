<div align="center">

# gitlab-runner-stack

### One-command production-grade GitLab Runner with isolated Docker Engine

</div>

---

## Overview

**gitlab-runner-stack** deploys a complete GitLab CI Runner environment using
Docker Compose — no host Docker socket mounting, no manual certificate editing.

The stack runs a dedicated Docker Engine (DinD) secured with mutual TLS, and a
GitLab Runner that connects to it over the network. Every byte of data — Docker
images, build cache, runner config, certificates — lives inside the project
directory for easy backup and migration.

```
┌──────────────────────────────────────────────────┐
│                  Host Machine                     │
│                                                   │
│  ┌─────────────┐       ┌────────────────────┐     │
│  │   Runner    │──────▶│   Docker Engine    │     │
│  │ (gitlab-    │ TLS   │   (DinD + TLS)     │     │
│  │  runner)    │:2376  │                    │     │
│  └──────┬──────┘       └────────┬───────────┘     │
│         │                       │                  │
│         │ polls                 │ creates          │
│         ▼                       ▼                  │
│  ┌──────────────┐       ┌────────────────────┐     │
│  │   GitLab     │       │   CI Job           │     │
│  │   Server     │       │   Containers       │     │
│  └──────────────┘       └────────────────────┘     │
│                                                   │
│  All data in ./docker ./runner ./certs ./cache    │
└──────────────────────────────────────────────────┘
```

## Features

- **Docker Engine 29** — isolated DinD daemon with overlay2 storage
- **Mutual TLS** — auto-generated CA, server, and client certificates
- **GitLab Runner** — supports both new auth tokens (16.0+) and legacy registration
- **BuildKit + Buildx** — enabled in the daemon for faster, multi-platform builds
- **Persistent caches** — Maven, Gradle, npm, pnpm, Yarn, Pip, Cargo, Go, Composer, NuGet, Flutter, ccache
- **Health checks** — both Docker daemon and Runner monitored by Compose
- **Prometheus metrics** — runner exposes metrics on :9252
- **Monitoring overlay** — optional Prometheus, Grafana, and AlertManager
- **Backup & restore** — one-command backup and restore scripts
- **Garbage collection** — configurable Docker GC with cache retention
- **One-command update** — pull latest images and recreate containers
- **Log rotation** — configurable per-service log file rotation
- **All data in-project** — nothing scattered across the host filesystem
- **Idempotent scripts** — safe to run multiple times

## Quick Start

```bash
git clone <your-repo-url> gitlab-runner-stack
cd gitlab-runner-stack

# 1. Create your config
cp .env.example .env

# 2. Edit .env — set your GitLab URL and runner token
vi .env

# 3. Initialize (generates certs, creates directories)
./scripts/init.sh

# 4. Start the stack
docker compose up -d

# 5. Register the runner with GitLab
./scripts/register-runner.sh
```

That's it. The runner will appear as online in your GitLab project's
**Settings → CI/CD → Runners** page.

## Getting a Runner Token

### GitLab 16.0+ (recommended)

1. Go to **Settings → CI/CD → Runners** in your GitLab project or group
2. Click **New project runner** (or **New group runner**)
3. Select tags, then click **Create runner**
4. Copy the **authentication token** that appears
5. Paste it as `RUNNER_AUTH_TOKEN` in your `.env`

### GitLab < 16.0 (legacy)

1. Go to **Settings → CI/CD → Runners**
2. Click **New project runner** to get a registration token
3. Paste it as `REGISTRATION_TOKEN` in your `.env`

## Configuration

All configuration lives in `.env`. Key variables:

| Variable | Description | Default |
|---|---|---|
| `GITLAB_URL` | GitLab server URL | `https://gitlab.example.com` |
| `RUNNER_AUTH_TOKEN` | Runner auth token (16.0+) | _(empty)_ |
| `REGISTRATION_TOKEN` | Legacy registration token | _(empty)_ |
| `RUNNER_NAME` | Display name | `gitlab-runner-01` |
| `RUNNER_TAGS` | Comma-separated tags | `docker,linux` |
| `RUNNER_CONCURRENT` | Concurrent jobs | `4` |
| `RUNNER_DEFAULT_IMAGE` | Default CI image | `alpine:latest` |
| `RUNNER_PRIVILEGED` | Privileged CI containers | `true` |
| `DOCKER_DIND_IMAGE` | Docker Engine image | `docker:29-dind` |
| `DOCKER_DRIVER` | Storage driver | `overlay2` |

See [`.env.example`](.env.example) for the complete list.

## Architecture

### Why a separate Docker daemon?

Mounting the host's Docker socket (`/var/run/docker.sock`) into a runner is
common but **insecure** — any CI job gets full root access to the host. This
stack uses an isolated Docker Engine inside a container (DinD) with mutual TLS
authentication. CI jobs run in containers created by this isolated daemon, and
all data stays inside the project directory.

### TLS Certificate Flow

``+certs/ca/       CA root certificate (signs both server and client)
certs/server/    Server cert for dockerd (ca.pem, server-cert.pem, server-key.pem)
certs/client/    Client cert for runner  (ca.pem, cert.pem, key.pem)
```

Certificates are generated by `scripts/generate-certs.sh` and are valid for
10 years by default (configurable via `CERT_VALIDITY_DAYS`).

## Directory Structure

```
gitlab-runner-stack/
├── compose.yaml              # Docker Compose definition
├── .env.example              # Configuration template
├── docker/
│   ├── daemon.json           # Docker daemon configuration
│   ├── data/                 # Docker images, layers (gitignored)
│   └── buildkit/             # BuildKit data (gitignored)
├── runner/
│   ├── config/
│   │   └── config.toml       # Runner configuration (rendered by register-runner.sh)
│   ├── cache/                # Runner-local cache (gitignored)
│   └── hooks/                # Custom runner hooks
├── certs/                    # TLS certificates (gitignored)
│   ├── ca/
│   ├── server/
│   └── client/
├── cache/                    # Shared build caches (gitignored)
└── scripts/
    ├── init.sh               # Initialize the stack
    ├── generate-certs.sh     # Generate TLS certificates
    └── register-runner.sh    # Register runner with GitLab
```

## Common Operations

```bash
# View logs
docker compose logs -f runner
docker compose logs -f docker

# Check status
docker compose ps

# Restart services
docker compose restart runner

# Stop everything
docker compose down

# Stop and remove all data (dangerous!)
docker compose down -v
```

## Registry Mirrors & Insecure Registries

Set in `.env`:

```bash
# Speed up pulls with a mirror
DOCKER_REGISTRY_MIRRORS=https://mirror.gcr.io

# Allow a local registry without TLS
DOCKER_INSECURE_REGISTRIES=registry.local:5000
```

Then update `docker/daemon.json` accordingly, or these will be handled by
future init script enhancements.

## Troubleshooting

### Runner shows as "never contacted" in GitLab

Check that `GITLAB_URL` and `RUNNER_AUTH_TOKEN` are correct in `.env`, then:

```bash
./scripts/register-runner.sh
docker compose logs runner
```

### CI jobs fail with "Cannot connect to the Docker daemon"

The Docker daemon container may still be starting. Check its health:

```bash
docker compose ps
docker compose logs docker
```

### Certificate errors

Regenerate certificates:

```bash
rm -rf certs/ca/* certs/server/* certs/client/*
./scripts/generate-certs.sh
docker compose restart
```

## Operations

```bash
# Full health check
./scripts/verify.sh

# Backup (config + certs)
./scripts/backup.sh

# Full backup (includes data + caches)
./scripts/backup.sh --full

# Restore
./scripts/restore.sh backups/gitlab-runner-stack_*.tar.gz

# Garbage collection
./scripts/prune.sh

# Update to latest images (preserves config + data)
./scripts/update.sh
```

### Monitoring

Enable the observability stack:

```bash
docker compose -f compose.yaml -f compose.monitoring.yaml up -d
```

| Service | URL | Default Credentials |
|---|---|---|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | — |
| AlertManager | http://localhost:9093 | — |

## CI Examples

Ready-to-use `.gitlab-ci.yml` templates in `examples/`:

| Directory | Language/Platform |
|---|---|
| `examples/java/` | Java (Maven + Gradle) |
| `examples/node/` | Node.js |
| `examples/python/` | Python |
| `examples/golang/` | Go |
| `examples/rust/` | Rust |
| `examples/php/` | PHP |
| `examples/dotnet/` | .NET |
| `examples/flutter/` | Flutter |
| `examples/docker/` | Docker builds |

## Documentation

| Doc | Content |
|---|---|
| [docs/install.md](docs/install.md) | Detailed installation guide |
| [docs/tls.md](docs/tls.md) | TLS certificate architecture and management |
| [docs/cache.md](docs/cache.md) | Build caching configuration |
| [docs/buildkit.md](docs/buildkit.md) | BuildKit and Buildx usage |
| [docs/runner.md](docs/runner.md) | Runner configuration reference |
| [docs/backup.md](docs/backup.md) | Backup and restore procedures |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common issues and solutions |

## License

[MIT](LICENSE)
