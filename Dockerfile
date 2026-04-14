# syntax=docker/dockerfile:1.7

ARG ALPINE_VERSION=3.20
ARG FRP_VERSION=0.68.1
ARG USE_CN_MIRROR=false
ARG APK_MIRROR=mirrors.ustc.edu.cn
ARG FRP_RELEASE_BASE_URL=https://github.com/fatedier/frp/releases/download
ARG FRP_RELEASE_TAG_PREFIX=v

FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS downloader
ARG FRP_VERSION
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG USE_CN_MIRROR
ARG APK_MIRROR
ARG ALPINE_VERSION
ARG FRP_RELEASE_BASE_URL
ARG FRP_RELEASE_TAG_PREFIX

ENV HTTP_PROXY=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}
ENV http_proxy=${HTTP_PROXY}
ENV https_proxy=${HTTPS_PROXY}
ENV NO_PROXY=${NO_PROXY}
ENV no_proxy=${NO_PROXY}

RUN set -eux; \
  if [ "$USE_CN_MIRROR" = "true" ]; then \
  printf "https://%s/alpine/v%s/main\n" "$APK_MIRROR" "$ALPINE_VERSION" > /etc/apk/repositories; \
  printf "https://%s/alpine/v%s/community\n" "$APK_MIRROR" "$ALPINE_VERSION" >> /etc/apk/repositories; \
  fi; \
  apk add --no-cache ca-certificates wget tar

WORKDIR /tmp

RUN set -eux; \
  case "${TARGETARCH}${TARGETVARIANT:+/${TARGETVARIANT}}" in \
  amd64)   FRP_ARCH="amd64" ;; \
  arm64)   FRP_ARCH="arm64" ;; \
  arm/v7)  FRP_ARCH="arm_hf" ;; \
  arm/v6)  FRP_ARCH="arm" ;; \
  arm)     FRP_ARCH="arm" ;; \
  *) echo "Unsupported target: ${TARGETOS}/${TARGETARCH}${TARGETVARIANT:+/${TARGETVARIANT}}"; exit 1 ;; \
  esac; \
  FRP_FILE="frp_${FRP_VERSION}_${TARGETOS}_${FRP_ARCH}.tar.gz"; \
  FRP_URL="${FRP_RELEASE_BASE_URL}/${FRP_RELEASE_TAG_PREFIX}${FRP_VERSION}/${FRP_FILE}"; \
  echo "Downloading: ${FRP_URL}"; \
  wget -O frp.tar.gz "${FRP_URL}"; \
  tar -xzf frp.tar.gz; \
  cp "frp_${FRP_VERSION}_${TARGETOS}_${FRP_ARCH}/frps" /usr/local/bin/frps; \
  chmod +x /usr/local/bin/frps

FROM alpine:${ALPINE_VERSION}

ARG USE_CN_MIRROR
ARG APK_MIRROR
ARG ALPINE_VERSION

RUN set -eux; \
  if [ "$USE_CN_MIRROR" = "true" ]; then \
  printf "https://%s/alpine/v%s/main\n" "$APK_MIRROR" "$ALPINE_VERSION" > /etc/apk/repositories; \
  printf "https://%s/alpine/v%s/community\n" "$APK_MIRROR" "$ALPINE_VERSION" >> /etc/apk/repositories; \
  fi; \
  apk add --no-cache ca-certificates tzdata gettext

WORKDIR /app

COPY --from=downloader /usr/local/bin/frps /usr/local/bin/frps
COPY app /app

RUN chmod +x /usr/local/bin/frps /app/entrypoint.sh

ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]
