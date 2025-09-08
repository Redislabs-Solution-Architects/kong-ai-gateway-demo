#!/usr/bin/env bash
set -euo pipefail
. ./scripts/load-env.sh
curl -Ls https://get.konghq.com/quickstart | bash -s -- -k "$DECK_KONNECT_TOKEN" --deck-output
: "${KONNECT_PROXY_URL:=http://localhost:8000}"
echo "Data plane ready at $KONNECT_PROXY_URL"
