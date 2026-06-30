# TLS / Certificate Guide

## Overview

This stack uses **mutual TLS** between the GitLab Runner and the Docker
Engine daemon. This is more secure than mounting the host Docker socket,
because CI jobs never get direct access to the host.

## Certificate Architecture

```
certs/
├── ca/          Certificate Authority (root of trust)
│   ├── ca.pem       CA public certificate
│   └── ca-key.pem   CA private key (keep secret!)
├── server/      Server certificate (for dockerd)
│   ├── ca.pem           CA cert (copied for dockerd)
│   ├── server-cert.pem  Server certificate
│   └── server-key.pem   Server private key
└── client/      Client certificate (for runner + CI jobs)
    ├── ca.pem       CA cert
    ├── cert.pem     Client certificate
    └── key.pem      Client private key
```

## How It Works

1. The `docker:dind` entrypoint sees `DOCKER_TLS_CERTDIR=/certs` and
   automatically enables TLS mode, reading server certs from
   `/certs/server/` and serving on port **2376**.

2. The GitLab Runner connects to `tcp://docker:2376` using client certs
   from `/certs/client/`.

3. CI job containers receive the client certs at `/certs/client` (read-only)
   and the `DOCKER_HOST`/`DOCKER_TLS_VERIFY`/`DOCKER_CERT_PATH` environment
   variables, so they can also talk to the daemon securely.

## Generating Certificates

```bash
./scripts/generate-certs.sh
```

This is idempotent — it regenerates everything cleanly. Certificates are
valid for 10 years (3650 days) by default.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `CERT_VALIDITY_DAYS` | `3650` | Certificate validity period |
| `DOCKER_TLS_HOST` | `docker` | Hostname in server cert SAN |
| `CERT_KEY_SIZE` | `4096` | RSA key size |

## Custom Hostnames

If you need to connect to the Docker daemon from outside the Compose network
(e.g. for debugging), add the host's IP or domain to the server certificate:

```bash
# In .env
DOCKER_TLS_HOST=10.0.0.5
```

Then regenerate:
```bash
rm -rf certs/ca/* certs/server/* certs/client/*
./scripts/generate-certs.sh
```

## Verifying Certificates

```bash
openssl verify -CAfile certs/ca/ca.pem \
    certs/server/server-cert.pem \
    certs/client/cert.pem
```

All three should print `OK`.

## Certificate Rotation

To rotate certificates without downtime:

```bash
./scripts/generate-certs.sh
docker compose restart
```

The runner reconnects automatically after restart.
