# BuildKit 指南

[English](buildkit.md) | **简体中文**

## 概述

BuildKit 通过 `daemon.json` 在 Docker 守护进程中默认启用：

```json
{
  "features": {
    "buildkit": true
  }
}
```

BuildKit 提供更快、更高效的 Docker 构建：
- 并行构建阶段执行
- 更智能的层缓存
- 更好的垃圾回收
- 多平台构建（配合 buildx）

## 在 CI 任务中使用 BuildKit

### 自动模式（docker build）

当设置 `DOCKER_BUILDKIT=1` 时，BuildKit 会自动启用。Runner 的 `config.toml`
已为所有 CI 任务容器设置了此变量。

```yaml
# .gitlab-ci.yml
build:
  image: docker:29
  script:
    - docker build -t myapp .
```

### Buildx（高级构建）

用于多平台构建、层缓存导出和其他高级功能：

```yaml
build:
  image: docker:29
  script:
    - docker buildx create --use
    - docker buildx build --platform linux/amd64,linux/arm64 -t myapp .
```

## 层缓存策略

### 本地缓存（默认）

构建层缓存在 `docker/data/` 中，并自动在任务之间持久保存。

### 镜像仓库缓存

从容器镜像仓库导出/导入缓存层：

```yaml
docker buildx build \
  --cache-from=type=registry,ref=myregistry/app:cache \
  --cache-to=type=registry,ref=myregistry/app:cache,mode=max \
  -t myapp .
```

这可以实现跨多个 Runner 的缓存共享。

## 垃圾回收

Docker 守护进程会自动管理 BuildKit 缓存。手动清理：

```bash
./scripts/prune.sh
```

此命令会删除旧的构建缓存，同时保留最近使用的层（可通过 `.env` 中的
`PRUNE_CACHE_RETENTION` 配置）。
