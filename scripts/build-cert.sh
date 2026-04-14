#!/usr/bin/env sh
set -e
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

CERT_DIR="$BASE_DIR/app/certs"
MODE="${1:-init}"

mkdir -p "$CERT_DIR"

log() {
  echo "[cert] $1"
}

fail() {
  echo "[cert] ERROR: $1"
  exit 1
}

build_san_list() {
  SAN_VALUE=""

  if [ -n "${DNS_NAMES:-}" ]; then
    OLD_IFS="$IFS"
    IFS=','
    for name in $DNS_NAMES; do
      [ -n "$name" ] || continue
      if [ -n "$SAN_VALUE" ]; then
        SAN_VALUE="$SAN_VALUE,"
      fi
      SAN_VALUE="${SAN_VALUE}DNS:${name}"
    done
    IFS="$OLD_IFS"
  fi

  if [ -n "${IP_ADDRESSES:-}" ]; then
    OLD_IFS="$IFS"
    IFS=','
    for ip in $IP_ADDRESSES; do
      [ -n "$ip" ] || continue
      if [ -n "$SAN_VALUE" ]; then
        SAN_VALUE="$SAN_VALUE,"
      fi
      SAN_VALUE="${SAN_VALUE}IP:${ip}"
    done
    IFS="$OLD_IFS"
  fi

  [ -n "$SAN_VALUE" ] || fail "SAN list is empty. Set DNS_NAMES and/or IP_ADDRESSES."

  printf '%s' "$SAN_VALUE"
}

detect_public_ip() {
  PUBLIC_IP=""

  if command -v curl >/dev/null 2>&1; then
    # 1. Default trace endpoint (force IPv4)
    PUBLIC_IP=$(curl -4 -fsSL https://www.miaoko.net/cdn-cgi/trace 2>/dev/null | sed -n 's/^ip=\([^ ]*\).*/\1/p' || true)

    # 2. Fallback to custom v4 trace endpoint
    [ -n "$PUBLIC_IP" ] || PUBLIC_IP=$(curl -4 -fsSL https://v4.miaoko.net/miao/trace 2>/dev/null | sed -n 's/^ip=\([^ ]*\).*/\1/p' || true)

    # 3. Fallback to ipify (force IPv4)
    [ -n "$PUBLIC_IP" ] || PUBLIC_IP=$(curl -4 -fsSL https://api.ipify.org 2>/dev/null || true)

    # 4. Fallback to ifconfig.me (force IPv4)
    [ -n "$PUBLIC_IP" ] || PUBLIC_IP=$(curl -4 -fsSL https://ifconfig.me 2>/dev/null || true)
  fi

  printf '%s' "$PUBLIC_IP"
}

write_extfile() {
  EXTFILE_PATH="$1"
  EXTENDED_KEY_USAGE="$2"
  SAN_LIST="$3"

  cat > "$EXTFILE_PATH" <<EOF
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=${EXTENDED_KEY_USAGE}
subjectAltName=${SAN_LIST}
EOF
}

case "$MODE" in

  init)
    DNS_NAMES="${SERVER_DNS_NAMES:-www.bilibili.com,www.taobao.com,localhost}"
    SERVER_CN="${SERVER_CN:-server}"

    DETECTED_IP=""
    if [ -n "${SERVER_IP_ADDRESSES:-}" ]; then
      IP_ADDRESSES="$SERVER_IP_ADDRESSES"
    else
      log "No SERVER_IP_ADDRESSES provided, trying to detect public IP..."
      DETECTED_IP="$(detect_public_ip)"
      if [ -n "$DETECTED_IP" ]; then
        log "Detected public IP: $DETECTED_IP"
        IP_ADDRESSES="127.0.0.1,$DETECTED_IP"
      else
        log "WARNING: Failed to detect public IP, using loopback only"
        IP_ADDRESSES="127.0.0.1"
      fi
    fi

    SAN_LIST="$(build_san_list)"
    SERVER_EXTFILE="$CERT_DIR/server.ext"

    log "Initializing CA and SAN-enabled server certificates..."
    log "Server SAN: $SAN_LIST"

    openssl genrsa -out "$CERT_DIR/ca.key" 4096
    openssl req -x509 -new -nodes -key "$CERT_DIR/ca.key" -sha256 -days 3650 \
      -subj "/CN=ca" \
      -out "$CERT_DIR/ca.crt"

    openssl genrsa -out "$CERT_DIR/server.key" 2048
    openssl req -new -key "$CERT_DIR/server.key" \
      -subj "/CN=${SERVER_CN}" \
      -out "$CERT_DIR/server.csr"

    write_extfile "$SERVER_EXTFILE" "serverAuth" "$SAN_LIST"

    openssl x509 -req -in "$CERT_DIR/server.csr" \
      -CA "$CERT_DIR/ca.crt" \
      -CAkey "$CERT_DIR/ca.key" \
      -CAcreateserial \
      -out "$CERT_DIR/server.crt" \
      -days 3650 -sha256 \
      -extfile "$SERVER_EXTFILE"

    rm -f "$CERT_DIR/server.csr" "$CERT_DIR/ca.srl" "$SERVER_EXTFILE"

    log "Server certificates generated"
    ;;

  client)
    CLIENT_NAME="${2:-client}"
    DNS_NAMES="${CLIENT_DNS_NAMES:-$CLIENT_NAME}"
    # Client certificates normally do not need IP SAN entries.
    # Keep this empty by default unless you explicitly want to include client IPs.
    IP_ADDRESSES="${CLIENT_IP_ADDRESSES:-}"
    CLIENT_CN="${CLIENT_CN:-$CLIENT_NAME}"
    SAN_LIST="$(build_san_list)"
    CLIENT_EXTFILE="$CERT_DIR/${CLIENT_NAME}.ext"

    log "Generating SAN-enabled client certificate for: $CLIENT_NAME"
    log "Client SAN: $SAN_LIST"

    [ -f "$CERT_DIR/ca.crt" ] || fail "CA certificate not found, run init first"
    [ -f "$CERT_DIR/ca.key" ] || fail "CA private key not found, run init first"

    openssl genrsa -out "$CERT_DIR/${CLIENT_NAME}.key" 2048
    openssl req -new -key "$CERT_DIR/${CLIENT_NAME}.key" \
      -subj "/CN=${CLIENT_CN}" \
      -out "$CERT_DIR/${CLIENT_NAME}.csr"

    write_extfile "$CLIENT_EXTFILE" "clientAuth" "$SAN_LIST"

    openssl x509 -req -in "$CERT_DIR/${CLIENT_NAME}.csr" \
      -CA "$CERT_DIR/ca.crt" \
      -CAkey "$CERT_DIR/ca.key" \
      -CAcreateserial \
      -out "$CERT_DIR/${CLIENT_NAME}.crt" \
      -days 3650 -sha256 \
      -extfile "$CLIENT_EXTFILE"

    rm -f "$CERT_DIR/${CLIENT_NAME}.csr" "$CERT_DIR/ca.srl" "$CLIENT_EXTFILE"

    log "Client certificate generated: ${CLIENT_NAME}.crt"
    ;;

  *)
    echo "Usage:"
    echo "  ./scripts/build-cert.sh init"
    echo "    Generate CA + SAN-enabled server certificate"
    echo "    Optional env: SERVER_DNS_NAMES=www.bilibili.com,www.taobao.com,localhost SERVER_IP_ADDRESSES=127.0.0.1,10.0.0.1 SERVER_CN=server"
    echo ""
    echo "  ./scripts/build-cert.sh client <name>"
    echo "    Generate SAN-enabled client certificate"
    echo "    Optional env: CLIENT_DNS_NAMES=<name> CLIENT_IP_ADDRESSES=<optional-ip-list> CLIENT_CN=<name>"
    exit 1
    ;;

esac

log "Done!"
