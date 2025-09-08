#!/usr/bin/env bash
set -euo pipefail
if [ -f .env ]; then
  set -a; source .env; set +a
else
  echo "Missing .env. Copy .env.example to .env and fill values." >&2
  exit 1
fi
