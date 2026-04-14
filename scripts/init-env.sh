#!/usr/bin/env sh
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

ENV_FILE=".env"
EXAMPLE_FILE=".env.example"

log() {
  echo "[init] $1"
}

fail() {
  echo "[init] ERROR: $1"
  exit 1
}

rand_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$1"
  else
    date +%s | sha256sum | cut -c1-"$1"
  fi
}

prompt() {
  VAR_NAME="$1"
  PROMPT_TEXT="$2"
  DEFAULT_VALUE="$3"

  printf "%s [%s]: " "$PROMPT_TEXT" "$DEFAULT_VALUE"
  read INPUT

  if [ -z "$INPUT" ]; then
    eval "$VAR_NAME=\"$DEFAULT_VALUE\""
  else
    eval "$VAR_NAME=\"$INPUT\""
  fi
}

prompt_yes_no() {
  VAR_NAME="$1"
  PROMPT_TEXT="$2"
  DEFAULT_VALUE="$3"

  printf "%s [%s]: " "$PROMPT_TEXT" "$DEFAULT_VALUE"
  read INPUT

  [ -z "$INPUT" ] && INPUT="$DEFAULT_VALUE"

  case "$INPUT" in
    y|Y|yes|YES|true|TRUE) eval "$VAR_NAME=true" ;;
    n|N|no|NO|false|FALSE) eval "$VAR_NAME=false" ;;
    *) fail "Invalid input: $INPUT" ;;
  esac
}

log "Initializing environment..."

[ -f "$EXAMPLE_FILE" ] || fail ".env.example not found"

if [ -f "$ENV_FILE" ]; then
  log ".env already exists, skip"
  exit 0
fi

HOST_NAME="$(hostname 2>/dev/null || echo node)"
DEFAULT_CONTAINER="frps-${HOST_NAME}"
DEFAULT_TOKEN="$(rand_hex 16)"
DEFAULT_PASS="$(rand_hex 8)"

prompt CONTAINER_NAME "Container name" "$DEFAULT_CONTAINER"
prompt FRP_BIND_PORT "FRP bind port" "8000"
prompt FRP_QUIC_PORT "FRP QUIC port" "4000"
prompt FRP_DASHBOARD_PORT "Dashboard port" "8088"
prompt FRP_DASHBOARD_USER "Dashboard user" "admin"
prompt FRP_TOKEN "FRP token" "$DEFAULT_TOKEN"
prompt FRP_DASHBOARD_PASS "Dashboard password" "$DEFAULT_PASS"
prompt_yes_no USE_TLS "Enable TLS? (y/n)" "y"

cp "$EXAMPLE_FILE" "$ENV_FILE"

sed -i.bak "s|CONTAINER_NAME=.*|CONTAINER_NAME=${CONTAINER_NAME}|g" "$ENV_FILE"
sed -i.bak "s|FRP_BIND_PORT=.*|FRP_BIND_PORT=${FRP_BIND_PORT}|g" "$ENV_FILE"
sed -i.bak "s|FRP_QUIC_PORT=.*|FRP_QUIC_PORT=${FRP_QUIC_PORT}|g" "$ENV_FILE"
sed -i.bak "s|FRP_DASHBOARD_PORT=.*|FRP_DASHBOARD_PORT=${FRP_DASHBOARD_PORT}|g" "$ENV_FILE"
sed -i.bak "s|FRP_DASHBOARD_USER=.*|FRP_DASHBOARD_USER=${FRP_DASHBOARD_USER}|g" "$ENV_FILE"
sed -i.bak "s|REPLACE_WITH_RANDOM_TOKEN|${FRP_TOKEN}|g" "$ENV_FILE"
sed -i.bak "s|REPLACE_WITH_PASSWORD|${FRP_DASHBOARD_PASS}|g" "$ENV_FILE"

if [ "$USE_TLS" = "true" ]; then
  sed -i.bak "s|FRP_TLS_ENABLE=.*|FRP_TLS_ENABLE=true|g" "$ENV_FILE"
else
  sed -i.bak "s|FRP_TLS_ENABLE=.*|FRP_TLS_ENABLE=false|g" "$ENV_FILE"
fi

rm -f .env.bak

log "Done!"
echo ""
echo "========== Configuration =========="
echo "Container Name : $CONTAINER_NAME"
echo "Bind Port      : $FRP_BIND_PORT"
echo "QUIC Port      : $FRP_QUIC_PORT"
echo "Dashboard User : $FRP_DASHBOARD_USER"
echo "Dashboard Pass : $FRP_DASHBOARD_PASS"
echo "TLS Enabled    : $USE_TLS"
echo "=================================="
echo ""
echo "👉 Please review and update .env if needed"
echo "👉 Then run: ./scripts/build.sh && docker compose up -d"
