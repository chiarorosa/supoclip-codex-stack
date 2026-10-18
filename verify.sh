#!/usr/bin/env bash
# End-to-end check of the running stack. Prints PASS/FAIL per check and exits non-zero on any FAIL.
# The last check makes a few real LLM calls, which count toward your ChatGPT plan usage.
set -uo pipefail
cd "$(dirname "$0")"

fail=0
check() { # check <name> <command...>
  local name=$1; shift
  if "$@" >/dev/null 2>&1; then echo "PASS  $name"; else echo "FAIL  $name"; fail=1; fi
}

all_healthy() {
  local c
  for c in codex-proxy supoclip-postgres supoclip-redis supoclip-backend supoclip-worker supoclip-frontend; do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$c" 2>/dev/null)" = "healthy" ] || return 1
  done
}
frontend_up() {
  local port
  port=$(grep -E '^FRONTEND_PORT=' stack.env | cut -d= -f2)
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${port:-3107}/")" = "200" ]
}
codex_logged_in() { ./dc.sh exec -T codex-proxy codex login status 2>&1 | grep -q "Logged in"; }
llm_pipeline() { ./dc.sh exec -T backend .venv/bin/python - < probe.py 2>&1 | grep -q "^PASS  real pipeline"; }

check "all containers healthy" all_healthy
check "frontend answers HTTP 200" frontend_up
check "ChatGPT login present in the volume" codex_logged_in
check "SupoClip LLM pipeline through the gateway" llm_pipeline

[ "$fail" -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED (see: ./dc.sh logs <service>)"
exit "$fail"
