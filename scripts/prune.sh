#!/bin/sh
##############################################################################
# prune.sh — Garbage-collect Docker images, containers, and build cache
##############################################################################
# Runs inside the Docker daemon container to clean up:
#   - Stopped containers
#   - Dangling/unused images
#   - Build cache
#   - Unused volumes/networks
#
# Configurable via .env:
#   PRUNE_DRY_RUN=true          — show what would be removed without removing
#   PRUNE_CACHE_RETENTION=72h   — keep build cache used within this window
##############################################################################
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { printf "${CYAN}[prune]${NC}   %s\n" "$*"; }
success() { printf "${GREEN}[prune]${NC}   %s\n" "$*"; }
warn()    { printf "${YELLOW}[prune]${NC}   %s\n" "$*"; }
die()     { printf "${RED}[prune]${NC}   ERROR: %s\n" "$*" >&2; exit 1; }

# Load .env for configuration
[ -f "$PROJECT_ROOT/.env" ] && . "$PROJECT_ROOT/.env" 2>/dev/null || true

DRY_RUN="${PRUNE_DRY_RUN:-false}"
CACHE_RETENTION="${PRUNE_CACHE_RETENTION:-72h}"

if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    die "Docker Compose not found."
fi

# Build flags
SYSTEM_FLAGS="-f"
BUILDER_FLAGS="--all"

if [ "$DRY_RUN" = "true" ]; then
    info "DRY RUN — nothing will be removed."
    SYSTEM_FLAGS=""
    BUILDER_FLAGS="--all --dry-run"
fi

printf "\n${BOLD}Docker Garbage Collection${NC}\n"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

if [ "$DRY_RUN" = "true" ]; then
    warn "DRY RUN MODE — no data will be removed."
    printf "\n"
else
    info "Cache retention: ${CACHE_RETENTION} (recent build cache preserved)"
    printf "\n"
fi

## ---------------------------------------------------------------------------
## 1. Container prune
## ---------------------------------------------------------------------------
info "Pruning stopped containers..."
$COMPOSE_CMD exec -T docker docker container prune $SYSTEM_FLAGS 2>&1 || warn "Could not prune containers."
success "Containers pruned."

## ---------------------------------------------------------------------------
## 2. Image prune
## ---------------------------------------------------------------------------
info "Pruning unused images (dangling)..."
$COMPOSE_CMD exec -T docker docker image prune $SYSTEM_FLAGS 2>&1 || warn "Could not prune images."

if [ "$DRY_RUN" != "true" ]; then
    info "Pruning ALL unused images..."
    $COMPOSE_CMD exec -T docker docker image prune -a --filter "until=${CACHE_RETENTION}" -f 2>&1 || warn "Could not prune all images."
fi
success "Images pruned."

## ---------------------------------------------------------------------------
## 3. Builder cache prune (BuildKit)
## ---------------------------------------------------------------------------
info "Pruning build cache (retention: ${CACHE_RETENTION})..."
$COMPOSE_CMD exec -T docker docker builder prune --filter "until=${CACHE_RETENTION}" $BUILDER_FLAGS 2>&1 || warn "Could not prune builder cache."
success "Builder cache pruned."

## ---------------------------------------------------------------------------
## 4. System prune (networks, dangling volumes)
## ---------------------------------------------------------------------------
info "Pruning unused networks and volumes..."
$COMPOSE_CMD exec -T docker docker system prune $SYSTEM_FLAGS 2>&1 || warn "Could not run system prune."
success "System pruned."

## ---------------------------------------------------------------------------
## 5. Report disk usage
## ---------------------------------------------------------------------------
printf "\n${BOLD}Disk Usage${NC}\n"
$COMPOSE_CMD exec -T docker docker system df 2>&1 || true

printf "\n${BOLD}${GREEN}Garbage collection complete!${NC}\n\n"
