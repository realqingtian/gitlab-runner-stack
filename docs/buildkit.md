# BuildKit Guide

## Overview

BuildKit is enabled in the Docker daemon by default via `daemon.json`:

```json
{
  "features": {
    "buildkit": true
  }
}
```

BuildKit provides faster, more efficient Docker builds with:
- Parallel build stage execution
- Smarter layer caching
- Better garbage collection
- Multi-platform builds (with buildx)

## Using BuildKit in CI Jobs

### Automatic (docker build)

BuildKit is used automatically when `DOCKER_BUILDKIT=1` is set. The
runner's `config.toml` already sets this for all CI job containers.

```yaml
# .gitlab-ci.yml
build:
  image: docker:29
  script:
    - docker build -t myapp .
```

### Buildx (advanced builds)

For multi-platform builds, layer cache export, and other advanced features:

```yaml
build:
  image: docker:29
  script:
    - docker buildx create --use
    - docker buildx build --platform linux/amd64,linux/arm64 -t myapp .
```

## Layer Caching Strategies

### Local cache (default)

Build layers are cached in `docker/data/` and persist across jobs
automatically.

### Registry cache

Export/import cache layers from a container registry:

```yaml
docker buildx build \
  --cache-from=type=registry,ref=myregistry/app:cache \
  --cache-to=type=registry,ref=myregistry/app:cache,mode=max \
  -t myapp .
```

This enables cache sharing across multiple runners.

## Garbage Collection

The Docker daemon automatically manages BuildKit cache. To manually clean:

```bash
./scripts/prune.sh
```

This removes old build cache while preserving recently-used layers (configurable
via `PRUNE_CACHE_RETENTION` in `.env`).
