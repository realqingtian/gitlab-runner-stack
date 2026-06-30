# Runner 配置指南

[English](runner.md) | **简体中文**

## config.toml

Runner 的行为由 `runner/config/config.toml` 控制，该文件由 `register-runner.sh`
从 `runner/config/config.toml.template` 渲染生成。

**切勿直接编辑 `config.toml`** —— 你的修改会被覆盖。
请改为编辑模板或 `.env` 变量。

## 关键设置

### 全局

| 设置 | .env 变量 | 默认值 | 说明 |
|---|---|---|---|
| `concurrent` | `RUNNER_CONCURRENT` | `4` | 同时运行的任务数 |
| `check_interval` | — | `0` | GitLab 轮询间隔秒数（0 = 默认） |
| `log_level` | — | `info` | 日志详细程度 |

### 单 Runner

| 设置 | .env 变量 | 默认值 | 说明 |
|---|---|---|---|
| `url` | `GITLAB_URL` | — | GitLab 服务器地址 |
| `token` | `RUNNER_AUTH_TOKEN` | — | 认证令牌 |
| `name` | `RUNNER_NAME` | `gitlab-runner-01` | 显示名称 |
| `limit` | `RUNNER_LIMIT` | `0` | 最大接受任务数（0 = 无限制） |

### Docker 执行器

| 设置 | .env 变量 | 默认值 | 说明 |
|---|---|---|---|
| `image` | `RUNNER_DEFAULT_IMAGE` | `alpine:latest` | 任务备用镜像 |
| `privileged` | `RUNNER_PRIVILEGED` | `true` | DinD 特权模式 |
| `host` | — | `tcp://docker:2376` | Docker 守护进程地址 |
| `tls_verify` | — | `true` | 要求 TLS 验证 |
| `pull_policy` | — | `if-not-present` | 镜像拉取策略 |

## 注册

### 新版认证令牌（GitLab 16.0+）

1. 在 GitLab 界面创建 Runner
2. 复制认证令牌
3. 在 `.env` 中设置 `RUNNER_AUTH_TOKEN`
4. 运行 `./scripts/register-runner.sh`

令牌直接写入 `config.toml` —— 无需 API 调用。

### 旧版注册令牌（GitLab < 16.0）

1. 从 GitLab 获取注册令牌
2. 在 `.env` 中设置 `REGISTRATION_TOKEN`
3. 运行 `./scripts/register-runner.sh`

此脚本在容器内调用 `gitlab-runner register`，该命令会联系 GitLab
将令牌交换为永久的 Runner 令牌。

## 重新注册

要更新 Runner（新令牌、不同 GitLab 实例、更改标签）：

```bash
# 编辑 .env，然后：
./scripts/register-runner.sh
```

## 验证

```bash
# 检查 Runner 状态
docker compose exec runner gitlab-runner verify

# 完整健康检查
./scripts/verify.sh
```

## 多 Runner（未来）

可以通过在 `config.toml` 中扩展额外的 `[[runners]]` 部分来部署多个 Runner。
多 Runner 供应脚本计划在第三阶段实现。
