#!/bin/sh
##############################################################################
# restore.sh — Restore from a backup archive
##############################################################################
# Usage:
#   ./scripts/restore.sh <backup-file.tar.gz>
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

info()    { printf "${CYAN}[restore]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[restore]${NC} %s\n" "$*"; }
warn()    { printf "${YELLOW}[restore]${NC} %s\n" "$*"; }
die()     { printf "${RED}[restore]${NC} ERROR: %s\n" "$*" >&2; exit 1; }

BACKUP_FILE="${1:-}"

if [ -z "$BACKUP_FILE" ]; then
    die "No backup file specified.\nUsage: $0 <backup-file.tar.gz>"
fi

# Resolve relative paths
if [ ! -f "$BACKUP_FILE" ]; then
    BACKUP_FILE="$PROJECT_ROOT/$BACKUP_FILE"
fi

[ -f "$BACKUP_FILE" ] || die "Backup file not found: $1"

printf "${YELLOW}${BOLD}WARNING: This will overwrite existing configuration and data.${NC}\n"
printf "${YELLOW}Backup file: ${BOLD}%s${NC}\n\n" "$BACKUP_FILE"

printf "Continue? [y/N] "
read -r CONFIRM
case "$CONFIRM" in
    y|Y|yes|YES) ;;
    *) die "Restore cancelled." ;;
esac

## ---------------------------------------------------------------------------
## Stop services before restoring
## ---------------------------------------------------------------------------
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    warn "Docker Compose not found — skipping service stop."
    COMPOSE_CMD=""
fi

if [ -n "$COMPOSE_CMD" ]; then
    info "Stopping services..."
    $COMPOSE_CMD down >/dev/null 2>&1 || true
    success "Services stopped."
fi

## ---------------------------------------------------------------------------
## Restore
## ---------------------------------------------------------------------------
info "Extracting backup..."

# List contents first so the user can see what's being restored
printf "${CYAN}Archive contents:${NC}\n"
tar tzf "$BACKUP_FILE" | head -20
printf "\n"

tar xzf "$BACKUP_FILE" -C "$PROJECT_ROOT"
success "Files restored."

## ---------------------------------------------------------------------------
## Restart
## ---------------------------------------------------------------------------
if [ -n "$COMPOSE_CMD" ]; then
    info "Starting services..."
    $COMPOSE_CMD up -d
    success "Services started."
fi

printf "\n${BOLD}${GREEN}Restore complete!${NC}\n"
printf "  Verify: ${CYAN}./scripts/verify.sh${NC}\n\n"
