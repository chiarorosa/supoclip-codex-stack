#!/usr/bin/env bash
# Idempotent installer for the SupoClip + Codex stack. Safe to re-run.
#
# Exit codes: 0 = stack is up, 1 = error, 2 = a human step is needed (ChatGPT login).
set -euo pipefail
cd "$(dirname "$0")"

# Upstream SupoClip commit this stack was tested with.
SUPOCLIP_REF=a1db8c39364faf5bf7fae727a08cac66312168f3

say() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"; }

say "Checking prerequisites"
need git
need docker
PY=$(command -v python3 || command -v python || true)
[ -n "$PY" ] || die "missing required tool: python3"
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is required"
docker info >/dev/null 2>&1 || die "the Docker daemon is not running"

say "Fetching SupoClip at ${SUPOCLIP_REF:0:7}"
if [ ! -d supoclip/.git ]; then
  git clone --quiet https://github.com/FujiwaraChoki/supoclip.git supoclip
fi
if [ "$(git -C supoclip rev-parse HEAD)" != "$SUPOCLIP_REF" ]; then
  git -C supoclip fetch --quiet origin
  git -C supoclip checkout --quiet "$SUPOCLIP_REF"
fi

say "Creating stack.env (kept if it already exists)"
[ -f stack.env ] || "$PY" gen_env.py

say "Building images (the first build takes several minutes)"
./dc.sh build

say "Checking the ChatGPT login stored in the Docker volume"
if ! ./dc.sh run --rm --no-deps --entrypoint codex codex-proxy login status 2>&1 | grep -q "Logged in"; then
  cat <<'EOF'

HUMAN STEP REQUIRED: sign in with your ChatGPT account (device login).
Run this in an interactive terminal, follow the URL it prints, then re-run ./setup.sh:

    ./login.sh

EOF
  exit 2
fi

say "Starting the stack"
./dc.sh up -d

say "Waiting for every container to become healthy (up to 10 minutes)"
containers="codex-proxy supoclip-postgres supoclip-redis supoclip-backend supoclip-worker supoclip-frontend"
for _ in $(seq 1 120); do
  pending=""
  for c in $containers; do
    state=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$c" 2>/dev/null || echo missing)
    [ "$state" = "healthy" ] || pending="$pending $c($state)"
  done
  [ -z "$pending" ] && break
  sleep 5
done
[ -z "$pending" ] || die "not healthy after 10 minutes:$pending (see: ./dc.sh logs <service>)"

port=$(grep -E '^FRONTEND_PORT=' stack.env | cut -d= -f2)
say "Done. Open http://localhost:${port:-3107} and create a local account, then run ./verify.sh"
