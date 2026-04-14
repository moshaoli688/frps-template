# frps-gateway

A Docker-based **frps (FRP Server) standardized deployment template** featuring:

- Multi-architecture builds (amd64 / arm64 / arm)
- Custom download sources (official / private distribution)
- Environment-driven configuration (env + template rendering)
- Lightweight, reusable, production-ready design

---

## ✨ Features

- 🔧 **Template-driven config**: Generate config via `.env` + `frps.toml.tpl`
- 🐳 **Dockerized deployment**: Ready to run on servers
- 🌐 **Multi-arch support**: Works across common CPU architectures
- 🚀 **Extensible distribution**: Supports custom FRP release sources
- 📦 **Lightweight image**: Only includes what frps needs
- 🧱 **Clean structure**: Suitable as a reusable infrastructure template

---

## 📁 Project Structure

```
frps-template/
├── app/
│   ├── config/
│   │   └── frps.toml.tpl
│   ├── certs/
│   └── entrypoint.sh
├── .env
├── docker-compose.yml
├── Dockerfile
└── build.sh
```

---

## 🚀 Quick Start

### 1. Configure Environment Variables

Edit `.env`:

```env
CONTAINER_NAME=frps-gateway-demo
FRPS_IMAGE=frps-gateway:latest

FRP_BIND_PORT=8000
FRP_QUIC_PORT=4000
FRP_PORT_START=20000
FRP_PORT_END=40000

FRP_DASHBOARD_PORT=8088
FRP_DASHBOARD_USER=admin
FRP_DASHBOARD_PASS=your_password

FRP_TOKEN=your_token

FRP_MAX_PORTS_PER_CLIENT=3
FRP_LOG_LEVEL=info
```

---

### 2. Build Image

```
./build.sh
```

---

### 3. Start Service

```
docker compose up -d
```

View logs:

```
docker compose logs -f
```

---

## 🧠 Configuration

### Template Example

```toml
bindPort = ${FRP_BIND_PORT}
quicBindPort = ${FRP_QUIC_PORT}

auth.token = "${FRP_TOKEN}"

allowPorts = [
  { start = ${FRP_PORT_START}, end = ${FRP_PORT_END} }
]
```

---

## 🌐 Network Mode

Recommended:

```
network_mode: host
```

Best suited for large port-range FRP scenarios.

---

## 🔐 Security Recommendations

- Use a strong random `FRP_TOKEN`
- Bind dashboard to localhost when possible:

```toml
webServer.addr = "127.0.0.1"
```

---

## 🪵 Log Example

```
========== [frps init] ==========
[frps init] Generating config...
[frps init] Validating config...
[frps init] Config OK

========== [frps start] ==========
[frps start] Starting frps...
```

---

## 📦 Build

Default:

```
./build.sh
```

Specify version:

```
FRP_VERSION=0.68.1 ./build.sh
```

---

## 🌍 Custom Release Source

```
docker build \
  --build-arg FRP_RELEASE_BASE_URL=https://your-server/frp \
  --build-arg FRP_VERSION=0.68.1 \
  -t frps-gateway .
```

---

## 🔒 TLS & Certificates

Generate certificates using the built-in script:

### 1. Initialize CA + Server Certificate (with SAN)

```
./build-cert.sh init
```

Optional environment variables:

```
SERVER_DNS_NAMES=www.bilibili.com,www.taobao.com,localhost \
SERVER_IP_ADDRESSES=127.0.0.1,1.2.3.4 \
SERVER_CN=server \
./build-cert.sh init
```

- Public IPv4 will be auto-detected if `SERVER_IP_ADDRESSES` is not provided
- SAN will include both DNS and IP entries

---

### 2. Generate Client Certificate

```
./build-cert.sh client node-a
```

Optional environment variables:

```
CLIENT_DNS_NAMES=node-a \
CLIENT_CN=node-a \
./build-cert.sh client node-a
```

- Client certificates typically do not require IP SAN entries
- Used for mTLS authentication with frps

---

### 3. Enable TLS in `.env`

```
FRP_TLS_ENABLE=true
FRP_TLS_CERT=/app/certs/server.crt
FRP_TLS_KEY=/app/certs/server.key
FRP_TLS_CA=/app/certs/ca.crt
```

---

## 📌 Design Philosophy

> Not just running frps, but building a standardized, reusable deployment component

---

## 📄 License

MIT
