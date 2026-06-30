# Caching Guide

**English** | [简体中文](../zh-CN/cache.md)

## Overview

The stack provides persistent build caches for all major programming
languages. Cache directories are mounted into every CI job container via
the runner's `config.toml`, so downloaded dependencies and build artifacts
persist across jobs.

## Supported Caches

| Language | Container Path | Host Path |
|---|---|---|
| Maven | `/root/.m2` | `cache/maven/` |
| Gradle | `/root/.gradle` | `cache/gradle/` |
| npm | `/root/.npm` | `cache/npm/` |
| pnpm | `/root/.local/share/pnpm` | `cache/pnpm/` |
| Yarn | `/usr/local/share/.cache/yarn` | `cache/yarn/` |
| Bun | `/root/.bun/install/cache` | `cache/bun/` |
| Pip | `/root/.cache/pip` | `cache/pip/` |
| Cargo (Rust) | `/usr/local/cargo/registry` | `cache/cargo/` |
| Go | `/root/.cache/go-build`, `/root/go/pkg/mod` | `cache/go/` |
| Composer (PHP) | `/root/.composer/cache` | `cache/composer/` |
| NuGet (.NET) | `/root/.nuget/packages` | `cache/nuget/` |
| Flutter (pub) | `/root/.pub-cache` | `cache/pub/` |
| ccache (C/C++) | `/root/.ccache` | `cache/ccache/` |
| Docker layers | (handled by BuildKit) | `cache/docker/` |
| Buildx | (handled by buildx) | `cache/buildx/` |

## How It Works

The runner's `config.toml.template` mounts each cache directory from the
host `cache/` folder into CI job containers. When a job downloads Maven
dependencies, they go to `/root/.m2/repository` which maps to
`cache/maven/repository` on the host. The next job that needs the same
dependencies finds them already present.

## Using Caches in CI

See the `examples/` directory for ready-to-use `.gitlab-ci.yml` templates.
The key is to set the correct environment variables and cache paths.

**Maven:**
```yaml
variables:
  MAVEN_OPTS: "-Dmaven.repo.local=/root/.m2/repository"
script:
  - mvn $MAVEN_OPTS compile
```

**npm:**
```yaml
script:
  - npm ci --cache /root/.npm --prefer-offline
```

**Bun:**
```yaml
variables:
  BUN_INSTALL: "/root/.bun"
script:
  - bun install --frozen-lockfile
```

**Pip:**
```yaml
variables:
  PIP_CACHE_DIR: "/root/.cache/pip"
script:
  - pip install -r requirements.txt
```

**Go:**
```yaml
variables:
  GOPATH: /root/go
script:
  - go mod download
  - go build ./...
```

## Clearing Caches

To clear a specific language cache:

```bash
rm -rf cache/maven/*
```

To clear all caches:

```bash
rm -rf cache/*/
```

## Docker Layer Cache

Docker layer caching is handled automatically by the Docker Engine's
BuildKit integration. Build layers persist in `docker/data/` and are
reused across builds.

For cross-job layer cache sharing, use BuildKit's `--cache-from` and
`--cache-to` flags with a registry. See `examples/docker/.gitlab-ci.yml`.
