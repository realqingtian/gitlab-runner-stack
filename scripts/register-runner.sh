#!/bin/sh
##############################################################################
# register-runner.sh — Register or re-register the GitLab Runner
##############################################################################
# This script renders config.toml from the template using values in .env,
# then restarts the runner container.
#
# Supports two flows:
#   • GitLab 16.0+ (new):  Set RUNNER_AUTH_TOKEN in .env
#   • GitLab < 16.0 (old): Set REGISTRATION_TOKEN in .env
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

info()    { printf "${CYAN}[register]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[register]${NC} %s\n" "$*"; }
warn()    { printf "${YELLOW}[register]${NC} %s\n" "$*"; }
error()   { printf "${RED}[register]${NC} %s\n" "$*" >&2; }
die()     { error "$*"; exit 1; }

## ---------------------------------------------------------------------------
## Load environment
## ---------------------------------------------------------------------------
[ -f "$PROJECT_ROOT/.env" ] || die ".env not found. Run ./scripts/init.sh first."
# shellcheck disable=SC1090
. "$PROJECT_ROOT/.env"

## ---------------------------------------------------------------------------
## Validate required variables
## ---------------------------------------------------------------------------
[ -n "${GITLAB_URL:-}" ] || die "GITLAB_URL is not set in .env."
[ "${GITLAB_URL}" != "https://gitlab.example.com" ] || die "GITLAB_URL is still the default placeholder. Set your real GitLab URL."

## Determine token
USE_LEGACY=0
if [ -n "${RUNNER_AUTH_TOKEN:-}" ]; then
    RUNNER_TOKEN="$RUNNER_AUTH_TOKEN"
    info "Using new authentication token (GitLab 16.0+)."
elif [ -n "${REGISTRATION_TOKEN:-}" ]; then
    RUNNER_TOKEN="$REGISTRATION_TOKEN"
    USE_LEGACY=1
    info "Using legacy registration token (GitLab < 16.0)."
else
    die "No token set. Set RUNNER_AUTH_TOKEN or REGISTRATION_TOKEN in .env."
fi

## ---------------------------------------------------------------------------
## Determine compose command
## ---------------------------------------------------------------------------
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    die "Docker Compose is not installed."
fi

## ---------------------------------------------------------------------------
## Render config.toml from template
## ---------------------------------------------------------------------------
TEMPLATE="$PROJECT_ROOT/runner/config/config.toml.template"
CONFIG="$PROJECT_ROOT/runner/config/config.toml"

[ -f "$TEMPLATE" ] || die "config.toml template not found at $TEMPLATE"

info "Rendering config.toml..."

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

if [ "$USE_LEGACY" -eq 0 ]; then
    #------------------------------------------------------------------------
    # New auth flow (GitLab 16.0+) — token goes directly in config.toml
    #------------------------------------------------------------------------
    sed \
        -e "s|__GITLAB_URL__|${GITLAB_URL}|g" \
        -e "s|__RUNNER_TOKEN__|${RUNNER_TOKEN}|g" \
        -e "s|__RUNNER_NAME__|${RUNNER_NAME:-gitlab-runner}|g" \
        "$TEMPLATE" > "$TMPFILE"

    cp "$TMPFILE" "$CONFIG"
    success "config.toml rendered with auth token."

    # Apply dynamic settings from .env
    info "Applying runner settings..."
    _apply_setting() {
        _pattern="$1"; _replacement="$2"
        sed -i.bak "${_pattern}" "$CONFIG" 2>/dev/null \
            || sed -i '' "${_pattern}" "$CONFIG"
        rm -f "${CONFIG}.bak"
    }
    [ -n "${RUNNER_CONCURRENT:-}" ]    && _apply_setting "s/^concurrent = .*/concurrent = ${RUNNER_CONCURRENT}/"
    [ -n "${RUNNER_DEFAULT_IMAGE:-}" ] && _apply_setting "s|image = .*|image = \"${RUNNER_DEFAULT_IMAGE}\"|"
    [ -n "${RUNNER_PRIVILEGED:-}" ]    && _apply_setting "s/privileged = .*/privileged = ${RUNNER_PRIVILEGED}/"
    [ -n "${RUNNER_LIMIT:-}" ]         && _apply_setting "s/limit = .*/limit = ${RUNNER_LIMIT}/"
    success "Settings applied."

else
    #------------------------------------------------------------------------
    # Legacy flow — write global-only config, let register add the runner
    #------------------------------------------------------------------------
    awk '/^\[\[runners\]\]/{exit} {print}' "$TEMPLATE" > "$TMPFILE"
    cp "$TMPFILE" "$CONFIG"
    success "Global config written (runner section will be added by register)."
fi

## ---------------------------------------------------------------------------
## Legacy flow: register via gitlab-runner register command
## ---------------------------------------------------------------------------
if [ "$USE_LEGACY" -eq 1 ]; then
    info "Registering via legacy command..."

    # Pass all docker executor settings as CLI flags
    $COMPOSE_CMD exec -T runner gitlab-runner register \
        --non-interactive \
        --url "$GITLAB_URL" \
        --token "$REGISTRATION_TOKEN" \
        --name "${RUNNER_NAME:-gitlab-runner}" \
        --tag-list "${RUNNER_TAGS:-}" \
        --executor docker \
        --docker-image "${RUNNER_DEFAULT_IMAGE:-alpine:latest}" \
        --docker-host "tcp://docker:2376" \
        --docker-tlsverify true \
        --docker-cert-path "/certs/client" \
        --docker-privileged \
        --docker-pull-policy "if-not-present" \
        --docker-volumes /cache \
        --docker-volumes /certs/client:/certs/client:ro \
        --docker-environment DOCKER_HOST=tcp://docker:2376 \
        --docker-environment DOCKER_TLS_VERIFY=1 \
        --docker-environment DOCKER_CERT_PATH=/certs/client \
        2>&1 && \
        success "Legacy registration completed." || \
        warn "Legacy registration may need manual intervention. Check runner logs."

    # Apply concurrent setting after registration
    if [ -n "${RUNNER_CONCURRENT:-}" ]; then
        sed -i.bak "s/^concurrent = .*/concurrent = ${RUNNER_CONCURRENT}/" "$CONFIG" 2>/dev/null \
            || sed -i '' "s/^concurrent = .*/concurrent = ${RUNNER_CONCURRENT}/" "$CONFIG"
        rm -f "${CONFIG}.bak"
    fi
fi

## ---------------------------------------------------------------------------
## Restart runner to pick up new config
## ---------------------------------------------------------------------------
info "Restarting runner..."

$COMPOSE_CMD restart runner >/dev/null 2>&1 && \
    success "Runner restarted." || \
    warn "Could not restart runner. Is the stack running? Start it with: $COMPOSE_CMD up -d"

## ---------------------------------------------------------------------------
## Summary
## ---------------------------------------------------------------------------
printf "\n"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}${BOLD}  Runner registered!${NC}\n"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "\n"
printf "  GitLab URL : ${CYAN}${GITLAB_URL}${NC}\n"
printf "  Runner name: ${CYAN}${RUNNER_NAME:-gitlab-runner}${NC}\n"
printf "  Tags       : ${CYAN}${RUNNER_TAGS:-none}${NC}\n"
printf "  Concurrent : ${CYAN}${RUNNER_CONCURRENT:-4}${NC}\n"
printf "\n"
printf "  Verify the runner is online:\n"
printf "     ${CYAN}%s logs -f runner${NC}\n" "$COMPOSE_CMD"
printf "\n"
printf "  Check in GitLab → Settings → CI/CD → Runners\n"
printf "\n"
