# Runner Configuration Guide

[English](runner.md) | [简体中文](runner.zh-CN.md)

## config.toml

The runner's behavior is controlled by `runner/config/config.toml`, which is
rendered from `runner/config/config.toml.template` by `register-runner.sh`.

**Never edit `config.toml` directly** — your changes will be overwritten.
Edit the template or the `.env` variables instead.

## Key Settings

### Global

| Setting | .env Variable | Default | Description |
|---|---|---|---|
| `concurrent` | `RUNNER_CONCURRENT` | `4` | Jobs running simultaneously |
| `check_interval` | — | `0` | Seconds between GitLab polls (0 = default) |
| `log_level` | — | `info` | Log verbosity |

### Per-Runner

| Setting | .env Variable | Default | Description |
|---|---|---|---|
| `url` | `GITLAB_URL` | — | GitLab server URL |
| `token` | `RUNNER_AUTH_TOKEN` | — | Authentication token |
| `name` | `RUNNER_NAME` | `gitlab-runner-01` | Display name |
| `limit` | `RUNNER_LIMIT` | `0` | Max jobs accepted (0 = unlimited) |

### Docker Executor

| Setting | .env Variable | Default | Description |
|---|---|---|---|
| `image` | `RUNNER_DEFAULT_IMAGE` | `alpine:latest` | Fallback image for jobs |
| `privileged` | `RUNNER_PRIVILEGED` | `true` | Privileged mode for DinD |
| `host` | — | `tcp://docker:2376` | Docker daemon address |
| `tls_verify` | — | `true` | Require TLS verification |
| `pull_policy` | — | `if-not-present` | Image pull strategy |

## Registration

### New auth token (GitLab 16.0+)

1. Create a runner in GitLab UI
2. Copy the authentication token
3. Set `RUNNER_AUTH_TOKEN` in `.env`
4. Run `./scripts/register-runner.sh`

The token goes directly into `config.toml` — no API call needed.

### Legacy registration token (GitLab < 16.0)

1. Get a registration token from GitLab
2. Set `REGISTRATION_TOKEN` in `.env`
3. Run `./scripts/register-runner.sh`

The script calls `gitlab-runner register` inside the container, which
contacts GitLab to exchange the token for a permanent runner token.

## Re-registering

To update the runner (new token, different GitLab instance, changed tags):

```bash
# Edit .env, then:
./scripts/register-runner.sh
```

## Verifying

```bash
# Check runner status
docker compose exec runner gitlab-runner verify

# Full health check
./scripts/verify.sh
```

## Multi-Runner (Future)

Multiple runners can be deployed by extending `config.toml` with additional
`[[runners]]` sections. A multi-runner provisioning script is planned for
Phase 3.
