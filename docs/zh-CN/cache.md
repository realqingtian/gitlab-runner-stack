# 缓存指南

[English](../en/cache.md) | **简体中文**

## 概述

本 Stack 为所有主流编程语言提供持久化构建缓存。缓存目录通过 Runner 的 `config.toml`
挂载到每个 CI 任务容器中，因此下载的依赖和构建产物可以跨任务持久保存。

## 支持的缓存

| 语言 | 容器路径 | 宿主机路径 |
|---|---|---|
| Maven | `/root/.m2` | `cache/maven/` |
| Gradle | `/root/.gradle` | `cache/gradle/` |
| npm | `/root/.npm` | `cache/npm/` |
| pnpm | `/root/.local/share/pnpm` | `cache/pnpm/` |
| Yarn | `/usr/local/share/.cache/yarn` | `cache/yarn/` |
| Pip | `/root/.cache/pip` | `cache/pip/` |
| Cargo（Rust） | `/usr/local/cargo/registry` | `cache/cargo/` |
| Go | `/root/.cache/go-build`、`/root/go/pkg/mod` | `cache/go/` |
| Composer（PHP） | `/root/.composer/cache` | `cache/composer/` |
| NuGet（.NET） | `/root/.nuget/packages` | `cache/nuget/` |
| Flutter（pub） | `/root/.pub-cache` | `cache/pub/` |
| ccache（C/C++） | `/root/.ccache` | `cache/ccache/` |
| Docker 层 | （由 BuildKit 处理） | `cache/docker/` |
| Buildx | （由 buildx 处理） | `cache/buildx/` |

## 工作原理

Runner 的 `config.toml.template` 将宿主机 `cache/` 目录中的每个缓存子目录挂载到
CI 任务容器中。当一个任务下载 Maven 依赖时，它们会存放到 `/root/.m2/repository`，
映射到宿主机的 `cache/maven/repository`。下一个需要相同依赖的任务会发现它们已经存在。

## 在 CI 中使用缓存

请查看 `examples/` 目录中开箱即用的 `.gitlab-ci.yml` 模板。
关键是设置正确的环境变量和缓存路径。

**Maven：**
```yaml
variables:
  MAVEN_OPTS: "-Dmaven.repo.local=/root/.m2/repository"
script:
  - mvn $MAVEN_OPTS compile
```

**npm：**
```yaml
script:
  - npm ci --cache /root/.npm --prefer-offline
```

**Pip：**
```yaml
variables:
  PIP_CACHE_DIR: "/root/.cache/pip"
script:
  - pip install -r requirements.txt
```

**Go：**
```yaml
variables:
  GOPATH: /root/go
script:
  - go mod download
  - go build ./...
```

## 清除缓存

清除特定语言的缓存：

```bash
rm -rf cache/maven/*
```

清除所有缓存：

```bash
rm -rf cache/*/
```

## Docker 层缓存

Docker 层缓存由 Docker Engine 的 BuildKit 集成自动处理。构建层持久化在
`docker/data/` 中，并在构建之间复用。

要跨任务共享层缓存，请使用 BuildKit 的 `--cache-from` 和 `--cache-to` 参数配合镜像仓库。
参见 `examples/docker/.gitlab-ci.yml`。
