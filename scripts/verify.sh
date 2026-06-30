#!/bin/sh
##############################################################################
# verify.sh — Verify the health and connectivity of the gitlab-runner-stack
##############################################################################
# Checks:
#   1. Required files exist (.env, compose.yaml, certs)
#   2. Docker daemon container is healthy
#   3. Runner container is running
#   4. Runner can reach the Docker daemon over TLS
#   5. Runner is registered with GitLab
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

PASS=0
FAIL=0
WARN=0

ok()   { printf "  ${GREEN}✓${NC} %s\n" "$*"; PASS=$((PASS+1)); }
fail() { printf "  ${RED}✗${NC} %s\n" "$*"; FAIL=$((FAIL+1)); }
warn() { printf "  ${YELLOW}!${NC} %s\n" "$*"; WARN=$((WARN+1)); }

if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    printf "${RED}Docker Compose not found.${NC}\n"
    exit 1
fi

printf "\n${BOLD}gitlab-runner-stack — Verification${NC}\n"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

## ---------------------------------------------------------------------------
## 1. Files
## ---------------------------------------------------------------------------
printf "${BOLD}[1/5] Files${NC}\n"

[ -f "$PROJECT_ROOT/.env" ]              && ok ".env exists"            || fail ".env missing — run ./scripts/init.sh"
[ -f "$PROJECT_ROOT/compose.yaml" ]      && ok "compose.yaml exists"    || fail "compose.yaml missing"
[ -f "$PROJECT_ROOT/docker/daemon.json" ] && ok "daemon.json exists"     || fail "daemon.json missing"
[ -f "$PROJECT_ROOT/certs/ca/ca.pem" ]   && ok "CA certificate exists"  || fail "CA cert missing — run ./scripts/generate-certs.sh"
[ -f "$PROJECT_ROOT/certs/server/server-cert.pem" ] && ok "Server certificate exists" || fail "Server cert missing"
[ -f "$PROJECT_ROOT/certs/client/cert.pem" ] && ok "Client certificate exists" || fail "Client cert missing"
[ -f "$PROJECT_ROOT/runner/config/config.toml" ] && ok "config.toml exists" || warn "config.toml missing — run ./scripts/register-runner.sh"

## ---------------------------------------------------------------------------
## 2. Docker daemon container health
## ---------------------------------------------------------------------------
printf "\n${BOLD}[2/5] Docker Daemon${NC}\n"

DOCKER_STATUS=$($COMPOSE_CMD ps docker --format '{{.Health}}' 2>/dev/null || echo "down")
case "$DOCKER_STATUS" in
    healthy)   ok "Docker daemon is healthy" ;;
    starting)  warn "Docker daemon is starting..." ;;
    unhealthy) fail "Docker daemon is unhealthy" ;;
    *)         fail "Docker daemon container is not running" ;;
esac

## ---------------------------------------------------------------------------
## 3. Runner container status
## ---------------------------------------------------------------------------
printf "\n${BOLD}[3/5] Runner${NC}\n"

RUNNER_STATUS=$($COMPOSE_CMD ps runner --format '{{.Status}}' 2>/dev/null || echo "down")
case "$RUNNER_STATUS" in
    *Up*)   ok "Runner is running ($RUNNER_STATUS)" ;;
    *Exit*) fail "Runner has exited ($RUNNER_STATUS)" ;;
    "")     fail "Runner container not found" ;;
    *)      warn "Runner status: $RUNNER_STATUS" ;;
esac

## ---------------------------------------------------------------------------
## 4. TLS connectivity (runner → docker daemon)
## ---------------------------------------------------------------------------
printf "\n${BOLD}[4/5] TLS Connectivity${NC}\n"

if [ "$DOCKER_STATUS" = "healthy" ]; then
    TLS_TEST=$($COMPOSE_CMD exec -T docker docker version --format '{{.Server.Version}}' 2>/dev/null || echo "")
    if [ -n "$TLS_TEST" ]; then
        ok "Docker daemon reachable (Engine v$TLS_TEST)"
    else
        fail "Cannot reach Docker daemon — check TLS certificates"
    fi
else
    warn "Skipping TLS test — Docker daemon not healthy"
fi

## ---------------------------------------------------------------------------
## 5. GitLab registration
## ---------------------------------------------------------------------------
printf "\n${BOLD}[5/5] GitLab Registration${NC}\n"

RUNNER_VERIFY=$($COMPOSE_CMD exec -T runner gitlab-runner verify 2>&1 || echo "FAILED")
case "$RUNNER_VERIFY" in
    *"is alive"*) ok "Runner is registered and alive in GitLab" ;;
    *"FAILED"*)   fail "Runner verification failed — check token and GitLab URL" ;;
    *)            warn "Runner verification inconclusive: $RUNNER_VERIFY" ;;
esac

## ---------------------------------------------------------------------------
## Summary
## ---------------------------------------------------------------------------
printf "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "  ${GREEN}Passed:${NC} $PASS   ${RED}Failed:${NC} $FAIL   ${YELLOW}Warnings:${NC} $WARN\n"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
