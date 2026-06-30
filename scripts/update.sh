##############################################################################
# update.sh — Update the gitlab-runner-stack to latest images
##############################################################################
# Pulls latest images, recreates containers with zero downtime:
#   1. Pull latest Docker Engine (dind) image
#   2. Pull latest GitLab Runner image
#   3. Recreate containers (preserves config, cache, certs, data)
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

info()    { printf "${CYAN}[update]${NC}  %s\n" "$*"; }
success() { printf "${GREEN}[update]${NC}  %s\n" "$*"; }
warn()    { printf "${YELLOW}[update]${NC}  %s\n" "$*"; }
die()     { printf "${RED}[update]${NC}  ERROR: %s\n" "$*" >&2; exit 1; }

# shellcheck disable=SC1090
[ -f "$PROJECT_ROOT/.env" ] && . "$PROJECT_ROOT/.env" 2>/dev/null || true

if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    die "Docker Compose not found."
fi

printf "\n${BOLD}gitlab-runner-stack — Update${NC}\n"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

info "Current versions:"
DOCKER_IMG="${DOCKER_DIND_IMAGE:-docker:29-dind}"
RUNNER_IMG="${GITLAB_RUNNER_IMAGE:-gitlab/gitlab-runner:latest}"
printf "  Docker Engine: ${CYAN}%s${NC}\n" "$DOCKER_IMG"
printf "  GitLab Runner: ${CYAN}%s${NC}\n\n" "$RUNNER_IMG"

## ---------------------------------------------------------------------------
## 1. Pull latest images
## ---------------------------------------------------------------------------
info "Pulling latest images..."

printf "  Pulling %s...\n" "$DOCKER_IMG"
docker pull "$DOCKER_IMG" 2>&1 | sed 's/^/    /' || warn "Could not pull $DOCKER_IMG"

printf "  Pulling %s...\n" "$RUNNER_IMG"
docker pull "$RUNNER_IMG" 2>&1 | sed 's/^/    /' || warn "Could not pull $RUNNER_IMG"

success "Images pulled."

## ---------------------------------------------------------------------------
## 2. Recreate containers (preserves volumes/config)
## ---------------------------------------------------------------------------
info "Recreating containers..."

$COMPOSE_CMD up -d --no-deps docker
success "Docker daemon recreated."

# Wait for docker daemon to be healthy before updating runner
info "Waiting for Docker daemon to be healthy..."
attempts=0
max_attempts=30
while [ "$attempts" -lt "$max_attempts" ]; do
    HEALTH=$($COMPOSE_CMD ps docker --format '{{.Health}}' 2>/dev/null || echo "")
    if [ "$HEALTH" = "healthy" ]; then
        success "Docker daemon is healthy."
        break
    fi
    attempts=$((attempts + 1))
    sleep 2
done

if [ "$attempts" -ge "$max_attempts" ]; then
    warn "Docker daemon did not become healthy in time. Continuing anyway."
fi

$COMPOSE_CMD up -d --no-deps runner
success "Runner recreated."

## ---------------------------------------------------------------------------
## 3. Clean up old images
## ---------------------------------------------------------------------------
info "Removing dangling images..."
dangling=$(docker images --filter "dangling=true" -q 2>/dev/null | head -5)
if [ -n "$dangling" ]; then
    docker rmi $dangling 2>/dev/null || true
    success "Dangling images removed."
else
    success "No dangling images."
fi

## ---------------------------------------------------------------------------
## 4. Report new versions
## ---------------------------------------------------------------------------
printf "\n${BOLD}Updated versions:${NC}\n"
DOCKER_VERSION=$($COMPOSE_CMD exec -T docker docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
RUNNER_VERSION=$($COMPOSE_CMD exec -T runner gitlab-runner --version 2>/dev/null | head -1 || echo "unknown")
printf "  Docker Engine: ${CYAN}%s${NC}\n" "$DOCKER_VERSION"
printf "  GitLab Runner: ${CYAN}%s${NC}\n" "$RUNNER_VERSION"

printf "\n${BOLD}${GREEN}Update complete!${NC}\n"
printf "  Config, certificates, caches, and data have been preserved.\n"
printf "  Verify: ${CYAN}./scripts/verify.sh${NC}\n\n"
