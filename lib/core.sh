# Em4dloverS Tunnel Manager - core: settings, catalog, system helpers
# Sourced by emad.sh. Do not run directly.
VER="1.2.0"
ROOT="${EMAD_ROOT:-}"                       # test override only
APP=/opt/emadlovers; CONF="$ROOT/etc/emadlovers"; TUN="$CONF/tunnels.d"; RUN="$CONF/run"; CFG="$CONF/cfg"
LOG="${EMAD_LOG:-/var/log/emadlovers.log}"; UNITDIR="$ROOT/etc/systemd/system"
R=$'\e[1;31m'; DR=$'\e[0;31m'; G=$'\e[1;32m'; Y=$'\e[1;33m'; W=$'\e[1;37m'; D=$'\e[2m'; N=$'\e[0m'
nap(){ [ -n "${EMAD_DEMO:-}" ] || sleep "$1"; }
sysd(){ [ -n "${EMAD_NOSYS:-}" ] || systemctl "$@"; }
die(){ printf '\n  %s[!]%s %s\n\n' "$R" "$N" "$*"; exit 1; }
ARCH_G=$(case $(uname -m) in x86_64) echo amd64;; aarch64) echo arm64;; *) echo unsupported;; esac)
ARCH_X=$(uname -m)

# ---------- catalog: type|name|description ----------
CATALOG='gre|GRE|Fast kernel L3 tunnel|GRE
gretap|GRE-TAP|Kernel L2 tunnel over GRE|GRE
gre6|GRE6 (ip6gre)|GRE over IPv6 endpoints|GRE
gre6tap|GRE6-TAP|L2 GRE over IPv6|GRE
gre-fou|GRE over FOU|GRE inside UDP, passes NAT|GRE
gre-gue|GRE over GUE|GRE inside Generic UDP Encap|GRE
gretap-fou|GRE-TAP over FOU|L2 GRE inside UDP|GRE
gretap-gue|GRE-TAP over GUE|L2 GRE inside GUE|GRE
frp-tcp|FRP TCP|Reverse proxy, TCP|FRP
frp-kcp|FRP KCP|Reverse proxy, KCP|FRP
frp-quic|FRP QUIC|Reverse proxy, QUIC|FRP
frp-websocket|FRP WebSocket|Reverse proxy, WebSocket|FRP
backhaul-tcp|Backhaul TCP|Reverse tunnel, TCP|Backhaul
backhaul-tcpudp|Backhaul TCP+UDP|One port carries TCP and UDP (accept_udp)|Backhaul
backhaul-tcpmux|Backhaul TCPMux|Reverse tunnel, TCPMux|Backhaul
backhaul-udp|Backhaul UDP|Reverse tunnel, UDP|Backhaul
backhaul-ws|Backhaul WS|Reverse tunnel, WS|Backhaul
backhaul-wsmux|Backhaul WSMux|Reverse tunnel, WSMux|Backhaul
backhaul-wss|Backhaul WSS|WebSocket over TLS (self-signed ECDSA P-384 cert)|Backhaul
rathole|Rathole TCP|Reverse tunnel in Rust, very fast|Rathole
gost-tcp|GOST relay TCP|GOST relay protocol over TCP|GOST relay
gost-tls|GOST relay+TLS|GOST relay protocol over TLS|GOST relay
gost-mtls|GOST relay+MTLS|GOST relay protocol over MTLS|GOST relay
gost-ws|GOST relay+WS|GOST relay protocol over WS|GOST relay
gost-mws|GOST relay+MWS|GOST relay protocol over MWS|GOST relay
gost-wss|GOST relay+WSS|GOST relay protocol over WSS|GOST relay
gost-mwss|GOST relay+MWSS|GOST relay protocol over MWSS|GOST relay
gost-h2|GOST relay+H2|GOST relay protocol over H2|GOST relay
gost-h2c|GOST relay+H2C|GOST relay protocol over H2C|GOST relay
gost-quic|GOST relay+QUIC|GOST relay protocol over QUIC|GOST relay
gost-kcp|GOST relay+KCP|GOST relay protocol over KCP|GOST relay
gost-grpc|GOST relay+gRPC|GOST relay protocol over gRPC|GOST relay
gosts-tcp|GOST SOCKS5 TCP|GOST SOCKS5 over TCP|GOST SOCKS5
gosts-tls|GOST SOCKS5+TLS|GOST SOCKS5 over TLS|GOST SOCKS5
gosts-mtls|GOST SOCKS5+MTLS|GOST SOCKS5 over MTLS|GOST SOCKS5
gosts-ws|GOST SOCKS5+WS|GOST SOCKS5 over WS|GOST SOCKS5
gosts-mws|GOST SOCKS5+MWS|GOST SOCKS5 over MWS|GOST SOCKS5
gosts-wss|GOST SOCKS5+WSS|GOST SOCKS5 over WSS|GOST SOCKS5
gosts-mwss|GOST SOCKS5+MWSS|GOST SOCKS5 over MWSS|GOST SOCKS5
gosts-h2|GOST SOCKS5+H2|GOST SOCKS5 over H2|GOST SOCKS5
gosts-h2c|GOST SOCKS5+H2C|GOST SOCKS5 over H2C|GOST SOCKS5
gosts-quic|GOST SOCKS5+QUIC|GOST SOCKS5 over QUIC|GOST SOCKS5
gosts-kcp|GOST SOCKS5+KCP|GOST SOCKS5 over KCP|GOST SOCKS5
gosts-grpc|GOST SOCKS5+gRPC|GOST SOCKS5 over gRPC|GOST SOCKS5
rathole-udp|Rathole UDP|Reverse tunnel, UDP services (untested on servers)|Rathole'
REVERSE_RX='^(rathole.*|backhaul-.*|frp-.*|chisel.*)$'

engine_of(){ case $1 in gre|gretap|ipip|vxlan|geneve|gre6|gre6tap|ipip6|dnat|*-fou|*-gue) echo kernel;; wg|wg-psk|wg-1280) echo wg;; socat-*) echo socat;;
  haproxy) echo haproxy;; gost-*|gosts-*) echo gost;; rathole|rathole-udp) echo rathole;; backhaul-*) echo backhaul;; frp-*) echo frp;; chisel|chisel-tls) echo chisel;; hy2|hy2-obfs) echo hysteria;; xray-*) echo xray;; esac; }
type_name(){ echo "$CATALOG" | awk -F'|' -v t="$1" '$1==t{print $2}'; }

# ---------- system ----------
need_root(){ [ -n "${EMAD_DEMO:-}${EMAD_NOSYS:-}" ] || [ "$(id -u)" = 0 ] || die "Run as root:  sudo emad"; }
detect_os(){
  [ -n "${EMAD_DEMO:-}" ] && { OS_NAME=Ubuntu; OS_VER=24.04; return; }
  . /etc/os-release 2>/dev/null; OS_NAME=${NAME:-?}; OS_VER=${VERSION_ID:-?}
  case "${ID:-}:${OS_VER}" in ubuntu:20.04|ubuntu:22.04|ubuntu:24.04|ubuntu:26.04|debian:11|debian:12|debian:13) ;;
    *) die "Unsupported OS: $OS_NAME $OS_VER. Supported: Ubuntu 20.04/22.04/24.04/26.04, Debian 11/12/13." ;; esac
}
myip(){ [ -n "${MYIP:-}" ] && return; [ -n "${EMAD_DEMO:-}" ] && { MYIP=203.0.113.10; return; }
  MYIP=$(curl -s4 -m 4 https://api.ipify.org || curl -s4 -m 4 https://ifconfig.me || hostname -I | awk '{print $1}'); }
apt_update(){ DEBIAN_FRONTEND=noninteractive apt-get update -qq; }
apt_i(){ DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@"; }
ssh_port(){ ss -tlnp 2>/dev/null | awk '/sshd/{n=split($4,a,":");print a[n];exit}'; }
port_free(){ ! ss -tuln 2>/dev/null | awk '{print $5}' | grep -qE "[:.]$1$"; }
rand_port(){ local p; while :; do p=$(shuf -i 10000-60000 -n1); port_free "$p" && { echo "$p"; return; }; done; }
rand_token(){ tr -dc "A-Za-z0-9" </dev/urandom | head -c 40; }
rand_str(){ tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-16}"; }
