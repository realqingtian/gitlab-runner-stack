#!/bin/sh
##############################################################################
# generate-certs.sh — Generate TLS certificates for Docker Remote (DinD)
##############################################################################
# Creates a full PKI:
#   certs/ca/       — CA certificate and key (the root of trust)
#   certs/server/   — server certificate for the Docker daemon (dockerd)
#   certs/client/   — client certificate for GitLab Runner / CI jobs
#
# Idempotent: re-running regenerates everything cleanly.
##############################################################################
set -eu

## ---------------------------------------------------------------------------
## Resolve project root (parent of scripts/)
## ---------------------------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

CERTS_DIR="$PROJECT_ROOT/certs"
CA_DIR="$CERTS_DIR/ca"
SERVER_DIR="$CERTS_DIR/server"
CLIENT_DIR="$CERTS_DIR/client"

## ---------------------------------------------------------------------------
## Configuration
## ---------------------------------------------------------------------------
VALIDITY_DAYS="${CERT_VALIDITY_DAYS:-3650}"
TLS_HOST="${DOCKER_TLS_HOST:-docker}"
KEY_SIZE="${CERT_KEY_SIZE:-4096}"

## ---------------------------------------------------------------------------
## Helpers
## ---------------------------------------------------------------------------
log()  { printf '[certs]  %s\n' "$*"; }
err()  { printf '[certs]  ERROR: %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

command -v openssl >/dev/null 2>&1 || die "openssl is required but not found."

## ---------------------------------------------------------------------------
## Prepare directories
## ---------------------------------------------------------------------------
mkdir -p "$CA_DIR" "$SERVER_DIR" "$CLIENT_DIR"

## ---------------------------------------------------------------------------
## 1. Certificate Authority
## ---------------------------------------------------------------------------
log "Generating CA (valid ${VALIDITY_DAYS} days)..."

openssl genrsa -out "$CA_DIR/ca-key.pem" "$KEY_SIZE" 2>/dev/null
chmod 600 "$CA_DIR/ca-key.pem"

openssl req -new -x509 -days "$VALIDITY_DAYS" \
    -key "$CA_DIR/ca-key.pem" \
    -out "$CA_DIR/ca.pem" \
    -subj "/CN=gitlab-runner-stack-CA" 2>/dev/null

## ---------------------------------------------------------------------------
## 2. Server certificate (for dockerd)
## ---------------------------------------------------------------------------
# The DinD entrypoint (dockerd-entrypoint.sh) checks for these exact filenames:
#   ca.pem  cert.pem  key.pem
#
# The cert must include the Docker service name as SAN so the runner can
# connect via tcp://docker:2376.
log "Generating server certificate (CN=$TLS_HOST)..."

openssl genrsa -out "$SERVER_DIR/key.pem" "$KEY_SIZE" 2>/dev/null
chmod 600 "$SERVER_DIR/key.pem"

openssl req -new \
    -key "$SERVER_DIR/key.pem" \
    -out "$SERVER_DIR/server.csr" \
    -subj "/CN=$TLS_HOST" 2>/dev/null

# Build SAN extension config (covers hostname, localhost, and IPs)
EXT_CONF="$SERVER_DIR/san.ext"
cat > "$EXT_CONF" <<EOF
subjectAltName = @alt_names
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = $TLS_HOST
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

openssl x509 -req -days "$VALIDITY_DAYS" \
    -in "$SERVER_DIR/server.csr" \
    -CA "$CA_DIR/ca.pem" \
    -CAkey "$CA_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$SERVER_DIR/cert.pem" \
    -extfile "$EXT_CONF" 2>/dev/null

# dockerd expects the CA in the server dir as well
cp "$CA_DIR/ca.pem" "$SERVER_DIR/ca.pem"

## ---------------------------------------------------------------------------
## 3. Client certificate (for GitLab Runner)
## ---------------------------------------------------------------------------
# The Docker client expects these filenames:
#   ca.pem  cert.pem  key.pem
log "Generating client certificate..."

openssl genrsa -out "$CLIENT_DIR/key.pem" "$KEY_SIZE" 2>/dev/null
chmod 600 "$CLIENT_DIR/key.pem"

openssl req -new \
    -key "$CLIENT_DIR/key.pem" \
    -out "$CLIENT_DIR/client.csr" \
    -subj "/CN=gitlab-runner-client" 2>/dev/null

EXT_CONF_CLIENT="$CLIENT_DIR/client.ext"
cat > "$EXT_CONF_CLIENT" <<EOF
extendedKeyUsage = clientAuth
EOF

openssl x509 -req -days "$VALIDITY_DAYS" \
    -in "$CLIENT_DIR/client.csr" \
    -CA "$CA_DIR/ca.pem" \
    -CAkey "$CA_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$CLIENT_DIR/cert.pem" \
    -extfile "$EXT_CONF_CLIENT" 2>/dev/null

cp "$CA_DIR/ca.pem" "$CLIENT_DIR/ca.pem"

## ---------------------------------------------------------------------------
## 4. Cleanup intermediates
## ---------------------------------------------------------------------------
rm -f "$SERVER_DIR/server.csr" "$SERVER_DIR/san.ext"
rm -f "$CLIENT_DIR/client.csr" "$CLIENT_DIR/client.ext"
rm -f "$CA_DIR/ca.srl" "$SERVER_DIR/../ca.srl" 2>/dev/null || true

## ---------------------------------------------------------------------------
## 5. Summary
## ---------------------------------------------------------------------------
log "Certificates generated successfully:"
log "  CA:     $CA_DIR/ca.pem"
log "  Server: $SERVER_DIR/{ca,cert,key}.pem"
log "  Client: $CLIENT_DIR/{ca,cert,key}.pem"
log ""
log "Verify:  openssl verify -CAfile $CA_DIR/ca.pem $SERVER_DIR/cert.pem $CLIENT_DIR/cert.pem"
