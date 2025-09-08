#!/usr/bin/env bash
set -euo pipefail
. ./scripts/load-env.sh
./scripts/deck-setup.sh >/dev/null
deck gateway dump > kong/live.yaml
echo "Live config saved to kong/live.yaml"
