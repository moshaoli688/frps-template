# ========================
# Bind
# ========================
bindAddr = "0.0.0.0"
bindPort = ${FRP_BIND_PORT}
kcpBindPort = ${FRP_BIND_PORT}
quicBindPort = ${FRP_QUIC_PORT}

# ========================
# TLS
# ========================
# Controlled by environment variables
# Uncomment the following lines when FRP_TLS_ENABLE=true
# transport.tls.force = ${FRP_TLS_ENABLE}
# transport.tls.certFile = "${FRP_TLS_CERT}"
# transport.tls.keyFile = "${FRP_TLS_KEY}"
# transport.tls.trustedCaFile = "${FRP_TLS_CA}"

# ========================
# Transport
# ========================
transport.maxPoolCount = 10
transport.tcpMux = true
transport.tcpMuxKeepaliveInterval = 60
transport.tcpKeepalive = 7200
transport.quic.keepalivePeriod = 10
transport.quic.maxIdleTimeout = 30
transport.quic.maxIncomingStreams = 100000

# ========================
# Web Server
# ========================
webServer.addr = "0.0.0.0"
webServer.port = ${FRP_DASHBOARD_PORT}
webServer.user = "${FRP_DASHBOARD_USER}"
webServer.password = "${FRP_DASHBOARD_PASS}"
webServer.pprofEnable = false
enablePrometheus = true

# ========================
# Log
# ========================
log.to = "console"
log.level = "${FRP_LOG_LEVEL}"
log.maxDays = 3
log.disablePrintColor = true

# ========================
# Auth
# ========================
detailedErrorsToClient = false
auth.method = "token"
auth.token = "${FRP_TOKEN}"

# ========================
# HTTP Plugins
# ========================
# [[httpPlugins]]
# name = "user-manager"
# addr = "127.0.0.1:9000"
# path = "/handler"
# ops = ["Login"]

# [[httpPlugins]]
# name = "port-manager"
# addr = "127.0.0.1:9001"
# path = "/handler"
# ops = ["NewProxy"]

# ========================
# Port Policy
# ========================
allowPorts = [
  { start = ${FRP_PORT_START}, end = ${FRP_PORT_END} }
]

maxPortsPerClient = ${FRP_MAX_PORTS_PER_CLIENT}
