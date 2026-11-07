#!/usr/bin/env bash
# Em4dloverS Tunnel Manager  |  t.me/Em4dloverS  |  support: t.me/KaMr4ng
VER="1.1.0"
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
CATALOG='gre|GRE|Fast kernel L3 tunnel|Kernel
gretap|GRE-TAP|Kernel L2 tunnel over GRE|Kernel
ipip|IPIP|Lightest kernel tunnel|Kernel
vxlan|VXLAN|Kernel UDP L2 tunnel|Kernel
geneve|GENEVE|Kernel UDP tunnel, flexible|Kernel
gre6|GRE6 (ip6gre)|GRE over IPv6 endpoints|Kernel
gre6tap|GRE6-TAP|L2 GRE over IPv6|Kernel
ipip6|IPIP6 (ip6tnl)|IPv4 inside IPv6|Kernel
dnat|Direct DNAT|iptables forward, no encryption|Kernel
gre-fou|GRE over FOU|GRE inside UDP, passes NAT|UDP Encap
gre-gue|GRE over GUE|GRE inside Generic UDP Encap|UDP Encap
gretap-fou|GRE-TAP over FOU|L2 GRE inside UDP|UDP Encap
gretap-gue|GRE-TAP over GUE|L2 GRE inside GUE|UDP Encap
ipip-fou|IPIP over FOU|IPIP inside UDP, low overhead|UDP Encap
ipip-gue|IPIP over GUE|IPIP inside GUE|UDP Encap
wg|WireGuard|Encrypted UDP, modern and fast|WireGuard
wg-psk|WireGuard + PSK|Extra preshared key from token|WireGuard
wg-1280|WireGuard MTU 1280|Safe MTU for filtered routes|WireGuard
socat-tcp|Socat TCP|Simple TCP relay|Relay
socat-udp|Socat UDP|Simple UDP relay|Relay
haproxy|HAProxy TCP|L4 forward with port ranges|Relay
gost-tcp|GOST relay TCP|GOST relay protocol over TCP|GOST Relay
gost-tls|GOST relay+TLS|GOST relay protocol over TLS|GOST Relay
gost-mtls|GOST relay+MTLS|GOST relay protocol over MTLS|GOST Relay
gost-ws|GOST relay+WS|GOST relay protocol over WS|GOST Relay
gost-mws|GOST relay+MWS|GOST relay protocol over MWS|GOST Relay
gost-wss|GOST relay+WSS|GOST relay protocol over WSS|GOST Relay
gost-mwss|GOST relay+MWSS|GOST relay protocol over MWSS|GOST Relay
gost-h2|GOST relay+H2|GOST relay protocol over H2|GOST Relay
gost-h2c|GOST relay+H2C|GOST relay protocol over H2C|GOST Relay
gost-quic|GOST relay+QUIC|GOST relay protocol over QUIC|GOST Relay
gost-kcp|GOST relay+KCP|GOST relay protocol over KCP|GOST Relay
gost-grpc|GOST relay+gRPC|GOST relay protocol over gRPC|GOST Relay
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
rathole|Rathole TCP|Reverse tunnel in Rust, very fast|Reverse
backhaul-tcp|Backhaul TCP|Reverse tunnel, TCP|Reverse
backhaul-tcpmux|Backhaul TCPMux|Reverse tunnel, TCPMux|Reverse
backhaul-udp|Backhaul UDP|Reverse tunnel, UDP|Reverse
backhaul-ws|Backhaul WS|Reverse tunnel, WS|Reverse
backhaul-wsmux|Backhaul WSMux|Reverse tunnel, WSMux|Reverse
frp-tcp|FRP TCP|Reverse proxy, TCP|Reverse
frp-kcp|FRP KCP|Reverse proxy, KCP|Reverse
frp-quic|FRP QUIC|Reverse proxy, QUIC|Reverse
frp-websocket|FRP WebSocket|Reverse proxy, WebSocket|Reverse
chisel|Chisel HTTP|Reverse tunnel over HTTP/WS|Reverse
chisel-tls|Chisel HTTPS|Reverse tunnel over TLS|Reverse
hy2|Hysteria2|QUIC tunnel, great on lossy links|Hysteria2
hy2-obfs|Hysteria2 + Obfs|QUIC with salamander obfuscation|Hysteria2
xray-vmess-tcp|Xray VMess TCP|Xray tunnel, VMess TCP|Xray
xray-vmess-ws|Xray VMess WebSocket|Xray tunnel, VMess WebSocket|Xray
xray-vmess-grpc|Xray VMess gRPC|Xray tunnel, VMess gRPC|Xray
xray-vmess-httpupgrade|Xray VMess HTTPUpgrade|Xray tunnel, VMess HTTPUpgrade|Xray
xray-vmess-kcp|Xray VMess mKCP|Xray tunnel, VMess mKCP|Xray
xray-vless-ws|Xray VLESS WebSocket|Xray tunnel, VLESS WebSocket|Xray
xray-vless-grpc|Xray VLESS gRPC|Xray tunnel, VLESS gRPC|Xray
xray-vless-httpupgrade|Xray VLESS HTTPUpgrade|Xray tunnel, VLESS HTTPUpgrade|Xray
xray-ss-aes128|Xray Shadowsocks AES-128|Xray tunnel, Shadowsocks AES-128|Xray
xray-ss-aes256|Xray Shadowsocks AES-256|Xray tunnel, Shadowsocks AES-256|Xray
xray-ss-chacha|Xray Shadowsocks ChaCha20|Xray tunnel, Shadowsocks ChaCha20|Xray'
REVERSE_RX='^(rathole|backhaul-.*|frp-.*|chisel.*)$'

engine_of(){ case $1 in gre|gretap|ipip|vxlan|geneve|gre6|gre6tap|ipip6|dnat|*-fou|*-gue) echo kernel;; wg|wg-psk|wg-1280) echo wg;; socat-*) echo socat;;
  haproxy) echo haproxy;; gost-*|gosts-*) echo gost;; rathole) echo rathole;; backhaul-*) echo backhaul;; frp-*) echo frp;; chisel|chisel-tls) echo chisel;; hy2|hy2-obfs) echo hysteria;; xray-*) echo xray;; esac; }
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
rand_str(){ tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-16}"; }

# ---------- UI ----------
banner(){
  [ -n "${EMAD_DEMO:-}" ] || clear
  local pal=(52 88 124 160 196 196 160 124 88 52 88 124 160 196 196 160 124 88) n=0 l
  while IFS= read -r l; do printf '\e[38;5;%sm%s\e[0m\n' "${pal[$((n++ % 18))]}" "$l"; nap 0.05; done <<'ART'
▄▄▄▄▄▄▄▄▄▄▄                                ▄▄▄▄▄             ████
████▀▀▀▀▀▀▀                               ██████             ████
████           ▄▄▄▄ ▄▄▄▄    ▄▄▄▄        ▄██▀████       ▄▄▄▄  ████
████           █████▀▀██████▀▀███▄     ███▀ ████     ▄███▀▀▀█████
███████████    ████   ▀████   ████   ▄███   ████    ████     ████
████           ████    ███    ████   ███▄▄▄▄████▄▄  ████     ████
████           ████    ███    ████   ▀▀▀▀▀▀▀████▀▀  ████     ████
████▄▄▄▄▄▄▄    ████    ███    ████          ████     ▀███▄▄▄█████
▀▀▀▀▀▀▀▀▀▀▀    ▀▀▀▀    ▀▀▀    ▀▀▀▀          ▀▀▀▀       ▀▀▀▀  ▀▀▀▀
 ████                                                             ▄▄▄▄▄▄▄▄▄
 ████                                                           ▄███▀▀▀▀███
 ████       ▄▄▄▄▄▄    ▄▄▄▄      ▄▄▄▄     ▄▄▄▄▄       ▄▄▄▄ ▄▄▄▄  ███       ▀
 ████    ▄███▀▀▀███▄   ████    ▄███   ▄███▀▀▀███▄    █████▀▀▀▀  ████▄▄▄
 ████   ████     ████   ███▄   ███▀  ████     ███▄   ████       ▀█████████▄
 ████   ████     ████   ▀███▄ ███▀   █████████████   ████           ▀▀▀█████
 ████   ████     ████    ▀███████    ████            ████       ▄       ████
 ████    ▀███▄▄▄███▀      ██████      ▀███▄▄▄▄▄██    ████       ███▄▄▄▄████▀
 ▀▀▀▀       ▀▀▀▀▀▀         ▀▀▀▀▀         ▀▀▀▀▀▀▀     ▀▀▀▀        ▀▀▀▀▀▀▀▀
ART
  printf '\n  %sEm4dloverS Tunnel Manager%s  v%s\n' "$W" "$N" "$VER"
  printf '  %sChannel%s  t.me/Em4dloverS\n  %sSupport%s  %st.me/KaMr4ng%s\n' "$R" "$N" "$R" "$N" "$D" "$N"
  printf '  %s%s%s\n' "$DR" "$(printf '%.0s=' $(seq 1 60))" "$N"
  myip; printf '  %s%s %s  |  IP %s%s' "$D" "$OS_NAME" "$OS_VER" "$MYIP" "$N"; nap 1.8; printf '\r\e[K'
}
hdr(){ printf '\n  %s[ %s ]%s\n\n' "$R" "$1" "$N"; }
ask(){ local v; printf '  %s%s%s%s: ' "$W" "$1" "${2:+ [$2]}" "$N"; read -r v; REPLY=${v:-${2:-}}; }
pause(){ printf '\n  %sPress Enter to go back...%s' "$D" "$N"; read -r _; }
STEPS=(); TOTAL=1; DONEN=0
bar(){ local p=$((DONEN*100/TOTAL)) f=$((DONEN*30/TOTAL)); printf '  %s[%s%s]%s %3d%%\n' "$R" "$(printf '%.0s#' $(seq 1 $f))" "$(printf '%.0s-' $(seq 1 $((30-f))))" "$N" "$p"; }
step(){ local msg=$1 p i=0 sp='|/-\'; shift
  "$@" >>"$LOG" 2>&1 & p=$!
  while kill -0 $p 2>/dev/null; do printf '\r  %s[%s]%s %s ' "$R" "${sp:$((i++%4)):1}" "$N" "$msg"; sleep 0.1; done
  DONEN=$((DONEN+1))
  if wait $p; then printf '\r\e[K  %s[ OK ]%s %s\n' "$G" "$N" "$msg"; STEPS+=("OK|$msg")
  else printf '\r\e[K  %s[FAIL]%s %s  (log: %s)\n' "$R" "$N" "$msg" "$LOG"; STEPS+=("FAIL|$msg"); fi; bar; }
summary(){ printf '\n  %sInstalled so far:%s\n' "$W" "$N"; local s; for s in "${STEPS[@]}"; do
  [ "${s%%|*}" = OK ] && printf '   %s+%s %s\n' "$G" "$N" "${s#*|}" || printf '   %sx%s %s\n' "$R" "$N" "${s#*|}"; done; nap 2; }

# ---------- engines ----------
fetch_bin(){ local repo=$1 rx=$2 t=/tmp/emad_dl url b f; shift 2; rm -rf $t; mkdir -p $t
  url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 | grep -E "$rx" | head -1)
  [ -n "$url" ] || return 1; curl -fsSL "$url" -o $t/pkg || return 1
  case $url in *.zip) unzip -qo $t/pkg -d $t;; *.tar.gz) tar xzf $t/pkg -C $t;; *.gz) gunzip -c $t/pkg >$t/$1;; *) cp $t/pkg $t/$1;; esac
  for b in "$@"; do f=$(find $t -type f -name "$b" | head -1); [ -n "$f" ] || return 1; install -m755 "$f" /usr/local/bin/$b; done; }
install_engine(){ local e=$1; STEPS=(); DONEN=0; TOTAL=3; mkdir -p "$(dirname "$LOG")"
  step "Updating package index" apt_update
  case $e in
   kernel) TOTAL=2; step "Installing iproute2, iptables, kmod" apt_i iproute2 iptables kmod;;
   wg) step "Installing WireGuard" apt_i wireguard wireguard-tools iproute2 iptables; TOTAL=2;;
   socat) TOTAL=2; step "Installing socat" apt_i socat;;
   haproxy) TOTAL=3; step "Installing HAProxy" apt_i haproxy; step "Disabling stock haproxy service" sysd disable --now haproxy;;
   *) step "Installing curl, unzip, tar, openssl" apt_i curl unzip tar gzip ca-certificates openssl
      case $e in
       gost) step "Downloading GOST" fetch_bin ginuerzh/gost "linux[_-]${ARCH_G}[-.][^/]*gz\$" gost;;
       rathole) step "Downloading Rathole" fetch_bin rapiz1/rathole "rathole-${ARCH_X}-unknown-linux-(gnu|musl)\.zip\$" rathole;;
       backhaul) step "Downloading Backhaul" fetch_bin Musixal/Backhaul "backhaul_linux_${ARCH_G}\.tar\.gz\$" backhaul;;
       frp) step "Downloading FRP" fetch_bin fatedier/frp "frp_.*_linux_${ARCH_G}\.tar\.gz\$" frps frpc;;
       chisel) step "Downloading Chisel" fetch_bin jpillora/chisel "chisel_.*_linux_${ARCH_G}\.gz\$" chisel;;
       hysteria) step "Downloading Hysteria2" fetch_bin apernet/hysteria "hysteria-linux-${ARCH_G}\$" hysteria;;
       xray) step "Downloading Xray" fetch_bin XTLS/Xray-core "Xray-linux-$([ "$ARCH_G" = amd64 ] && echo 64 || echo arm64-v8a)\.zip\$" xray;;
      esac;; esac
  step "Preparing directories" mkdir -p "$TUN" "$RUN" "$CFG" "$CONF/keys"
  summary; }

# ---------- ports ----------
valid_ports(){ local t a b; [ -n "$1" ] || return 1
  for t in ${1//,/ }; do
    if [[ $t =~ ^([0-9]+)-([0-9]+)$ ]]; then a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}; [ "$a" -ge 1 ] && [ "$b" -le 65535 ] && [ "$a" -le "$b" ] || return 1
    elif [[ $t =~ ^[0-9]+$ ]]; then [ "$t" -ge 1 ] && [ "$t" -le 65535 ] || return 1; else return 1; fi; done; }
port_tokens(){ echo "${PORTS//,/ }"; }
port_list(){ local t; for t in $(port_tokens); do [[ $t == *-* ]] && seq "${t%-*}" "${t#*-}" || echo "$t"; done; }
fw_open(){ command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q active || return 0
  local t; [ -n "${CPORT:-}" ] && [ "$CPORT" != 0 ] && ufw allow "$CPORT" >/dev/null 2>&1
  if [ "$ROLE" = iran ] || [[ $TYPE =~ $REVERSE_RX ]]; then for t in $(port_tokens); do
    if [[ $t == *-* ]]; then ufw allow "${t/-/:}/tcp" >/dev/null 2>&1; ufw allow "${t/-/:}/udp" >/dev/null 2>&1; else ufw allow "$t" >/dev/null 2>&1; fi; done; fi; return 0; }

# ---------- generators (print lines of the run script) ----------
gen_kernel(){ local a=1 b=2 ifn=emad$IDX mk="" tok pr dst MTU=1400 wa fp=$((31000+IDX)) pre="" inp="" k e ipp lt post="" extra=""
  [ "$ROLE" = foreign ] && { a=2; b=1; }
  case $TYPE in
   gre) mk="ip tunnel add $ifn mode gre local $LOCAL remote $REMOTE ttl 255"; inp="-p gre";;
   gretap) mk="ip link add $ifn type gretap local $LOCAL remote $REMOTE ttl 255"; inp="-p gre";;
   ipip) mk="ip tunnel add $ifn mode ipip local $LOCAL remote $REMOTE ttl 255"; inp="-p ipencap";;
   vxlan) MTU=1380; mk="ip link add $ifn type vxlan id $IDX local $LOCAL remote $REMOTE dstport $((4789+IDX)) nolearning"; inp="-p udp --dport $((4789+IDX))";;
   geneve) MTU=1380; mk="ip link add $ifn type geneve id $IDX remote $REMOTE dstport $((6081+IDX))"; inp="-p udp --dport $((6081+IDX))";;
   gre6) MTU=1380; mk="ip link add $ifn type ip6gre local $LOCAL remote $REMOTE ttl 255";;
   gre6tap) MTU=1380; mk="ip link add $ifn type ip6gretap local $LOCAL remote $REMOTE ttl 255";;
   ipip6) MTU=1380; mk="ip link add $ifn type ip6tnl mode ipip6 local $LOCAL remote $REMOTE";;
   *-fou|*-gue) MTU=1380; k=${TYPE%%-*}; e=${TYPE##*-}; case $k in gre|gretap) ipp=47;; *) ipp=4;; esac
      pre="modprobe fou 2>/dev/null; ip fou del port $fp 2>/dev/null; ip fou add port $fp $([ $e = gue ] && echo gue || echo "ipproto $ipp")"; post="ip fou del port $fp 2>/dev/null"
      mk="ip link add $ifn type $k local $LOCAL remote $REMOTE ttl 255 encap $e encap-sport auto encap-dport $fp"; inp="-p udp --dport $fp";;
   wg|wg-psk|wg-1280) MTU=1380; [ $TYPE = wg-1280 ] && MTU=1280; mk="ip link add $ifn type wireguard"; inp="-p udp --dport $((51800+IDX))";;
  esac
  [ -n "${TMTU:-}" ] && MTU=$TMTU
  echo "sysctl -qw net.ipv4.ip_forward=1 net.ipv4.conf.all.rp_filter=0 net.ipv4.conf.default.rp_filter=0"
  echo 'rules(){ local o=$1 i=$1; [ "$o" = -A ] && i=-I'
  [ "$TYPE" != dnat ] && { echo "  iptables \$i INPUT -i $ifn -j ACCEPT"; echo "  iptables \$i FORWARD -i $ifn -j ACCEPT"; echo "  iptables \$i FORWARD -o $ifn -j ACCEPT"
    echo "  iptables -t mangle \$o POSTROUTING -o $ifn -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss $((MTU-40))"; }
  [ -n "$inp" ] && echo "  iptables \$i INPUT $inp -s $REMOTE -j ACCEPT"
  if [ "$ROLE" = iran ]; then
    dst="10.$IDX.0.2"; [ "$TYPE" = dnat ] && dst=$REMOTE
    for tok in $(port_tokens); do for pr in tcp udp; do
      echo "  iptables -t nat \$o PREROUTING -p $pr --dport ${tok/-/:} -j DNAT --to-destination $dst"; done; done
    if [ "$TYPE" = dnat ]; then echo "  iptables -t nat \$o POSTROUTING -d $REMOTE -j MASQUERADE"; echo "  iptables \$i FORWARD -d $REMOTE -j ACCEPT"; echo "  iptables \$i FORWARD -s $REMOTE -j ACCEPT"
    else echo "  iptables -t nat \$o POSTROUTING -o $ifn -j MASQUERADE"; fi
  fi
  echo '  :'; echo '}'; echo 'case $1 in'; echo ' start)'
  if [ "$TYPE" = dnat ]; then echo "  rules -D 2>/dev/null; rules -A ;;"; echo " stop) rules -D 2>/dev/null ;;"
  else
    [ -n "$pre" ] && echo "  $pre"
    echo "  ip link del $ifn 2>/dev/null; $mk || exit 1"
    if [[ $TYPE == wg* ]]; then wa="private-key $CONF/keys/$NAME.key listen-port $((51800+IDX))"
      if [ "$TYPE" = wg-psk ]; then printf "$(printf %s "$(printf %s "$TOKEN" | sha256sum | cut -d' ' -f1)" | sed 's/../\\x&/g')" | base64 >"$CONF/keys/$NAME.psk"; chmod 600 "$CONF/keys/$NAME.psk"; extra=" preshared-key $CONF/keys/$NAME.psk"; fi
      [ -n "${PEER:-}" ] && { wa+=" peer $PEER$extra allowed-ips 10.$IDX.0.0/30"; [ "$ROLE" = iran ] && wa+=" endpoint $REMOTE:$((51800+IDX)) persistent-keepalive 15"; }
      echo "  wg set $ifn $wa"; fi
    echo "  ip addr add 10.$IDX.0.$a/30 dev $ifn; ip link set $ifn txqueuelen 10000 mtu $MTU up"
    echo "  command -v ufw >/dev/null && ufw allow in on $ifn >/dev/null 2>&1"
    echo "  rules -D 2>/dev/null; rules -A ;;"
    echo " stop) rules -D 2>/dev/null; ip link del $ifn 2>/dev/null; $post ;;"
  fi; echo 'esac'; }

gen_gost(){ local fam=${TYPE%%-*} t=${TYPE#*-} base=relay sch a="" p; [ "$fam" = gosts ] && base=socks5; sch="$base+$t"; [ "$t" = tcp ] && sch=$base; echo 'case $1 in start)'
  if [ "$ROLE" = foreign ]; then echo "  exec gost -L \"$sch://emad:$TOKEN@:$CPORT\" ;;"
  else for p in $(port_list); do a+=" -L tcp://:$p/127.0.0.1:$p"; done
       echo "  exec gost$a -F \"$sch://emad:$TOKEN@$REMOTE:$CPORT\" ;;"; fi; echo 'esac'; }
gen_rathole(){ local f=$CFG/$NAME.toml p; echo 'case $1 in start)'
  if [ "$ROLE" = iran ]; then { printf '[server]\nbind_addr = "0.0.0.0:%s"\ndefault_token = "%s"\n' "$CPORT" "$TOKEN"
      for p in $(port_list); do printf '[server.services.p%s]\nbind_addr = "0.0.0.0:%s"\n' "$p" "$p"; done; } >"$f"
  else { printf '[client]\nremote_addr = "%s:%s"\ndefault_token = "%s"\n' "$REMOTE" "$CPORT" "$TOKEN"
      for p in $(port_list); do printf '[client.services.p%s]\nlocal_addr = "127.0.0.1:%s"\n' "$p" "$p"; done; } >"$f"; fi
  chmod 600 "$f"; echo "  exec rathole $f ;;"; echo 'esac'; }
gen_backhaul(){ local f=$CFG/$NAME.toml tr=${TYPE#backhaul-} t pl=""; echo 'case $1 in start)'
  if [ "$ROLE" = iran ]; then for t in $(port_tokens); do pl+="\"$t\", "; done
    printf '[server]\nbind_addr = "0.0.0.0:%s"\ntransport = "%s"\ntoken = "%s"\nnodelay = true\nkeepalive_period = 75\nlog_level = "info"\nports = [%s]\n' "$CPORT" "$tr" "$TOKEN" "${pl%, }" >"$f"
  else printf '[client]\nremote_addr = "%s:%s"\ntransport = "%s"\ntoken = "%s"\nnodelay = true\nkeepalive_period = 75\nlog_level = "info"\n' "$REMOTE" "$CPORT" "$tr" "$TOKEN" >"$f"; fi
  chmod 600 "$f"; echo "  exec backhaul -c $f ;;"; echo 'esac'; }
gen_frp(){ local pr=${TYPE#frp-} f p; echo 'case $1 in start)'
  if [ "$ROLE" = iran ]; then f=$CFG/$NAME.frps.toml
    { printf 'bindPort = %s\nauth.token = "%s"\n' "$CPORT" "$TOKEN"
      [ "$pr" = kcp ] && echo "kcpBindPort = $CPORT"; [ "$pr" = quic ] && echo "quicBindPort = $CPORT"; } >"$f"; echo "  exec frps -c $f ;;"
  else f=$CFG/$NAME.frpc.toml
    { printf 'serverAddr = "%s"\nserverPort = %s\nauth.token = "%s"\ntransport.protocol = "%s"\n' "$REMOTE" "$CPORT" "$TOKEN" "$pr"
      for p in $(port_list); do printf '[[proxies]]\nname = "p%s"\ntype = "tcp"\nlocalIP = "127.0.0.1"\nlocalPort = %s\nremotePort = %s\n' "$p" "$p" "$p"; done; } >"$f"
    echo "  exec frpc -c $f ;;"; fi; chmod 600 "$f"; echo 'esac'; }
gen_chisel(){ local a="" p tls="" sch=http c=$CFG/$NAME; echo 'case $1 in start)'
  if [ "$TYPE" = chisel-tls ]; then sch=https
    if [ "$ROLE" = iran ]; then [ -f $c.crt ] || openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj /CN=emad -keyout $c.key -out $c.crt 2>/dev/null; tls=" --tls-key $c.key --tls-cert $c.crt"; else tls=" --tls-skip-verify"; fi; fi
  if [ "$ROLE" = iran ]; then echo "  exec chisel server --port $CPORT --reverse --auth emad:$TOKEN$tls ;;"
  else for p in $(port_list); do a+=" R:0.0.0.0:$p:127.0.0.1:$p"; done
       echo "  exec chisel client --auth emad:$TOKEN --keepalive 10s$tls $sch://$REMOTE:$CPORT$a ;;"; fi; echo 'esac'; }
gen_socat(){ local pr=TCP p; [ "$TYPE" = socat-udp ] && pr=UDP; echo 'case $1 in start)'
  if [ "$ROLE" = iran ]; then for p in $(port_list); do echo "  socat $pr-LISTEN:$p,fork,reuseaddr $pr:$REMOTE:$p &"; done; echo "  wait ;;"
  else echo "  exec sleep infinity ;;"; fi; echo 'esac'; }
gen_haproxy(){ local f=$CFG/$NAME.cfg t; echo 'case $1 in start)'
  if [ "$ROLE" = iran ]; then { printf 'global\n  maxconn 100000\ndefaults\n  mode tcp\n  timeout connect 5s\n  timeout client 1h\n  timeout server 1h\n  option tcpka\nfrontend f\n'
      for t in $(port_tokens); do echo "  bind *:$t"; done; printf '  default_backend b\nbackend b\n  server s1 %s\n' "$REMOTE"; } >"$f"
    echo "  exec haproxy -db -f $f ;;"; else echo "  exec sleep infinity ;;"; fi; echo 'esac'; }

gen_hysteria(){ local f=$CFG/$NAME.yaml p ob=""; echo 'case $1 in start)'
  [ "$TYPE" = hy2-obfs ] && ob=$'obfs:\n  type: salamander\n  salamander:\n    password: '"$TOKEN"$'\n'
  if [ "$ROLE" = foreign ]; then [ -f $CFG/$NAME.crt ] || openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 3650 -subj /CN=emad -keyout $CFG/$NAME.key -out $CFG/$NAME.crt 2>/dev/null
    printf 'listen: :%s\ntls:\n  cert: %s\n  key: %s\nauth:\n  type: password\n  password: %s\n%s' "$CPORT" "$CFG/$NAME.crt" "$CFG/$NAME.key" "$TOKEN" "$ob" >"$f"; echo "  exec hysteria server -c $f ;;"
  else { printf 'server: %s:%s\nauth: %s\ntls:\n  insecure: true\n%s' "$REMOTE" "$CPORT" "$TOKEN" "$ob"
      echo "tcpForwarding:"; for p in $(port_list); do printf '  - listen: 0.0.0.0:%s\n    remote: 127.0.0.1:%s\n' "$p" "$p"; done
      echo "udpForwarding:"; for p in $(port_list); do printf '  - listen: 0.0.0.0:%s\n    remote: 127.0.0.1:%s\n    timeout: 60s\n' "$p" "$p"; done; } >"$f"; echo "  exec hysteria client -c $f ;;"; fi
  chmod 600 "$f"; echo 'esac'; }
gen_xray(){ local f=$CFG/$NAME.json k=${TYPE#xray-} proto net m="" st h u ss sc ins="" p first=1
  h=$(printf %s "$TOKEN" | md5sum | cut -c1-32); u="${h:0:8}-${h:8:4}-${h:12:4}-${h:16:4}-${h:20:12}"
  case $k in vmess-*) proto=vmess; net=${k#vmess-};; vless-*) proto=vless; net=${k#vless-};; ss-aes128) proto=shadowsocks; m=aes-128-gcm;; ss-aes256) proto=shadowsocks; m=aes-256-gcm;; ss-chacha) proto=shadowsocks; m=chacha20-ietf-poly1305;; esac
  case ${net:-tcp} in ws) st='{"network":"ws","wsSettings":{"path":"/emad"}}';; grpc) st='{"network":"grpc","grpcSettings":{"serviceName":"emad"}}';;
    httpupgrade) st='{"network":"httpupgrade","httpupgradeSettings":{"path":"/emad"}}';; kcp) st='{"network":"kcp","kcpSettings":{"seed":"'$TOKEN'"}}';; *) st='{"network":"tcp"}';; esac
  [ "$proto" = shadowsocks ] && st='{"network":"tcp"}'
  echo 'case $1 in start)'
  if [ "$ROLE" = foreign ]; then
    case $proto in vmess) ss='{"clients":[{"id":"'$u'"}]}';; vless) ss='{"clients":[{"id":"'$u'"}],"decryption":"none"}';; *) ss='{"method":"'$m'","password":"'$TOKEN'","network":"tcp,udp"}';; esac
    printf '{"log":{"loglevel":"warning"},"inbounds":[{"listen":"0.0.0.0","port":%s,"protocol":"%s","settings":%s,"streamSettings":%s}],"outbounds":[{"protocol":"freedom"}]}\n' "$CPORT" "$proto" "$ss" "$st" >"$f"
  else
    case $proto in vmess) sc='{"vnext":[{"address":"'$REMOTE'","port":'$CPORT',"users":[{"id":"'$u'","security":"auto"}]}]}';; vless) sc='{"vnext":[{"address":"'$REMOTE'","port":'$CPORT',"users":[{"id":"'$u'","encryption":"none"}]}]}';;
      *) sc='{"servers":[{"address":"'$REMOTE'","port":'$CPORT',"method":"'$m'","password":"'$TOKEN'"}]}';; esac
    for p in $(port_list); do ins+="${first/1/}"; [ $first = 0 ] && ins+=","; first=0; ins+='{"tag":"d'$p'","listen":"0.0.0.0","port":'$p',"protocol":"dokodemo-door","settings":{"address":"127.0.0.1","port":'$p',"network":"tcp,udp"}}'; done
    printf '{"log":{"loglevel":"warning"},"inbounds":[%s],"outbounds":[{"protocol":"%s","settings":%s,"streamSettings":%s}]}\n' "$ins" "$proto" "$sc" "$st" >"$f"
  fi
  chmod 600 "$f"; echo "  exec xray run -c $f ;;"; echo 'esac'; }

gen_run(){ local f=$RUN/$NAME.sh; SVC=simple
  { echo '#!/bin/bash'; echo "# Em4dloverS tunnel: $NAME ($TYPE, $ROLE)"
    case $TYPE in gre|gretap|ipip|vxlan|geneve|gre6|gre6tap|ipip6|*-fou|*-gue|wg|wg-psk|wg-1280|dnat) SVC=oneshot; gen_kernel;; gost-*|gosts-*) gen_gost;; rathole) gen_rathole;;
      backhaul-*) gen_backhaul;; frp-*) gen_frp;; chisel|chisel-tls) gen_chisel;; socat-*) gen_socat;; haproxy) gen_haproxy;; hy2|hy2-obfs) gen_hysteria;; xray-*) gen_xray;; esac; } >"$f"
  chmod 700 "$f"; }
write_unit(){ local u="$UNITDIR/emad-$NAME.service"; mkdir -p "$UNITDIR"
  { printf '[Unit]\nDescription=Em4dloverS tunnel %s (%s)\nAfter=network-online.target\nWants=network-online.target\n\n[Service]\nType=%s\n' "$NAME" "$TYPE" "$SVC"
    [ "$SVC" = oneshot ] && printf 'RemainAfterExit=yes\nExecStop=%s stop\n' "$RUN/$NAME.sh" || printf 'Restart=always\nRestartSec=3\n'
    printf 'ExecStart=%s start\nLimitNOFILE=1048576\n\n[Install]\nWantedBy=multi-user.target\n' "$RUN/$NAME.sh"; } >"$u"; }

# ---------- tunnels ----------
next_idx(){ local i; for i in $(seq 1 250); do grep -qs "^IDX=$i\$" "$TUN"/*.conf || { echo $i; return; }; done; }
check_fields(){ local e; e=$(engine_of "$TYPE")
  [[ $NAME =~ ^[a-z0-9_-]{1,24}$ ]] || { echo "ERR bad name"; return 1; }
  echo "$CATALOG" | cut -d'|' -f1 | grep -qx "$TYPE" && [ -n "$e" ] || { echo "ERR bad type"; return 1; }
  [ -n "$PORTS" ] || PORTS=1; valid_ports "$PORTS" || { echo "ERR bad ports"; return 1; }
  [[ -z ${PEER:-} || $PEER =~ ^[A-Za-z0-9+/]{43}=$ ]] || { echo "ERR bad peer key"; return 1; }
  [[ $ROLE =~ ^(iran|foreign)$ ]] || { echo "ERR bad role"; return 1; }
  [[ $REMOTE =~ ^[0-9a-fA-F:.]+$ && $LOCAL =~ ^[0-9a-fA-F:.]+$ ]] || { echo "ERR bad ip"; return 1; }
  [[ ${CPORT:-0} =~ ^[0-9]+$ && $IDX =~ ^[0-9]+$ ]] && [ "$IDX" -ge 1 ] && [ "$IDX" -le 250 ] || { echo "ERR bad idx/port"; return 1; }
  [[ ${TOKEN:-x} =~ ^[A-Za-z0-9]+$ ]] || { echo "ERR bad token"; return 1; }
  if [ "$ROLE" = iran ] || [[ $TYPE =~ ^(rathole|frp-.*|chisel)$ ]]; then
    local sp; sp=$(ssh_port); [ -n "$sp" ] && port_list | grep -qx "$sp" && { echo "ERR port $sp is your SSH port"; return 1; }
    [ "$(port_list | wc -l)" -le 1000 ] || { echo "ERR max 1000 ports"; return 1; }; fi; return 0; }
write_conf(){ printf 'NAME=%s\nTYPE=%s\nROLE=%s\nLOCAL=%s\nREMOTE=%s\nPORTS=%s\nCPORT=%s\nTOKEN=%s\nIDX=%s\nPEER=%s\n' \
    "$NAME" "$TYPE" "$ROLE" "$LOCAL" "$REMOTE" "$PORTS" "${CPORT:-}" "${TOKEN:-}" "$IDX" "${PEER:-}" >"$TUN/$NAME.conf"; chmod 600 "$TUN/$NAME.conf"; }
create_tunnel(){ local e; e=$(engine_of "$TYPE"); check_fields || return 1
  [ -f "$TUN/$NAME.conf" ] && { echo "ERR name exists"; return 1; }
  mkdir -p "$TUN" "$RUN" "$CFG" "$CONF/keys"; chmod 700 "$CONF"
  if [ -z "${EMAD_NOSYS:-}" ]; then command -v "$( [ $e = kernel ] && echo ip || echo "$e" )" >/dev/null 2>&1 || install_engine "$e" >/dev/null 2>&1; fi
  if [ "$TYPE" = wg ] && [ ! -f "$CONF/keys/$NAME.key" ]; then
    if [ -n "${EMAD_NOSYS:-}" ]; then echo k >"$CONF/keys/$NAME.key"; echo pub >"$CONF/keys/$NAME.pub"
    else (umask 077; wg genkey >"$CONF/keys/$NAME.key"); wg pubkey <"$CONF/keys/$NAME.key" >"$CONF/keys/$NAME.pub"; fi; fi
  write_conf; gen_run; write_unit; sysd daemon-reload; sysd enable "emad-$NAME" >/dev/null 2>&1; fw_open
  if [ "$TYPE" = wg ] && [ -z "${PEER:-}" ]; then echo "OK pending-peer"; else sysd restart "emad-$NAME" && echo OK || echo "ERR service failed to start"; fi; }
edit_tunnel(){ local n=$1 kv k v; shift; [[ $n =~ ^[a-z0-9_-]+$ && -f "$TUN/$n.conf" ]] || { echo "ERR no such tunnel"; return 1; }
  load "$n"
  for kv in "$@"; do k=${kv%%=*}; v=${kv#*=}; case $k in local) LOCAL=$v;; remote) REMOTE=$v;; ports) PORTS=$v;; cport) CPORT=$v;; token) TOKEN=$v;; peer) PEER=$v;; esac; done
  check_fields || return 1
  sysd stop "emad-$n" >/dev/null 2>&1                      # old script removes the old firewall rules
  write_conf; gen_run; write_unit; sysd daemon-reload; fw_open
  sysd restart "emad-$n" && echo OK || echo "ERR service failed to start"; }
load(){ NAME=$1; PEER=; . "$TUN/$1.conf" 2>/dev/null; }
act(){ [[ $2 =~ ^[a-z0-9_-]+$ && -f "$TUN/$2.conf" ]] || { echo "ERR no such tunnel"; return 1; }
  case $1 in start|stop|restart) sysd "$1" "emad-$2" && echo OK || echo ERR;;
   delete) full_delete "$2"; echo OK;;
   *) echo ERR;; esac; }
list_tunnels(){ local f; for f in "$TUN"/*.conf; do [ -f "$f" ] || continue; ( . "$f"; printf '%s|%s|%s|%s|%s|%s\n' "$NAME" "$TYPE" "$ROLE" "$REMOTE" "$PORTS" "$(sysd is-active "emad-$NAME" 2>/dev/null || echo unknown)" ); done; }

# ---------- compatibility status ----------
GH_OK=0; APT_OK=0
score_of(){ local t=$1 s=0 e mod=""; e=$(engine_of "$t")
  case $(uname -m) in x86_64|aarch64) s=$((s+1));; esac
  case $e in kernel|wg)
    case $(systemd-detect-virt -c 2>/dev/null) in openvz|lxc*|docker) ;; *) s=$((s+1));; esac
    case $t in gre|gretap) mod=ip_gre;; ipip) mod=ipip;; vxlan) mod=vxlan;; gre6) mod=ip6_gre;; ipip6) mod=ip6_tunnel;; wg) mod=wireguard;; dnat) mod=iptable_nat;; esac
    { modinfo "$mod" >/dev/null 2>&1 || grep -qw "$mod" "/lib/modules/$(uname -r)/modules.builtin" 2>/dev/null; } && s=$((s+1))
    [ $APT_OK = 1 ] || command -v iptables >/dev/null && s=$((s+1));;
   socat|haproxy) s=$((s+2)); [ $APT_OK = 1 ] || command -v "$e" >/dev/null && s=$((s+1));;
   *) s=$((s+1)); command -v "$e" >/dev/null || command -v "${e/frp/frpc}" >/dev/null && s=$((s+1)); [ $GH_OK = 1 ] && s=$((s+1));; esac
  echo $s; }
net_probe(){ curl -fsS -m 5 -o /dev/null https://api.github.com && GH_OK=1; getent hosts archive.ubuntu.com >/dev/null || getent hosts deb.debian.org >/dev/null && APT_OK=1; }
status_table(){ local t n d s c; [ -n "${EMAD_DEMO:-}" ] || net_probe; [ -n "${EMAD_DEMO:-}" ] && { GH_OK=1; APT_OK=1; }
  while IFS='|' read -r t n d; do s=$(score_of "$t")
    [ "${1:-}" = machine ] && { echo "$t|$n|$s"; continue; }
    c=$R; [ "$s" -ge 3 ] && c=$Y; [ "$s" -eq 4 ] && c=$G
    printf '   %-18s %s%d/4%s  %s[%s%s]%s\n' "$n" "$c" "$s" "$N" "$c" "$(printf '%.0s#' $(seq 1 $s))" "$(printf '%.0s.' $(seq 1 $((4-s))))" "$N"
  done <<<"$CATALOG"; }

# ---------- optimizer ----------
optimize(){ cat >"$ROOT/etc/sysctl.d/99-emadlovers.conf" <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_mtu_probing=1
net.ipv4.ip_forward=1
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 262144 67108864
net.ipv4.tcp_wmem=4096 262144 67108864
net.core.somaxconn=65535
net.core.netdev_max_backlog=16384
net.ipv4.tcp_max_syn_backlog=16384
EOF
  modprobe tcp_bbr 2>/dev/null; sysctl --system >/dev/null; }

tune_all(){ optimize; local f n t i
  for f in "$TUN"/*.conf; do [ -f "$f" ] || continue; ( . "$f"; case $TYPE in gre|gretap|ipip|vxlan|geneve|gre6|gre6tap|ipip6|*-fou|*-gue|wg*) ip link set "emad$IDX" mtu $([[ $TYPE == vxlan || $TYPE == geneve || $TYPE == gre6* || $TYPE == *-fou || $TYPE == *-gue || $TYPE == wg* ]] && echo 1380 || echo 1400) 2>/dev/null;; esac ); done
  echo "OK BBR, buffers and MTU applied"; }
# ---------- temporary guide site (30 min, random 5-digit port, auto-removed) ----------
guide_make(){ local n=$1 TTL=${EMAD_GUIDE_TTL:-1800} port dir html ip; load "$n"; [ -n "$TYPE" ] || { echo "ERR no such tunnel"; return 1; }
  myip; ip=${MYIP:-127.0.0.1}; port=$(rand_port); dir=/tmp/emad-guide-$port; mkdir -p "$dir"
  local role_title role_steps type_label=$(type_name "$TYPE")
  if [ "$ROLE" = foreign ]; then role_title="Foreign server (exit)"
    role_steps="<li>Open the menu with <code>emad</code>, then choose <b>2 Create tunnel</b>.</li><li>Role: <b>Foreign</b>. No ports are needed on this side.</li><li>Type: <b>$type_label</b>.</li><li>Tunnel ID: <b>$IDX</b>, control port: <b>${CPORT:-not needed}</b>, token: <b>${TOKEN:-not needed}</b>.</li><li>Other server IP: <b>$LOCAL</b> (the Iran server).</li>"
  else role_title="Iran server (entry)"
    role_steps="<li>Open the menu with <code>emad</code>, then choose <b>2 Create tunnel</b>.</li><li>Role: <b>Iran</b>.</li><li>Type: <b>$type_label</b>.</li><li>Tunnel ID: <b>$IDX</b>, control port: <b>${CPORT:-not needed}</b>, token: <b>${TOKEN:-not needed}</b>.</li><li>Ports to forward: <b>$PORTS</b>.</li><li>Other server IP: <b>$REMOTE</b> (the foreign server).</li>"
  fi
  cat >"$dir/index.html" <<HTML
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Em4dloverS guide: $NAME</title>
<style>
:root{--w:#fff;--k:#000;--r:#e1131f;--g:#f4f4f2}
*{box-sizing:border-box}body{margin:0;font:16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:var(--k);color:var(--w)}
header{padding:38px 24px 26px;border-bottom:2px solid var(--r);background:linear-gradient(120deg,#000 60%,#1a0000)}
header h1{margin:0;font:600 34px/1.1 Georgia,"Times New Roman",serif}header h1 em{color:var(--r);font-style:normal}
header p{margin:8px 0 0;color:#bdbdb8}.warn{display:inline-block;margin-top:14px;padding:6px 12px;border:1px solid var(--r);border-radius:99px;color:#ff8a90;font-size:14px}
main{max-width:820px;margin:0 auto;padding:26px 22px 60px}
.card{background:var(--w);color:var(--k);border-radius:16px;padding:22px 24px;margin:0 0 18px;box-shadow:0 14px 40px #0008}
.card h2{margin:0 0 10px;font-size:20px}.card ol{padding-left:22px;margin:0}.card li{margin:6px 0}
code{background:var(--g);padding:2px 7px;border-radius:6px;font-size:14px}.red{color:var(--r)}
.kv{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:10px;margin:12px 0 0}
.kv div{border-left:3px solid var(--r);padding:4px 10px;background:var(--g);border-radius:0 8px 8px 0;color:var(--k)}.kv small{display:block;color:#666}
.step{display:flex;gap:14px;align-items:flex-start}.num{flex:none;width:34px;height:34px;border-radius:50%;background:var(--r);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700}
footer{text-align:center;color:#8f8f8b;font-size:14px;padding:20px}footer a{color:#fff}
</style></head><body>
<header><h1 class="serif">Em4d<em>loverS</em> Tunnel</h1><p>Setup guide for tunnel <b>$NAME</b> ($type_label)</p>
<span class="warn">This page closes automatically in 30 minutes and is then deleted.</span></header>
<main>
<div class="card"><h2>Your tunnel</h2><div class="kv">
<div><small>Name</small><b>$NAME</b></div><div><small>Type</small><b>$type_label</b></div><div><small>This server</small><b>$role_title</b></div>
<div><small>Tunnel ID</small><b>$IDX</b></div><div><small>Other server</small><b>${REMOTE:-$LOCAL}</b></div><div><small>Ports</small><b>${PORTS:-1}</b></div></div></div>
<div class="card"><h2>Step 1: Install the menu on both servers</h2><ol><li>Log in as <code>root</code>.</li><li>Run: <code>bash &lt;(curl -Ls https://raw.githubusercontent.com/emdabsii/Em4dloverS-Tunnel/main/install.sh)</code></li><li>Wait until the menu opens.</li></ol></div>
<div class="card"><h2>Step 2: Create the tunnel on $role_title</h2><ol>$role_steps</ol></div>
<div class="card"><h2>Step 3: Use the same values on the other server</h2><p>Tunnel ID, control port and token must match exactly on both servers. The type must be the same too.</p></div>
<div class="card"><h2>Step 4: Check it works</h2><ol><li>Open the web panel and select the tunnel.</li><li>Press <b>Check now</b>. A green state means the two servers are connected.</li><li>If it stays red, check that the control port and ports are open in your provider firewall.</li></ol></div>
<div class="card"><h2>Need help?</h2><p>Channel: <a class="red" href="https://t.me/Em4dloverS">t.me/Em4dloverS</a><br>Support: <a class="red" href="https://t.me/KaMr4ng">t.me/KaMr4ng</a></p></div>
</main><footer>Em4dloverS Tunnel  |  t.me/Em4dloverS</footer></body></html>
HTML
  ( setsid timeout "$TTL" python3 -m http.server "$port" --bind 0.0.0.0 --directory "$dir" >/dev/null 2>&1; rm -rf "$dir" ) </dev/null >/dev/null 2>&1 &
  command -v ufw >/dev/null && ufw allow "$port/tcp" >/dev/null 2>&1
  sleep 1; echo "http://$ip:$port/"; }

full_delete(){ local n=$1 f ip i
  load "$n" 2>/dev/null || true
  sysd disable --now "emad-$n" >/dev/null 2>&1; sysd stop "emad-$n" >/dev/null 2>&1
  [ -f "$RUN/$n.sh" ] && bash "$RUN/$n.sh" stop >/dev/null 2>&1          # removes firewall rules and the interface
  if command -v ufw >/dev/null && [ -n "${CPORT:-}" ] && [ "${CPORT:-0}" != 0 ]; then ufw delete allow "$CPORT" >/dev/null 2>&1; fi
  i="emad${IDX:-x}"; ip link del "$i" 2>/dev/null
  rm -f "$UNITDIR/emad-$n.service" "$TUN/$n.conf" "$RUN/$n.sh" "$CFG/$n".* "$CONF/keys/$n".*
  rm -rf /tmp/emad-guide-* 2>/dev/null
  sysd daemon-reload >/dev/null 2>&1; return 0; }

# ---------- setup link (em4d://) ----------
# The Iran side makes a link; the foreign side pastes it. The link carries
# only what the other side needs: name, type, both IPs, tunnel ID, control port and token.
make_link(){ load "$1"; [ -n "$TYPE" ] && [ "$ROLE" = iran ] || { echo "ERR only Iran-side tunnels can make a link"; return 1; }
  local j; j=$(python3 -c 'import json,sys;print(json.dumps({"n":sys.argv[1],"t":sys.argv[2],"l":sys.argv[3],"r":sys.argv[4],"i":int(sys.argv[5]),"c":int(sys.argv[6] or 0),"k":sys.argv[7]}))' "$NAME" "$TYPE" "$REMOTE" "$LOCAL" "$IDX" "${CPORT:-0}" "${TOKEN:-}")
  echo "em4d://$(printf %s "$j" | base64 -w0)"; }
apply_link(){ local raw=$1 j; raw=${raw#em4d://}; raw=${raw//[[:space:]]/}
  j=$(printf %s "$raw" | base64 -d 2>/dev/null) || { echo "ERR bad link"; return 1; }
  eval "$(printf %s "$j" | python3 -c 'import json,sys,shlex
d=json.load(sys.stdin)
for k,v in {"NAME":d["n"],"TYPE":d["t"],"LOCAL":d["l"],"REMOTE":d["r"],"IDX":d["i"],"CPORT":d["c"],"TOKEN":d["k"]}.items(): print(k+"="+shlex.quote(str(v)))' 2>/dev/null)" || { echo "ERR bad link"; return 1; }
  ROLE=foreign; PORTS=1; PEER=""; create_tunnel; }

# ---------- web panel ----------
panel_cfg(){ python3 "$APP/panel/app.py" set "$@"; }
panel_url(){ python3 "$APP/panel/app.py" url "$MYIP"; }
panel_state(){ systemctl is-active emad-panel 2>/dev/null || echo inactive; }
panel_install(){ hdr "Install web panel"
  [ -f "$APP/panel/app.py" ] || { printf '  %s[!]%s File missing: %s/panel/app.py\n  Re-run the installer from GitHub.\n' "$R" "$N" "$APP"; return; }
  local fresh=1 port pass; [ -f "$CONF/panel.json" ] && fresh=0
  STEPS=(); DONEN=0; TOTAL=4
  step "Installing Python and Flask" apt_i python3 python3-flask curl
  if [ $fresh = 1 ]; then port=$(rand_port); pass=$(rand_str 12); step "Creating panel configuration" panel_cfg "port=$port" "user=admin" "pass=$pass"
  else port=$(python3 "$APP/panel/app.py" get port); step "Keeping existing configuration" true; fi
  printf '[Unit]\nDescription=Em4dloverS Panel\nAfter=network-online.target\n\n[Service]\nExecStart=/usr/bin/python3 %s/panel/app.py run\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n' "$APP" >"$UNITDIR/emad-panel.service"
  step "Writing service file" true
  step "Starting panel service" bash -c "systemctl daemon-reload && systemctl enable emad-panel && systemctl restart emad-panel"
  command -v ufw >/dev/null && ufw allow "$port/tcp" >/dev/null 2>&1; summary
  [ "$(panel_state)" = active ] || { printf '\n  %s[!]%s Panel failed to start. See: journalctl -u emad-panel -n 30\n' "$R" "$N"; return; }
  if [ $fresh = 1 ]; then printf '\n  %sPanel is ready.%s\n  Address : %s%s%s\n  Username: %sadmin%s\n  Password: %s%s%s\n' "$G" "$N" "$W" "$(panel_url)" "$N" "$W" "$N" "$W" "$pass" "$N"
  else printf '\n  %sPanel repaired. Login unchanged.%s  Address: %s%s%s\n' "$G" "$N" "$W" "$(panel_url)" "$N"; fi; }
panel_menu(){ [ -f "$CONF/panel.json" ] || { panel_install; return; }
  while :; do local st c=$R; st=$(panel_state); [ "$st" = active ] && c=$G; myip; hdr "Web panel"
    printf '  Status   : %s%s%s\n  Address  : %s%s%s\n  Username : %s%s%s\n  Password : %shidden (use 4 or 5 to set a new one)%s\n\n' "$c" "$st" "$N" "$W" "$(panel_url)" "$N" "$W" "$(python3 "$APP/panel/app.py" get user)" "$N" "$D" "$N"
    printf '  %s[1]%s Restart   %s[2]%s Stop   %s[3]%s Start   %s[4]%s Change username/password\n  %s[5]%s New random password   %s[6]%s Change port   %s[7]%s Repair   %s[8]%s Uninstall   %s[0]%s Back\n\n' $R $N $R $N $R $N $R $N $R $N $R $N $R $N $R $N $R $N
    ask "Select" 0; case $REPLY in 1) systemctl restart emad-panel;; 2) systemctl stop emad-panel;; 3) systemctl start emad-panel;; 4) panel_reset; pause;;
      5) local p; p=$(rand_str 12); panel_cfg "pass=$p" && systemctl restart emad-panel; printf '\n  New password: %s%s%s\n' "$W" "$p" "$N"; pause;;
      6) ask "New port (Enter = random free)"; local np=${REPLY:-$(rand_port)}; [[ $np =~ ^[0-9]{2,5}$ ]] && port_free "$np" && panel_cfg "port=$np" && { command -v ufw >/dev/null && ufw allow "$np/tcp" >/dev/null 2>&1; systemctl restart emad-panel; echo "  Port is now $np"; } || echo "  Port invalid or busy."; pause;;
      7) panel_install; pause;; 8) ask "Type YES to uninstall the panel" no; [ "$REPLY" = YES ] && { systemctl disable --now emad-panel; rm -f "$UNITDIR/emad-panel.service" "$CONF/panel.json"; systemctl daemon-reload; echo "  Panel removed."; pause; return; };;
      *) return;; esac; done; }
panel_ssl(){ hdr "Panel SSL (Let's Encrypt)"; [ -f "$CONF/panel.json" ] || { echo "  Install the panel first."; return; }
  ask "Domain (must point to $MYIP)"; local d=$REPLY; ask "Email for Let's Encrypt"; local m=$REPLY
  [[ $d =~ ^[A-Za-z0-9.-]+$ && $m =~ ^[^@\ ]+@[^@\ ]+$ ]] || { echo "  Invalid domain or email."; return; }
  getent hosts "$d" | grep -q "$MYIP" || echo "  ${Y}Warning:${N} $d does not resolve to $MYIP yet."
  STEPS=(); DONEN=0; TOTAL=3
  step "Installing certbot" apt_i certbot
  step "Requesting certificate (port 80 must be free)" certbot certonly --standalone -d "$d" -m "$m" --agree-tos -n --deploy-hook "systemctl restart emad-panel"
  step "Applying certificate to panel" bash -c "python3 $APP/panel/app.py set domain=$d cert=/etc/letsencrypt/live/$d/fullchain.pem key=/etc/letsencrypt/live/$d/privkey.pem && systemctl restart emad-panel"
  printf '\n  New panel address: %s%s%s\n' "$W" "$(panel_url)" "$N"; }
panel_reset(){ hdr "Reset panel login"; [ -f "$CONF/panel.json" ] || { echo "  Install the panel first."; return; }
  ask "New username" admin; local u=$REPLY; ask "New password (Enter = random)"; local p=${REPLY:-$(rand_str 12)}
  [[ $u =~ ^[A-Za-z0-9_.-]{3,32}$ && $p =~ ^[A-Za-z0-9_.@#%+=-]{6,64}$ ]] || { echo "  Invalid username or password format."; return; }
  panel_cfg "user=$u" "pass=$p" && systemctl restart emad-panel; printf '\n  Username: %s%s%s\n  Password: %s%s%s\n' "$W" "$u" "$N" "$W" "$p" "$N"; }

# ---------- interactive ----------
pick_type(){ local i=0 t n d; hdr "Choose tunnel type"
  while IFS='|' read -r t n d; do i=$((i+1)); printf '  %s%2d%s  %-18s %s%s%s\n' "$R" "$i" "$N" "$n" "$D" "$d" "$N"; done <<<"$CATALOG"
  ask "Number" 1; TYPE=$(echo "$CATALOG" | sed -n "${REPLY}p" | cut -d'|' -f1); [ -n "$TYPE" ]; }
wizard(){ local again=y; while [ "$again" = y ]; do
  pick_type || { echo "  Invalid choice."; return; }; local e; e=$(engine_of "$TYPE"); hdr "Create: $(type_name "$TYPE")"
  ask "Tunnel name (a-z 0-9 - _)" "t$(next_idx)"; NAME=$REPLY
  printf '  This server is:  %s1%s Iran (entry)   %s2%s Foreign (exit)\n' "$R" "$N" "$R" "$N"; ask "Role" 1; [ "$REPLY" = 2 ] && ROLE=foreign || ROLE=iran
  myip; ask "This server public IP" "$MYIP"; LOCAL=$REPLY; ask "Other server IP"; REMOTE=$REPLY
  ask "Tunnel ID 1-250 (use the SAME on both servers)" "$(next_idx)"; IDX=$REPLY; PORTS=""; CPORT=""; TOKEN=""
  if [ "$ROLE" = iran ] || [[ $TYPE =~ $REVERSE_RX ]]; then ask "Ports (e.g. 80,443,2000-2100)" "443"; PORTS=$REPLY; else PORTS=1; fi
  if [[ $e =~ ^(gost|rathole|backhaul|frp|chisel)$ ]]; then ask "Control port (same on both servers)" "$((33000+IDX))"; CPORT=$REPLY
    ask "Token (same on both servers, Enter = new)"; TOKEN=${REPLY:-$(rand_str 16)}; printf '  Token: %s%s%s\n' "$W" "$TOKEN" "$N"; fi
  PEER=""; if [ "$TYPE" = wg ]; then echo "  WireGuard needs the other side's public key."
    ask "Peer public key (Enter = create keys now, set it later)"; PEER=$REPLY; fi
  echo; install_engine "$e"; local out; out=$(create_tunnel); printf '\n  Result: %s%s%s\n' "$W" "$out" "$N"
  [ "$TYPE" = wg ] && printf '  Your public key: %s%s%s\n' "$W" "$(cat "$CONF/keys/$NAME.pub" 2>/dev/null)" "$N"
  ask "Add another tunnel / server? (y/n)" n; again=$REPLY; done; }
edit_menu(){ load "$1"; hdr "Edit $1  ($TYPE, $ROLE)"; local a=()
  ask "Other server IP" "$REMOTE"; [ "$REPLY" != "$REMOTE" ] && a+=("remote=$REPLY")
  ask "This server IP" "$LOCAL"; [ "$REPLY" != "$LOCAL" ] && a+=("local=$REPLY")
  if [ "$PORTS" != 1 ]; then ask "Ports (add or remove, e.g. 80,443,2000-2100)" "$PORTS"; [ "$REPLY" != "$PORTS" ] && a+=("ports=$REPLY"); fi
  if [ -n "$CPORT" ]; then ask "Control port" "$CPORT"; [ "$REPLY" != "$CPORT" ] && a+=("cport=$REPLY"); ask "Token" "$TOKEN"; [ "$REPLY" != "$TOKEN" ] && a+=("token=$REPLY"); fi
  [ ${#a[@]} -eq 0 ] && { echo "  Nothing changed."; return; }
  printf '  Result: %s%s%s\n  %sRemember to apply the same IP, port, control port and token changes on the other server.%s\n' "$W" "$(edit_tunnel "$1" "${a[@]}")" "$N" "$D" "$N"; }
manage(){ while :; do hdr "Tunnels"; local i=0 line names=()
  while IFS='|' read -r n t r rem p s; do [ -n "$n" ] || continue; i=$((i+1)); names+=("$n"); local c=$R; [ "$s" = active ] && c=$G
    printf '  %s%2d%s  %-14s %-16s %-8s %s -> %s  %s%s%s\n' "$R" "$i" "$N" "$n" "$(type_name "$t")" "$r" "${p:0:18}" "$rem" "$c" "$s" "$N"; done < <(list_tunnels)
  [ $i -eq 0 ] && { echo "  No tunnels yet."; pause; return; }
  ask "Select number (0 = back)" 0; [ "$REPLY" = 0 ] && return; local n=${names[$((REPLY-1))]:-}; [ -n "$n" ] || continue
  printf '  %ss%s start  %sx%s stop  %sr%s restart  %se%s edit  %sg%s setup guide  %sl%s logs  %sk%s WG key  %sd%s delete\n' "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N"
  ask "Action"; case $REPLY in s) act start "$n";; x) act stop "$n";; r) act restart "$n";; d) ask "Type YES to delete" no; [ "$REPLY" = YES ] && act delete "$n";;
   e) edit_menu "$n"; pause;;
   g) hdr "Setup guide"; echo "  Open this link in your browser (closes after 30 minutes):"; echo "  $(guide_make "$n")"; pause;;
   l) journalctl -u "emad-$n" -n 40 --no-pager; pause;;
   k) load "$n"; ask "Peer public key"; sed -i "s|^PEER=.*|PEER=$REPLY|" "$TUN/$n.conf"; load "$n"; gen_run; sysd restart "emad-$n" && echo "  Done.";; esac; done; }
install_menu(){ hdr "Install requirements"; local e i=0 list=(kernel wg socat haproxy gost rathole backhaul frp chisel hysteria xray all)
  for e in "${list[@]}"; do i=$((i+1)); printf '  %s%2d%s  %s\n' "$R" "$i" "$N" "$e"; done; ask "Number" 12; e=${list[$((REPLY-1))]:-}; [ -n "$e" ] || return
  if [ "$e" = all ]; then for e in "${list[@]:0:11}"; do hdr "Installing: $e"; install_engine "$e"; done; else install_engine "$e"; fi; }
support(){ hdr "Contact"; printf '  Channel : %st.me/Em4dloverS%s\n  Support : %st.me/KaMr4ng%s\n' "$W" "$N" "$D" "$N"; }
menu(){ while :; do banner
  printf '\n  %s[1]%s Install requirements        %s[6]%s Web panel (status/manage)\n  %s[2]%s Create tunnel (wizard)       %s[7]%s Panel SSL (domain)\n  %s[3]%s Manage tunnels               %s[8]%s Reset panel login\n  %s[4]%s Tunnel Status (this server)  %s[9]%s Contact / Telegram\n  %s[5]%s Optimize network (BBR)       %s[0]%s Exit\n\n' \
    $R $N $R $N $R $N $R $N $R $N $R $N $R $N $R $N $R $N $R $N
  ask "Select"; case $REPLY in 1) install_menu;; 2) wizard;; 3) manage; continue;; 4) hdr "Tunnel Status"; status_table;; 5) hdr "Optimizer"; optimize && echo "  BBR, fq and buffers applied.";;
    6) panel_menu; continue;; 7) panel_ssl;; 8) panel_reset;; 9) support;; 0) printf '\n  %sBye. t.me/Em4dloverS%s\n\n' "$R" "$N"; exit 0;; *) continue;; esac; pause; done; }

# ---------- entry ----------
if [ "${1:-}" = api ]; then shift; need_root; case ${1:-} in
  catalog) echo "$CATALOG";; list) list_tunnels;; status) status_table machine;; ip) myip; echo "$MYIP";; act) act "$2" "$3";;
  edit) shift; edit_tunnel "$@";;
  tune) tune_all;;
  link) make_link "$2";;
  apply-link) apply_link "$2";;
  guide) guide_make "$2";;
  create) NAME=$2 TYPE=$3 ROLE=$4 LOCAL=$5 REMOTE=$6 PORTS=$7 CPORT=$8 TOKEN=$9 IDX=${10} PEER=${11:-}; create_tunnel;; esac; exit 0; fi
need_root; detect_os; mkdir -p "$TUN" "$RUN" "$CFG" "$CONF/keys" "$ROOT/etc/sysctl.d" 2>/dev/null; menu
