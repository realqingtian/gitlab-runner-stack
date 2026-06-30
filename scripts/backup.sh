#!/bin/sh
##############################################################################
# backup.sh — Back up all persistent data
##############################################################################
# Packages these directories into a timestamped tar.gz:
#   runner/config/   certs/   docker/daemon.json
#
# By default does NOT include docker/data/ (large) or cache/ (regenerable).
# Use --full to include everything.
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

info()    { printf "${CYAN}[backup]${NC}  %s\n" "$*"; }
success() { printf "${GREEN}[backup]${NC}  %s\n" "$*"; }
warn()    { printf "${YELLOW}[backup]${NC}  %s\n" "$*"; }
die()     { printf "${RED}[backup]${NC}  ERROR: %s\n" "$*" >&2; exit 1; }

FULL=0
BACKUP_DIR="$PROJECT_ROOT/backups"

for arg in "$@"; do
    case "$arg" in
        --full)   FULL=1 ;;
        --help|-h)
            echo "Usage: $0 [--full]"
            echo "  --full  Include docker/data/ and cache/ (large, slower)"
            exit 0
            ;;
    esac
done

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/gitlab-runner-stack_${TIMESTAMP}.tar.gz"

info "Creating backup..."

ESSENTIAL_ITEMS="runner/config certs docker/daemon.json compose.yaml .env"

if [ "$FULL" -eq 1 ]; then
    warn "Full backup: including docker/data/ and cache/ (this may take a while)..."
    ITEMS="$ESSENTIAL_ITEMS docker/data cache"
else
    ITEMS="$ESSENTIAL_ITEMS"
fi

# Build tar command — only include paths that exist
TAR_ARGS=""
for item in $ITEMS; do
    if [ -e "$item" ]; then
        TAR_ARGS="$TAR_ARGS $item"
    fi
done

if [ -z "$TAR_ARGS" ]; then
    die "Nothing to back up."
fi

# shellcheck disable=SC2086
tar czf "$BACKUP_FILE" $TAR_ARGS

FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

success "Backup created: $BACKUP_FILE ($FILE_SIZE)"

# Show backup history
BACKUP_COUNT=$(find "$BACKUP_DIR" -name '*.tar.gz' | wc -l | tr -d ' ')
info "Total backups: $BACKUP_COUNT"

# Retention: keep last 10 backups
if [ "$BACKUP_COUNT" -gt 10 ]; then
    info "Applying retention policy (keep last 10)..."
    ls -t "$BACKUP_DIR"/gitlab-runner-stack_*.tar.gz | tail -n +11 | while read -r old; do
        rm -f "$old"
        warn "Removed old backup: $(basename "$old")"
    done
fi

printf "\n${BOLD}Backup complete!${NC}\n"
printf "  File: ${CYAN}$BACKUP_FILE${NC}\n"
printf "  Size: ${CYAN}$FILE_SIZE${NC}\n"
printf "\n  Restore with: ${CYAN}./scripts/restore.sh $BACKUP_FILE${NC}\n\n"
