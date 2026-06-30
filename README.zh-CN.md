<div align="center">

# gitlab-runner-stack

### 一键部署生产级 GitLab Runner（隔离式 Docker Engine）

[English](README.md) | **简体中文**

</div>

---

## 项目简介

**gitlab-runner-stack** 使用 Docker Compose 部署一套完整的 GitLab CI Runner 环境 ——
无需挂载宿主机 Docker Socket，无需手动编辑证书。

该 Stack 运行一个独立的 Docker Engine（DinD），通过双向 TLS 加密通信，GitLab Runner
通过网络连接到它。所有数据 —— Docker 镜像、构建缓存、Runner 配置、TLS 证书 ——
都存放在项目目录内，方便备份和迁移。

```
┌──────────────────────────────────────────────────┐
│                     宿主机                        │
│                                                   │
│  ┌─────────────┐       ┌────────────────────┐     │
│  │   Runner    │──────▶│   Docker Engine    │     │
│  │ (gitlab-    │ TLS   │   (DinD + TLS)     │     │
│  │  runner)    │:2376  │                    │     │
│  └──────┬──────┘       └────────┬───────────┘     │
│         │                       │                  │
│         │ 轮询                   │ 创建             │
│         ▼                       ▼                  │
│  ┌──────────────┐       ┌────────────────────┐     │
│  │   GitLab     │       │   CI 任务           │     │
│  │   服务器      │       │   容器              │     │
│  └──────────────┘       └────────────────────┘     │
│                                                   │
│  所有数据存放在 ./docker ./runner ./certs ./cache  │
└──────────────────────────────────────────────────┘
```

## 功能特性

- **Docker Engine 29** — 独立的 DinD 守护进程，使用 overlay2 存储驱动
- **双向 TLS** — 自动生成 CA、服务器端和客户端证书
- **GitLab Runner** — 同时支持新版认证令牌（16.0+）和旧版注册令牌
- **BuildKit + Buildx** — 守护进程内置，支持更快的多平台构建
- **持久化缓存** — Maven、Gradle、npm、pnpm、Yarn、Pip、Cargo、Go、Composer、NuGet、Flutter、ccache
- **健康检查** — Docker 守护进程和 Runner 均由 Compose 监控
- **Prometheus 指标** — Runner 在 :9252 端口暴露监控指标
- **监控扩展** — 可选的 Prometheus、Grafana 和 AlertManager 监控套件
- **备份与恢复** — 一键备份和恢复脚本
- **垃圾回收** — 可配置的 Docker GC，支持缓存保留策略
- **一键更新** — 拉取最新镜像并重建容器，配置和数据不受影响
- **日志轮转** — 可配置的逐服务日志文件轮转
- **数据项目内管理** — 所有数据都在项目目录内，不散落在宿主机各处
- **幂等脚本** — 可安全地多次运行

## 快速开始

```bash
git clone https://github.com/realqingtian/gitlab-runner-stack.git gitlab-runner-stack
cd gitlab-runner-stack

# 1. 创建配置文件
cp .env.example .env

# 2. 编辑 .env — 设置 GitLab 地址和 Runner 令牌
vi .env

# 3. 初始化（生成证书、创建目录）
./scripts/init.sh

# 4. 启动
docker compose up -d

# 5. 注册 Runner
./scripts/register-runner.sh
```

完成。Runner 将在 GitLab 项目的 **Settings → CI/CD → Runners** 页面显示为在线状态。

## 获取 Runner 令牌

### GitLab 16.0+（推荐）

1. 进入 GitLab 项目或组的 **Settings → CI/CD → Runners**
2. 点击 **New project runner**（或 **New group runner**）
3. 选择标签，然后点击 **Create runner**
4. 复制显示的 **authentication token**（认证令牌）
5. 将其粘贴到 `.env` 的 `RUNNER_AUTH_TOKEN` 中

### GitLab < 16.0（旧版）

1. 进入 **Settings → CI/CD → Runners**
2. 点击 **New project runner** 获取注册令牌
3. 将其粘贴到 `.env` 的 `REGISTRATION_TOKEN` 中

## 配置

所有配置都在 `.env` 文件中。主要变量：

| 变量 | 说明 | 默认值 |
|---|---|---|
| `GITLAB_URL` | GitLab 服务器地址 | `https://gitlab.example.com` |
| `RUNNER_AUTH_TOKEN` | Runner 认证令牌（16.0+） | _（空）_ |
| `REGISTRATION_TOKEN` | 旧版注册令牌 | _（空）_ |
| `RUNNER_NAME` | Runner 显示名称 | `gitlab-runner-01` |
| `RUNNER_TAGS` | 标签（逗号分隔） | `docker,linux` |
| `RUNNER_CONCURRENT` | 并发任务数 | `4` |
| `RUNNER_DEFAULT_IMAGE` | 默认 CI 镜像 | `alpine:latest` |
| `RUNNER_PRIVILEGED` | CI 容器特权模式 | `true` |
| `DOCKER_DIND_IMAGE` | Docker Engine 镜像 | `docker:29-dind` |
| `DOCKER_DRIVER` | 存储驱动 | `overlay2` |

完整列表请查看 [`.env.example`](.env.example)。

## 架构

### 为什么使用独立的 Docker 守护进程？

将宿主机的 Docker Socket（`/var/run/docker.sock`）挂载到 Runner 中很常见，但
**不安全** —— 任何 CI 任务都能获得宿主机的完整 root 权限。本 Stack 使用容器内的独立
Docker Engine（DinD）并通过双向 TLS 认证。CI 任务在此独立守护进程创建的容器中运行，
所有数据都保留在项目目录内。

### TLS 证书流程

```
certs/ca/       CA 根证书（签发服务器端和客户端证书）
certs/server/   dockerd 服务器证书（ca.pem, server-cert.pem, server-key.pem）
certs/client/   Runner 客户端证书（ca.pem, cert.pem, key.pem）
```

证书由 `scripts/generate-certs.sh` 生成，默认有效期为 10 年（可通过 `CERT_VALIDITY_DAYS` 配置）。

## 目录结构

```
gitlab-runner-stack/
│
├── compose.yaml                  # Docker Compose — 引擎 + Runner
├── compose.monitoring.yaml       # 监控扩展（可选）
├── .env.example                  # 配置模板
├── .gitignore
├── README.md                     # 英文文档
├── README.zh-CN.md               # 中文文档
├── LICENSE
│
├── docker/
│   ├── daemon.json               # Docker 守护进程配置
│   ├── data/                     # Docker 镜像、层（已 gitignore）
│   └── buildkit/                 # BuildKit 数据（已 gitignore）
│
├── runner/
│   ├── config/
│   │   └── config.toml.template  # Runner 配置模板（由 register-runner.sh 渲染）
│   ├── cache/                    # Runner 本地缓存（已 gitignore）
│   └── hooks/                    # 自定义 Runner 钩子
│
├── certs/                        # TLS 证书（已 gitignore）
│   ├── ca/
│   ├── server/
│   └── client/
│
├── cache/                        # 共享构建缓存（已 gitignore）
│   ├── maven/  gradle/  npm/  pnpm/  yarn/
│   ├── pip/  cargo/  go/  composer/  nuget/
│   └── pub/  ccache/  docker/  buildx/
│
├── scripts/
│   ├── init.sh                   # 初始化 Stack
│   ├── generate-certs.sh         # 生成 TLS 证书
│   ├── register-runner.sh        # 注册 Runner
│   ├── verify.sh                 # 健康检查
│   ├── backup.sh                 # 备份数据
│   ├── restore.sh                # 从备份恢复
│   ├── prune.sh                  # 垃圾回收
│   └── update.sh                 # 更新到最新镜像
│
├── monitoring/                   # Prometheus + Grafana + AlertManager（可选）
│   ├── prometheus/
│   ├── grafana/
│   └── alertmanager/
│
├── examples/                     # CI 模板（.gitlab-ci.yml）
│   ├── java/  node/  python/  golang/  rust/
│   └── php/  dotnet/  flutter/  docker/
│
└── docs/
    ├── en/                       # 英文文档
    │   ├── install.md  tls.md  cache.md
    │   ├── buildkit.md  runner.md
    │   └── backup.md  troubleshooting.md
    └── zh-CN/                    # 中文文档
        ├── install.md  tls.md  cache.md
        ├── buildkit.md  runner.md
        └── backup.md  troubleshooting.md
```

## 常用操作

```bash
# 查看日志
docker compose logs -f runner
docker compose logs -f docker

# 查看状态
docker compose ps

# 重启服务
docker compose restart runner

# 停止所有服务
docker compose down

# 停止并删除所有数据（危险！）
docker compose down -v
```

## 镜像加速与私有仓库

在 `.env` 中设置：

```bash
# 使用镜像加速
DOCKER_REGISTRY_MIRRORS=https://mirror.gcr.io

# 允许不带 TLS 的本地仓库
DOCKER_INSECURE_REGISTRIES=registry.local:5000
```

然后相应地更新 `docker/daemon.json`。

## 故障排除

### Runner 在 GitLab 中显示"从未联系"

检查 `.env` 中的 `GITLAB_URL` 和 `RUNNER_AUTH_TOKEN` 是否正确，然后：

```bash
./scripts/register-runner.sh
docker compose logs runner
```

### CI 任务报错"Cannot connect to the Docker daemon"

Docker 守护进程容器可能还在启动中。检查健康状态：

```bash
docker compose ps
docker compose logs docker
```

### 证书错误

重新生成证书：

```bash
rm -rf certs/ca/* certs/server/* certs/client/*
./scripts/generate-certs.sh
docker compose restart
```

## 运维管理

```bash
# 完整健康检查
./scripts/verify.sh

# 备份（配置 + 证书）
./scripts/backup.sh

# 完整备份（包含数据 + 缓存）
./scripts/backup.sh --full

# 恢复
./scripts/restore.sh backups/gitlab-runner-stack_*.tar.gz

# 垃圾回收
./scripts/prune.sh

# 更新到最新镜像（保留配置和数据）
./scripts/update.sh
```

### 监控

启用可观测性套件：

```bash
docker compose -f compose.yaml -f compose.monitoring.yaml up -d
```

| 服务 | 地址 | 默认凭证 |
|---|---|---|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | — |
| AlertManager | http://localhost:9093 | — |

## CI 示例

`examples/` 目录中提供开箱即用的 `.gitlab-ci.yml` 模板：

| 目录 | 语言/平台 |
|---|---|
| `examples/java/` | Java（Maven + Gradle） |
| `examples/node/` | Node.js |
| `examples/python/` | Python |
| `examples/golang/` | Go |
| `examples/rust/` | Rust |
| `examples/php/` | PHP |
| `examples/dotnet/` | .NET |
| `examples/flutter/` | Flutter |
| `examples/docker/` | Docker 构建 |

## 文档

| 文档 | 内容 |
|---|---|
| 文档 | 内容 |
|---|---|
| [install](docs/en/install.md) / [中文](docs/zh-CN/install.md) | 详细安装指南 |
| [tls](docs/en/tls.md) / [中文](docs/zh-CN/tls.md) | TLS 证书架构与管理 |
| [cache](docs/en/cache.md) / [中文](docs/zh-CN/cache.md) | 构建缓存配置 |
| [buildkit](docs/en/buildkit.md) / [中文](docs/zh-CN/buildkit.md) | BuildKit 和 Buildx 使用 |
| [runner](docs/en/runner.md) / [中文](docs/zh-CN/runner.md) | Runner 配置参考 |
| [backup](docs/en/backup.md) / [中文](docs/zh-CN/backup.md) | 备份与恢复流程 |
| [troubleshooting](docs/en/troubleshooting.md) / [中文](docs/zh-CN/troubleshooting.md) | 常见问题与解决方案 |

## 开源协议

[MIT](LICENSE)
