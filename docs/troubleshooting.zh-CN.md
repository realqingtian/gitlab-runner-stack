# 故障排除

[English](troubleshooting.md) | **简体中文**

## Runner 未出现在 GitLab 中

### 症状
Runner 在 GitLab 界面显示为"从未联系"或离线。

### 修复方法

1. 验证 `.env` 中的令牌和地址：
```bash
grep -E 'GITLAB_URL|RUNNER_AUTH_TOKEN|REGISTRATION_TOKEN' .env
```

2. 重新注册 Runner：
```bash
./scripts/register-runner.sh
```

3. 查看 Runner 日志：
```bash
docker compose logs runner
```

4. 从容器内部验证：
```bash
docker compose exec runner gitlab-runner verify
```

---

## "Cannot connect to the Docker daemon"

### 症状
CI 任务报错 `Cannot connect to the Docker daemon at tcp://docker:2376`。

### 修复方法

1. 检查 Docker 守护进程容器是否健康：
```bash
docker compose ps
```

2. 查看 Docker 守护进程日志：
```bash
docker compose logs docker
```

3. 验证 TLS 证书：
```bash
openssl verify -CAfile certs/ca/ca.pem certs/server/server-cert.pem certs/client/cert.pem
```

4. 如果证书损坏则重新生成：
```bash
rm -rf certs/ca/* certs/server/* certs/client/*
./scripts/generate-certs.sh
docker compose restart
```

---

## 证书错误（x509）

### 症状
`x509: certificate signed by unknown authority` 或 `x509: certificate has expired`。

### 修复方法

重新生成所有证书：
```bash
./scripts/generate-certs.sh
docker compose restart
```

如果从自定义主机名连接，请先在 `.env` 中更新 `DOCKER_TLS_HOST`。

---

## Docker 守护进程无法启动

### 症状
`docker` 容器退出或持续不健康。

### 修复方法

1. 检查你的文件系统是否支持 `overlay2`：
```bash
docker compose logs docker | grep -i storage
```

2. 尝试 `vfs` 存储驱动：
```bash
# 在 .env 中
DOCKER_DRIVER=vfs
```

3. 检查权限问题：
```bash
ls -la docker/data/
```

---

## 磁盘空间不足

### 症状
构建失败，容器无法启动，`no space left on device`。

### 修复方法

运行垃圾回收：
```bash
./scripts/prune.sh
```

检查磁盘使用：
```bash
docker compose exec docker docker system df
```

在 `.env` 中调整保留策略：
```bash
# 保留更少的构建缓存历史
PRUNE_CACHE_RETENTION=24h
```

---

## 内存使用过高

### 症状
宿主机内存不足，发生 OOM Kill。

### 修复方法

1. 降低并发数：
```bash
# 在 .env 中
RUNNER_CONCURRENT=2
```
然后重新注册：
```bash
./scripts/register-runner.sh
```

2. 限制 Docker 守护进程内存：
```bash
# 在 .env 中
DOCKER_MEMORY=4g
```

---

## 残留的 CI 任务容器

### 症状
失败任务后积累了大量残留容器。

### 修复方法

```bash
./scripts/prune.sh
```

或手动清理：
```bash
docker compose exec docker docker container prune -f
```

---

## 完整验证

运行健康检查脚本进行完整诊断：

```bash
./scripts/verify.sh
```

如果所有方法都失败，干净重启通常能解决：
```bash
docker compose down
docker compose up -d
./scripts/register-runner.sh
```
