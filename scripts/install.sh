#!/usr/bin/env sh
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

REPO_URL="${REPO_URL:-https://github.com/moshaoli688/frps-template.git}"
PROJECT_DIR="${PROJECT_DIR:-frps-gateway}"
ENABLE_TLS="${ENABLE_TLS:-true}"
FORCE_REINIT_ENV="${FORCE_REINIT_ENV:-false}"

log() {
  echo "[install] $1"
}

warn() {
  echo "[install] WARNING: $1"
}

fail() {
  echo "[install] ERROR: $1"
  exit 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_compose() {
  if has_cmd docker && docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif has_cmd docker-compose; then
    docker-compose "$@"
  else
    fail "docker compose or docker-compose is required"
  fi
}

rand_hex() {
  length="$1"
  if has_cmd openssl; then
    openssl rand -hex "$length"
  elif has_cmd python3; then
    python3 - <<PY
import secrets
print(secrets.token_hex($length))
PY
  else
    date +%s | md5 | cut -c1-$((length * 2))
  fi
}

check_required() {
  has_cmd git || fail "git is required"
  has_cmd docker || fail "docker is required"
  run_compose version >/dev/null 2>&1 || fail "docker compose is required"
}

ensure_repo() {
  if [ -d "$PROJECT_DIR/.git" ]; then
    log "Project exists, updating repository..."
    cd "$PROJECT_DIR"
    git pull --ff-only || warn "git pull failed, keeping existing files"
  elif [ -d "$PROJECT_DIR" ]; then
    fail "Directory '$PROJECT_DIR' already exists but is not a git repository"
  else
    log "Cloning repository..."
    git clone "$REPO_URL" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
  fi
}

init_env() {
  [ -f ".env.example" ] || fail ".env.example not found"

  if [ -f ".env" ] && [ "$FORCE_REINIT_ENV" != "true" ]; then
    log ".env already exists, keeping existing configuration"
    return
  fi

  log "Initializing .env..."

  # Interactive inputs (optional)
  HOST_NAME="$(hostname 2>/dev/null || echo node)"
  SAFE_HOST_NAME="$(printf '%s' "$HOST_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9.-')"
  printf "Container name [frps-%s]: " "$SAFE_HOST_NAME"
  read INPUT_CONTAINER

  printf "FRP token [auto]: "
  read INPUT_TOKEN

  printf "Dashboard password [auto]: "
  read INPUT_PASS

  cp .env.example .env

  DEFAULT_TOKEN="$(rand_hex 16)"
  DEFAULT_PASS="$(rand_hex 8)"

  TOKEN="${INPUT_TOKEN:-$DEFAULT_TOKEN}"
  DASHBOARD_PASS="${INPUT_PASS:-$DEFAULT_PASS}"

  if has_cmd sed; then
    sed -i.bak "s|REPLACE_WITH_RANDOM_TOKEN|$TOKEN|g" .env
    sed -i.bak "s|REPLACE_WITH_PASSWORD|$DASHBOARD_PASS|g" .env
    FINAL_CONTAINER="${INPUT_CONTAINER:-frps-${SAFE_HOST_NAME}}"
    sed -i.bak "s|^CONTAINER_NAME=.*|CONTAINER_NAME=${FINAL_CONTAINER}|g" .env
    rm -f .env.bak
  else
    fail "sed is required"
  fi

  log ".env initialized"
}

ensure_scripts_executable() {
  [ -f "scripts/build.sh" ] || fail "scripts/build.sh not found"
  [ -f "scripts/build-cert.sh" ] || fail "scripts/build-cert.sh not found"
  [ -f "scripts/init-env.sh" ] && chmod +x scripts/init-env.sh || true
  chmod +x scripts/build.sh scripts/build-cert.sh
  [ -f "app/entrypoint.sh" ] && chmod +x app/entrypoint.sh || true
}

setup_tls() {
  if [ "$ENABLE_TLS" != "true" ]; then
    log "TLS disabled, skipping certificate generation"
    return
  fi

  log "TLS enabled, checking certificates..."

  # Optional manual IP input
  printf "Enter server public IP for TLS SAN (leave empty to auto-detect): "
  read TLS_IP_INPUT

  if [ -f "app/certs/server.crt" ] && [ -f "app/certs/server.key" ] && [ -f "app/certs/ca.crt" ]; then
    log "TLS certificates already exist, skipping generation"
  else
    log "Generating TLS certificates..."
    if [ -n "$TLS_IP_INPUT" ]; then
      SERVER_IP_ADDRESSES="$TLS_IP_INPUT" ./scripts/build-cert.sh init
    else
      ./scripts/build-cert.sh init
    fi
  fi

  if has_cmd sed; then
    sed -i.bak "s|^FRP_TLS_ENABLE=.*|FRP_TLS_ENABLE=true|g" .env
    rm -f .env.bak
  fi
}

show_summary() {
  log "Installation summary:"
  echo "----------------------------------------"
  grep -E '^(CONTAINER_NAME|FRPS_IMAGE|FRP_BIND_PORT|FRP_QUIC_PORT|FRP_DASHBOARD_PORT|FRP_TLS_ENABLE)=' .env || true
  echo "----------------------------------------"
}

build_image() {
  log "Building image..."
  ./scripts/build.sh
}

start_service() {
  log "Starting service..."
  run_compose up -d
}

show_next_steps() {
  echo ""
  echo "✅ frps deployment completed"
  echo ""
  echo "Useful commands:"
  echo "  View logs:    docker compose logs -f"
  echo "  Stop service: docker compose down"
  echo "  Restart:      docker compose restart"
  echo "  Rebuild:      ./scripts/build.sh"
  echo ""
}

main() {
  log "Starting one-click installer..."
  check_required
  ensure_repo
  ensure_scripts_executable
  init_env
  setup_tls
  show_summary
  build_image
  start_service
  show_next_steps
}

main "$@"
