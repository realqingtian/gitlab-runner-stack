#!/bin/sh
##############################################################################
# refresh-certs.sh — Regenerate TLS certificates and restart containers
##############################################################################
# Convenience wrapper that:
#   1. Regenerates the full TLS PKI via generate-certs.sh
#   2. Force-recreates containers so cert-init re-runs and copies the fresh
#      host certs into the shared named volume, then dockerd/runner reload
#      them from the volume.
#
# Use this after modifying cert parameters (validity, key size, hostname)
# or when recovering from a TLS verification failure.
##############################################################################
set -eu

## ---------------------------------------------------------------------------
## Resolve paths
## ---------------------------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$PROJECT_ROOT"

## ---------------------------------------------------------------------------
## Helpers
## ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { printf "${CYAN}[refresh]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[refresh]${NC} %s\n" "$*"; }
warn()    { printf "${YELLOW}[refresh]${NC} %s\n" "$*"; }
error()   { printf "${RED}[refresh]${NC} %s\n" "$*" >&2; }
die()     { error "$*"; exit 1; }

## ---------------------------------------------------------------------------
## Banner
## ---------------------------------------------------------------------------
printf "\n"
printf "${BOLD}╔══════════════════════════════════════════════════╗${NC}\n"
printf "${BOLD}║  gitlab-runner-stack — Refresh Certificates     ║${NC}\n"
printf "${BOLD}╚══════════════════════════════════════════════════╝${NC}\n"
printf "\n"

## ---------------------------------------------------------------------------
## Detect Docker Compose
## ---------------------------------------------------------------------------
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
    warn "Using docker-compose V1. V2 (docker compose) is recommended."
else
    die "Docker Compose is not installed."
fi

## ---------------------------------------------------------------------------
## 1. Regenerate certificates
## ---------------------------------------------------------------------------
info "Regenerating TLS certificates..."
sh "$SCRIPT_DIR/generate-certs.sh"
success "Certificates regenerated."

## ---------------------------------------------------------------------------
## 2. Restart containers (if running)
## ---------------------------------------------------------------------------
RUNNING=$($COMPOSE_CMD ps --services --filter "status=running" 2>/dev/null || true)

if [ -z "$RUNNING" ]; then
    success "No containers running — nothing to restart."
    printf "\n"
    printf "  Start the stack with: ${CYAN}%s up -d${NC}\n" "$COMPOSE_CMD"
    printf "\n"
    exit 0
fi

info "Containers are running — force-recreating to apply new certificates..."

# Recreate all containers so cert-init re-runs and copies the fresh host
# certs into the shared named volume. A plain `restart` would NOT re-trigger
# cert-init (it has already completed), leaving the volume with stale certs.
$COMPOSE_CMD up -d --force-recreate
success "Containers recreated with fresh certificates."

## ---------------------------------------------------------------------------
## 3. Summary
## ---------------------------------------------------------------------------
printf "\n"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}${BOLD}  Certificates refreshed and containers recreated!${NC}\n"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "\n"
printf "  Verify the stack:\n"
printf "    ${CYAN}./scripts/verify.sh${NC}\n"
printf "\n"
