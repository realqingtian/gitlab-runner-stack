# 安装指南

[English](install.md) | **简体中文**

## 前置条件

- **Docker Engine 24+**（宿主机）
- **Docker Compose V2**（`docker compose`）
- **OpenSSL**（用于证书生成）
- 一个可从宿主机访问的 **GitLab** 实例（CE 或 EE）
- 你的 GitLab 项目或组的 **Runner 令牌**

## 快速安装

```bash
git clone <repo-url> gitlab-runner-stack
cd gitlab-runner-stack

cp .env.example .env

# 编辑 .env — 设置 GITLAB_URL 和 Runner 令牌
vi .env

./scripts/init.sh

docker compose up -d

./scripts/register-runner.sh
```

## 分步说明

### 1. 克隆仓库

```bash
git clone <repo-url> gitlab-runner-stack
cd gitlab-runner-stack
```

### 2. 配置环境变量

```bash
cp .env.example .env
```

打开 `.env` 并设置必填项：

| 变量 | 说明 |
|---|---|
| `GITLAB_URL` | 你的 GitLab 服务器地址 |
| `RUNNER_AUTH_TOKEN` | Runner 认证令牌（GitLab 16.0+） |
| `REGISTRATION_TOKEN` | 旧版注册令牌（GitLab < 16.0） |

### 3. 初始化

```bash
./scripts/init.sh
```

此脚本会：
- 检查前置条件
- 创建所有目录
- 生成 TLS 证书（如果不存在）
- 校验配置

### 4. 启动

```bash
docker compose up -d
```

验证两个容器是否在运行：

```bash
docker compose ps
```

你应该看到 `docker` 和 `runner` 的状态为 `Up`。

### 5. 注册 Runner

```bash
./scripts/register-runner.sh
```

此脚本会用你的凭据渲染 `config.toml` 并重启 Runner。

### 6. 验证

```bash
./scripts/verify.sh
```

在 GitLab 界面 **Settings > CI/CD > Runners** 中查看 —— Runner 应显示为在线（绿色圆圈）。

## 启用监控（可选）

```bash
docker compose -f compose.yaml -f compose.monitoring.yaml up -d
```

访问地址：
- Grafana：http://localhost:3000（默认 admin/admin）
- Prometheus：http://localhost:9090
- AlertManager：http://localhost:9093

## 卸载

```bash
docker compose down

# 删除所有数据（不可逆）
rm -rf docker/data/ cache/ certs/ runner/config/config.toml
```
