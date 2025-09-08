#!/usr/bin/env bash
set -euo pipefail
. ./scripts/load-env.sh
export DECK_KONNECT_TOKEN="$DECK_KONNECT_TOKEN"
export DECK_KONNECT_CONTROL_PLANE_NAME="${DECK_KONNECT_CONTROL_PLANE_NAME:-quickstart}"
export KONNECT_CONTROL_PLANE_URL="${KONNECT_CONTROL_PLANE_URL:-https://us.api.konghq.com}"
deck gateway ping
