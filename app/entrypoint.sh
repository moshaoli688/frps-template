#!/bin/sh
set -e

CONFIG_TEMPLATE="/app/config/frps.toml.tpl"
CONFIG_OUTPUT="/tmp/frps.toml"

# ========================
# Utils
# ========================
log() {
  echo "[frps $1] $2"
}

fail() {
  echo "[frps] ERROR: $1"
  exit 1
}

# ========================
# Defaults
# ========================
: ${FRP_MAX_PORTS_PER_CLIENT:=3}
: ${FRP_LOG_LEVEL:=info}

# ========================
# Init
# ========================
echo "========== [frps init] =========="

log "init" "Generating config..."

# Prefer envsubst when available
if command -v envsubst >/dev/null 2>&1; then
  log "init" "Using envsubst"
  envsubst < "$CONFIG_TEMPLATE" > "$CONFIG_OUTPUT"
else
  log "init" "envsubst not found, using sed fallback"

  sed \
    -e "s|\${FRP_BIND_PORT}|$FRP_BIND_PORT|g" \
    -e "s|\${FRP_QUIC_PORT}|$FRP_QUIC_PORT|g" \
    -e "s|\${FRP_DASHBOARD_PORT}|$FRP_DASHBOARD_PORT|g" \
    -e "s|\${FRP_DASHBOARD_USER}|$FRP_DASHBOARD_USER|g" \
    -e "s|\${FRP_DASHBOARD_PASS}|$FRP_DASHBOARD_PASS|g" \
    -e "s|\${FRP_TOKEN}|$FRP_TOKEN|g" \
    -e "s|\${FRP_PORT_START}|$FRP_PORT_START|g" \
    -e "s|\${FRP_PORT_END}|$FRP_PORT_END|g" \
    -e "s|\${FRP_MAX_PORTS_PER_CLIENT}|$FRP_MAX_PORTS_PER_CLIENT|g" \
    -e "s|\${FRP_LOG_LEVEL}|$FRP_LOG_LEVEL|g" \
    "$CONFIG_TEMPLATE" > "$CONFIG_OUTPUT"
fi

log "init" "Validating config..."

# Required variable checks
[ -n "$FRP_BIND_PORT" ] || fail "FRP_BIND_PORT is empty"
[ -n "$FRP_TOKEN" ] || fail "FRP_TOKEN is empty"
[ -n "$FRP_PORT_START" ] || fail "FRP_PORT_START is empty"
[ -n "$FRP_PORT_END" ] || fail "FRP_PORT_END is empty"

# TLS configuration checks
if [ "${FRP_TLS_ENABLE:-false}" = "true" ]; then
  [ -n "$FRP_TLS_CERT" ] || fail "FRP_TLS_CERT is empty"
  [ -n "$FRP_TLS_KEY" ] || fail "FRP_TLS_KEY is empty"
  [ -n "$FRP_TLS_CA" ] || fail "FRP_TLS_CA is empty"

  [ -f "$FRP_TLS_CERT" ] || fail "FRP_TLS_CERT file not found"
  [ -f "$FRP_TLS_KEY" ] || fail "FRP_TLS_KEY file not found"
  [ -f "$FRP_TLS_CA" ] || fail "FRP_TLS_CA file not found"
fi

# Enable TLS settings in rendered config only after validation passes
if [ "${FRP_TLS_ENABLE:-false}" = "true" ]; then
  log "init" "TLS enabled, applying TLS settings"
  sed -i 's/^# \(transport\.tls\)/\1/g' "$CONFIG_OUTPUT"
fi

# Check for unresolved template variables
if grep -q '\${' "$CONFIG_OUTPUT"; then
  fail "Unresolved variables in config"
fi

log "init" "Config OK"

# Print rendered config only in DEBUG mode
if [ "$DEBUG" = "true" ]; then
  echo "---------- [frps config] ----------"
  cat "$CONFIG_OUTPUT"
  echo "-----------------------------------"
fi

# ========================
# Start
# ========================
echo ""
echo "========== [frps start] =========="

log "start" "Starting frps..."


if [ -x /usr/local/bin/frps ]; then
  exec /usr/local/bin/frps -c "$CONFIG_OUTPUT"
elif [ -x /usr/bin/frps ]; then
  exec /usr/bin/frps -c "$CONFIG_OUTPUT"
else
  echo "frps not found"
  exit 1
fi
