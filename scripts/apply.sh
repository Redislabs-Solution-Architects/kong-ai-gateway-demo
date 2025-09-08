#!/usr/bin/env bash
set -euo pipefail

# Load environment variables
. ./scripts/load-env.sh

# Export required vars for envsubst
export OPENAI_API_KEY REDIS_HOST REDIS_PORT REDIS_USERNAME REDIS_PASSWORD

# Setup decK environment (suppress output for cleaner display)
./scripts/deck-setup.sh >/dev/null

# Apply Kong configuration with variable expansion
echo "Applying kong/kong.yaml to Konnect control plane..."
envsubst < kong/kong.yaml > /tmp/kong-expanded.yaml
deck gateway apply /tmp/kong-expanded.yaml
rm -f /tmp/kong-expanded.yaml

echo "Configuration applied successfully."