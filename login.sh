#!/usr/bin/env bash
# One-time ChatGPT device login, performed INSIDE the codex-proxy image.
# The credentials are stored only in the `codex_auth` Docker volume, never on the host.
# Needs an interactive terminal: it prints a URL and a code for you to enter in a browser.
set -euo pipefail
cd "$(dirname "$0")"
exec ./dc.sh run --rm --no-deps --entrypoint codex codex-proxy login --device-auth
