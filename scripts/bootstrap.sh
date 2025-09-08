#!/usr/bin/env bash
set -euo pipefail
echo "Bootstrap script starting..."

### --- helpers --------------------------------------------------------------
log() { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
die() { printf "\033[1;31m[err]\033[0m %s\n" "$*"; exit 1; }

require_cmd() {
  local cmd="$1" install_hint="${2:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    [ -n "$install_hint" ] && warn "$cmd not found. Will try: $install_hint"
    return 1
  fi
}

require_env() {
  local var="$1"
  if [[ -z "${!var:-}" ]]; then
    die "Missing env: $var (set it in .env)"
  fi
}

wait_for() {
  local desc="$1" cmd="$2" tries="${3:-60}" sleep_s="${4:-2}"
  log "Waiting for $desc ..."
  for ((i=1;i<=tries;i++)); do
    if eval "$cmd" >/dev/null 2>&1; then
      log "$desc is ready."
      return 0
    fi
    sleep "$sleep_s"
  done
  die "Timed out waiting for $desc"
}

### --- load .env ------------------------------------------------------------
echo "Loading environment variables..."
if [[ -f ".env" ]]; then
  set -a; source .env; set +a
  echo "Environment loaded successfully"
else
  die "No .env found. Copy .env.example to .env and fill in your values."
fi

# Required envs
echo "Checking required environment variables..."
require_env DECK_KONNECT_TOKEN
echo "✓ DECK_KONNECT_TOKEN verified"
: "${DECK_KONNECT_CONTROL_PLANE_NAME}"
: "${KONNECT_CONTROL_PLANE_URL}"
: "${KONNECT_PROXY_URL}"

# OpenAI + Redis for your plugins  
require_env OPENAI_API_KEY
echo "✓ OPENAI_API_KEY verified"
require_env REDIS_HOST
echo "✓ REDIS_HOST verified"
require_env REDIS_PORT
echo "✓ REDIS_PORT verified"
require_env REDIS_USERNAME
echo "✓ REDIS_USERNAME verified" 
require_env REDIS_PASSWORD
echo "✓ REDIS_PASSWORD verified"

# decK config file
echo "Checking for kong/kong.yaml..."
[[ -f "kong/kong.yaml" ]] || die "kong/kong.yaml not found (repo incomplete)."
echo "✓ kong/kong.yaml found"

### --- install Docker (macOS) ----------------------------------------------
echo "Checking Docker installation..."
if ! require_cmd docker "brew install --cask docker"; then
  if [[ "$OSTYPE" == darwin* ]]; then
    if command -v brew >/dev/null 2>&1; then
      log "Installing Docker Desktop via Homebrew Cask ..."
      brew install --cask docker
      log "Launching Docker Desktop ..."
      open -a Docker
    else
      die "Homebrew not installed. Install Docker Desktop manually, then rerun."
    fi
  else
    die "Docker not installed. Please install Docker, then rerun."
  fi
fi
echo "✓ Docker found"

# Ensure Docker engine is running
echo "Checking Docker daemon status..."
wait_for "Docker engine" "docker info"

### --- install decK ---------------------------------------------------------
echo "Checking decK installation..."
if ! require_cmd deck "brew install kong/deck/deck"; then
  if command -v brew >/dev/null 2>&1; then
    log "Installing decK ..."
    brew install kong/deck/deck
  else
    die "decK not installed and Homebrew missing. Install decK, then rerun."
  fi
fi
echo "✓ decK found"

### --- start/ensure data plane container -----------------------------------
if ! docker ps --format '{{.Names}}' | grep -q '^kong-quickstart-gateway$'; then
  log "Starting Konnect data plane via quickstart ..."
  # This script will pull images, start the DP, create control plane, and connect them
  curl -Ls https://get.konghq.com/quickstart | bash -s -- -k "$DECK_KONNECT_TOKEN" --deck-output
else
  log "Data plane container already running (kong-quickstart-gateway). Skipping start."
fi

# Give the proxy a moment to be ready (basic health check)
sleep 5

### --- apply kong config ----------------------------------------------------
log "Applying kong/kong.yaml to Konnect ..."
bash ./scripts/apply.sh

### --- smoke test -----------------------------------------------------------
echo "Waiting for configuration to propagate..."
sleep 5
log "Smoke test: /chat (allowed topic) ..."
set +e
HTTP_CODE=$(curl -sS -o /tmp/kong_bootstrap_resp.json -w "%{http_code}" -X POST "$KONNECT_PROXY_URL/chat" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -H "x-prompt-count: 1" \
  --json '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"How do i deposit a check?"}]}')
set -e

if [[ "$HTTP_CODE" == "200" ]]; then
  log "Success! /chat returned 200. (Body saved to /tmp/kong_bootstrap_resp.json)"
else
  warn "Expected 200 but got $HTTP_CODE. Check /tmp/kong_bootstrap_resp.json for details."
fi

log "All done. Next:
- Edit kong/kong.yaml as needed, then re-apply with:  deck gateway apply kong/kong.yaml
- Try cache HIT by repeating the same prompt.
- To stop DP: curl -s https://get.konghq.com/quickstart | bash -s -- -d -a kong-quickstart
"

