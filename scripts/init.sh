#!/bin/sh
##############################################################################
# init.sh — Initialize the gitlab-runner-stack
##############################################################################
# This script:
#   1. Checks prerequisites (docker, docker compose, openssl)
#   2. Copies .env.example → .env if not present
#   3. Creates required directories
#   4. Generates TLS certificates (if not present)
#   5. Validates configuration
#   6. Prints next steps
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

info()    { printf "${CYAN}[init]${NC}    %s\n" "$*"; }
success() { printf "${GREEN}[init]${NC}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[init]${NC}    %s\n" "$*"; }
error()   { printf "${RED}[init]${NC}    %s\n" "$*" >&2; }
die()     { error "$*"; exit 1; }

## ---------------------------------------------------------------------------
## Banner
## ---------------------------------------------------------------------------
printf "\n"
printf "${BOLD}╔══════════════════════════════════════════════════╗${NC}\n"
printf "${BOLD}║     gitlab-runner-stack — Initialization       ║${NC}\n"
printf "${BOLD}╚══════════════════════════════════════════════════╝${NC}\n"
printf "\n"

## ---------------------------------------------------------------------------
## 1. Prerequisites
## ---------------------------------------------------------------------------
info "Checking prerequisites..."

command -v docker >/dev/null 2>&1 || die "docker is not installed or not in PATH."
command -v openssl >/dev/null 2>&1 || die "openssl is not installed or not in PATH."

# Docker Compose V2 (docker compose) or V1 (docker-compose)
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
    warn "Using docker-compose V1. V2 (docker compose) is recommended."
else
    die "Docker Compose is not installed. Install Docker Compose V2."
fi

success "Prerequisites satisfied ($COMPOSE_CMD)."

## ---------------------------------------------------------------------------
## 2. Environment file
## ---------------------------------------------------------------------------
info "Checking environment file..."

if [ ! -f "$PROJECT_ROOT/.env" ]; then
    cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
    success "Created .env from .env.example"
    warn "Edit .env to set your GitLab URL and Runner token before continuing."
else
    success ".env already exists."
fi

# shellcheck disable=SC1090
. "$PROJECT_ROOT/.env"

## ---------------------------------------------------------------------------
## 3. Create directories
## ---------------------------------------------------------------------------
info "Creating directories..."

for dir in \
    docker/data docker/buildkit \
    runner/config runner/cache runner/hooks \
    certs/ca certs/server certs/client \
    cache/maven cache/gradle cache/npm cache/pnpm cache/yarn \
    cache/pip cache/cargo cache/go cache/nuget cache/composer \
    cache/pub cache/ccache cache/docker cache/buildx; do
    mkdir -p "$PROJECT_ROOT/$dir"
done

success "Directories ready."

## ---------------------------------------------------------------------------
## 4a. Runner config — copy template if config.toml doesn't exist
## ---------------------------------------------------------------------------
info "Checking runner configuration..."

if [ ! -f "$PROJECT_ROOT/runner/config/config.toml" ]; then
    cp "$PROJECT_ROOT/runner/config/config.toml.template" \
       "$PROJECT_ROOT/runner/config/config.toml"
    success "Created runner/config/config.toml from template."
else
    success "runner/config/config.toml already exists."
fi

## ---------------------------------------------------------------------------
## 4. TLS Certificates
## ---------------------------------------------------------------------------
info "Checking TLS certificates..."

if [ -f "$PROJECT_ROOT/certs/ca/ca.pem" ] \
   && [ -f "$PROJECT_ROOT/certs/server/server-cert.pem" ] \
   && [ -f "$PROJECT_ROOT/certs/client/cert.pem" ]; then
    success "TLS certificates already exist."
else
    warn "TLS certificates missing — generating..."
    sh "$SCRIPT_DIR/generate-certs.sh"
    success "TLS certificates generated."
fi

## ---------------------------------------------------------------------------
## 5. Validate configuration
## ---------------------------------------------------------------------------
info "Validating configuration..."

WARNINGS=0

if [ -z "${GITLAB_URL:-}" ] || [ "${GITLAB_URL:-}" = "https://gitlab.example.com" ]; then
    warn "GITLAB_URL is not set (still default). Edit .env before deploying."
    WARNINGS=$((WARNINGS + 1))
fi

if [ -z "${RUNNER_AUTH_TOKEN:-}" ] && [ -z "${REGISTRATION_TOKEN:-}" ]; then
    warn "No runner token set. Set RUNNER_AUTH_TOKEN or REGISTRATION_TOKEN in .env."
    warn "You can still start the stack, but the runner won't accept jobs until registered."
    WARNINGS=$((WARNINGS + 1))
fi

## ---------------------------------------------------------------------------
## 6. Summary & next steps
## ---------------------------------------------------------------------------
printf "\n"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}${BOLD}  Initialization complete!${NC}\n"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "\n"

if [ "$WARNINGS" -gt 0 ]; then
    printf "${YELLOW}  ⚠  %d configuration warning(s) — see above.${NC}\n" "$WARNINGS"
    printf "${YELLOW}     Fix them in ${BOLD}.env${NC}${YELLOW}, then continue.${NC}\n"
    printf "\n"
fi

printf "  ${BOLD}Next steps:${NC}\n"
printf "\n"
printf "  1. Edit ${BOLD}.env${NC} — set GITLAB_URL and your runner token\n"
printf "\n"
printf "  2. Start the stack:\n"
printf "     ${CYAN}%s up -d${NC}\n" "$COMPOSE_CMD"
printf "\n"
printf "  3. Register the runner:\n"
printf "     ${CYAN}./scripts/register-runner.sh${NC}\n"
printf "\n"
printf "  4. Verify:\n"
printf "     ${CYAN}%s ps${NC}\n" "$COMPOSE_CMD"
printf "     ${CYAN}%s logs -f runner${NC}\n" "$COMPOSE_CMD"
printf "\n"
