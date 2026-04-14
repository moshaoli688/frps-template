#!/usr/bin/env sh
set -eu

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

DEFAULT_FRP_VERSION="${DEFAULT_FRP_VERSION:-0.68.1}"
IMAGE_NAME="${IMAGE_NAME:-frps-gateway}"
PLATFORM="${PLATFORM:-}"
USE_LATEST="${USE_LATEST:-true}"

USE_CN_MIRROR="${USE_CN_MIRROR:-false}"
APK_MIRROR="${APK_MIRROR:-mirrors.ustc.edu.cn}"

HTTP_PROXY="${HTTP_PROXY:-}"
HTTPS_PROXY="${HTTPS_PROXY:-}"

FRP_VERSION="$DEFAULT_FRP_VERSION"

chmod +x "$BASE_DIR/app/entrypoint.sh" 2>/dev/null || true

if [ "$USE_LATEST" = "true" ]; then
  echo "[build] Trying to fetch latest FRP release version..."
  LATEST_VERSION=$(
    wget -qO- https://api.github.com/repos/fatedier/frp/releases/latest 2>/dev/null \
      | grep -m1 '"tag_name":' \
      | sed -E 's/.*"v([^"]+)".*/\1/' \
      || true
  )

  if [ -n "${LATEST_VERSION:-}" ]; then
    FRP_VERSION="$LATEST_VERSION"
    echo "[build] Latest version detected: $FRP_VERSION"
  else
    echo "[build] Failed to fetch latest version, fallback to default: $FRP_VERSION"
  fi
fi

echo "[build] Building image: ${IMAGE_NAME}:${FRP_VERSION}"

BUILD_ARGS="
  --build-arg FRP_VERSION=$FRP_VERSION
  --build-arg USE_CN_MIRROR=$USE_CN_MIRROR
  --build-arg APK_MIRROR=$APK_MIRROR
"

[ -n "$HTTP_PROXY" ] && BUILD_ARGS="$BUILD_ARGS --build-arg HTTP_PROXY=$HTTP_PROXY"
[ -n "$HTTPS_PROXY" ] && BUILD_ARGS="$BUILD_ARGS --build-arg HTTPS_PROXY=$HTTPS_PROXY"

if [ -n "$PLATFORM" ]; then
  docker buildx build \
    --platform "$PLATFORM" \
    $BUILD_ARGS \
    -t "${IMAGE_NAME}:${FRP_VERSION}" \
    -t "${IMAGE_NAME}:latest" \
    --load \
    .
else
  docker build \
    $BUILD_ARGS \
    -t "${IMAGE_NAME}:${FRP_VERSION}" \
    -t "${IMAGE_NAME}:latest" \
    .
fi
