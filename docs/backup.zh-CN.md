# 备份与恢复指南

[English](backup.md) | **简体中文**

## 备份

### 标准备份（仅配置 + 证书）

```bash
./scripts/backup.sh
```

备份内容：
- `runner/config/` — Runner 配置
- `certs/` — TLS 证书
- `docker/daemon.json` — 守护进程配置
- `compose.yaml` — Stack 定义
- `.env` — 环境配置

输出文件：`backups/gitlab-runner-stack_YYYYMMDD_HHMMSS.tar.gz`

### 完整备份（包含数据和缓存）

```bash
./scripts/backup.sh --full
```

额外包含：
- `docker/data/` — Docker 镜像、层、构建缓存
- `cache/` — 所有语言构建缓存

这可能会非常大（数 GB）。仅在迁移到新主机时使用。

### 保留策略

此脚本自动保留最近 10 个备份，删除更早的备份。

## 恢复

```bash
./scripts/restore.sh backups/gitlab-runner-stack_20240101_120000.tar.gz
```

此脚本会：
1. 要求确认（会覆盖现有数据）
2. 停止所有服务
3. 解压备份
4. 重启服务

## 自动化（cron）

安排每日备份：

```bash
# 编辑 crontab
crontab -e

# 每天凌晨 2 点备份
0 2 * * * cd /path/to/gitlab-runner-stack && ./scripts/backup.sh
```

## 不应备份的内容

以下目录已被 gitignore，不应备份：
- `docker/data/` — 很大，可通过镜像拉取重新生成（需要时用 `--full`）
- `cache/` — 可通过包仓库重新生成（需要时用 `--full`）
- `backups/` — 避免备份备份文件

## 迁移到新主机

```bash
# 在旧主机上：
./scripts/backup.sh --full

# 将备份复制到新主机：
scp backups/gitlab-runner-stack_*.tar.gz newhost:/path/to/gitlab-runner-stack/backups/

# 在新主机上：
git clone <repo-url> gitlab-runner-stack
cd gitlab-runner-stack
./scripts/init.sh
./scripts/restore.sh backups/gitlab-runner-stack_*.tar.gz
```
