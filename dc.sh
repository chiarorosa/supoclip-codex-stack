#!/usr/bin/env bash
# Wrapper so the long compose command line is not repeated.
#   ./dc.sh build codex-proxy
#   ./dc.sh up -d
set -euo pipefail
cd "$(dirname "$0")"
exec docker compose \
  --project-name supoclip-stack \
  --project-directory supoclip \
  --env-file stack.env \
  -f supoclip/docker-compose.yml \
  -f compose.codex.yml \
  "$@"
