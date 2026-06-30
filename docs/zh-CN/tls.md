# TLS / 证书指南

[English](../en/tls.md) | **简体中文**

## 概述

本 Stack 在 GitLab Runner 与 Docker Engine 守护进程之间使用**双向 TLS**。
这比挂载宿主机 Docker Socket 更安全，因为 CI 任务无法直接访问宿主机。

## 证书架构

```
certs/
├── ca/          证书颁发机构（信任根）
│   ├── ca.pem       CA 公钥证书
│   └── ca-key.pem   CA 私钥（务必保密！）
├── server/      服务器证书（用于 dockerd）
│   ├── ca.pem           CA 证书（复制给 dockerd）
│   ├── cert.pem  服务器证书
│   └── key.pem   服务器私钥
└── client/      客户端证书（用于 Runner + CI 任务）
    ├── ca.pem       CA 证书
    ├── cert.pem     客户端证书
    └── key.pem      客户端私钥
```

## 工作原理

1. `docker:dind` 入口脚本检测到 `DOCKER_TLS_CERTDIR=/certs`，自动启用 TLS 模式，
   从 `/certs/server/` 读取服务器证书，在端口 **2376** 上提供服务。

2. GitLab Runner 使用 `/certs/client/` 中的客户端证书连接到 `tcp://docker:2376`。

3. CI 任务容器以只读方式接收 `/certs/client` 中的客户端证书，
   以及 `DOCKER_HOST`/`DOCKER_TLS_VERIFY`/`DOCKER_CERT_PATH` 环境变量，
   因此它们也能安全地与守护进程通信。

## 生成证书

```bash
./scripts/generate-certs.sh
```

此脚本是幂等的 —— 它会干净地重新生成所有内容。证书默认有效期为 10 年（3650 天）。

## 配置

| 变量 | 默认值 | 说明 |
|---|---|---|
| `CERT_VALIDITY_DAYS` | `3650` | 证书有效期 |
| `DOCKER_TLS_HOST` | `docker` | 服务器证书 SAN 中的主机名 |
| `CERT_KEY_SIZE` | `4096` | RSA 密钥长度 |

## 自定义主机名

如果需要从 Compose 网络外部连接 Docker 守护进程（例如调试），请在服务器证书中
添加宿主机的 IP 或域名：

```bash
# 在 .env 中
DOCKER_TLS_HOST=10.0.0.5
```

然后重新生成：
```bash
rm -rf certs/ca/* certs/server/* certs/client/*
./scripts/generate-certs.sh
```

## 验证证书

```bash
openssl verify -CAfile certs/ca/ca.pem \
    certs/server/cert.pem \
    certs/client/cert.pem
```

三个都应该输出 `OK`。

## 证书轮换

要在不停机的情况下轮换证书：

```bash
./scripts/generate-certs.sh
docker compose restart
```

Runner 会在重启后自动重新连接。
