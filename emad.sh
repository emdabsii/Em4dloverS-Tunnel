#!/usr/bin/env bash
# Em4dloverS Tunnel Manager  |  t.me/Em4dloverS  |  support: t.me/kamr4
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
CATALOG='gre|GRE|Kernel L3 tunnel, lowest latency
gretap|GRE-TAP|Kernel L2 tunnel over GRE
ipip|IPIP|Lightest kernel tunnel (one per IP pair)
vxlan|VXLAN|Kernel UDP-encapsulated L2 tunnel
gre6|GRE6 (ip6gre)|GRE over IPv6 endpoints
ipip6|IPIP6 (ip6tnl)|IPv4-in-IPv6 kernel tunnel
wg|WireGuard|Encrypted UDP tunnel, fast and modern
dnat|Direct DNAT|iptables port forward (no encryption)
socat-tcp|Socat TCP|Simple TCP relay
socat-udp|Socat UDP|Simple UDP relay
haproxy|HAProxy TCP|L4 forward, port ranges
gost-tcp|GOST relay|GOST relay over plain TCP
gost-tls|GOST relay+TLS|GOST relay over TLS
gost-mtls|GOST relay+MTLS|GOST relay over multiplexed TLS
gost-ws|GOST relay+WS|GOST relay over WebSocket
gost-mws|GOST relay+MWS|GOST relay over multiplexed WS
gost-wss|GOST relay+WSS|GOST relay over secure WebSocket
gost-mwss|GOST relay+MWSS|GOST relay over multiplexed WSS
gost-h2|GOST relay+H2|GOST relay over HTTP/2 TLS
gost-h2c|GOST relay+H2C|GOST relay over HTTP/2 cleartext
gost-quic|GOST relay+QUIC|GOST relay over QUIC
gost-kcp|GOST relay+KCP|GOST relay over KCP (UDP, lossy links)
gost-grpc|GOST relay+gRPC|GOST relay over gRPC
rathole|Rathole TCP|Reverse tunnel, Rust, very fast
backhaul-tcp|Backhaul TCP|Reverse tunnel, TCP
backhaul-tcpmux|Backhaul TCPMux|Reverse tunnel, multiplexed TCP
backhaul-udp|Backhaul UDP|Reverse tunnel, UDP transport
backhaul-ws|Backhaul WS|Reverse tunnel, WebSocket
backhaul-wsmux|Backhaul WSMux|Reverse tunnel, multiplexed WS
frp-tcp|FRP TCP|Reverse proxy, TCP
frp-kcp|FRP KCP|Reverse proxy, KCP
frp-quic|FRP QUIC|Reverse proxy, QUIC
frp-websocket|FRP WebSocket|Reverse proxy, WebSocket
chisel|Chisel|Reverse tunnel over HTTP/WebSocket'
REVERSE_RX='^(rathole|backhaul-.*|frp-.*|chisel)$'

engine_of(){ case $1 in gre|gretap|ipip|vxlan|gre6|ipip6|dnat) echo kernel;; wg) echo wg;; socat-*) echo socat;;
  haproxy) echo haproxy;; gost-*) echo gost;; rathole) echo rathole;; backhaul-*) echo backhaul;; frp-*) echo frp;; chisel) echo chisel;; esac; }
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
  printf '  %sChannel%s  t.me/Em4dloverS\n  %sSupport%s  %st.me/kamr4%s\n' "$R" "$N" "$R" "$N" "$D" "$N"
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
  case $url in *.zip) unzip -qo $t/pkg -d $t;; *.tar.gz) tar xzf $t/pkg -C $t;; *.gz) gunzip -c $t/pkg >$t/$1;; esac
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
  local t; for t in $(port_tokens) "$CPORT"; do [ -n "$t" ] && ufw allow "${t/-/:}" >/dev/null 2>&1; done; return 0; }

# ---------- generators (print lines of the run script) ----------
gen_kernel(){ local a=1 b=2 ifn=emad$IDX mk="" tok pr dst MTU=1400 wa
  [ "$ROLE" = foreign ] && { a=2; b=1; }
  case $TYPE in
   gre) mk="ip tunnel add $ifn mode gre local $LOCAL remote $REMOTE ttl 255";;
   gretap) mk="ip link add $ifn type gretap local $LOCAL remote $REMOTE ttl 255";;
   ipip) mk="ip tunnel add $ifn mode ipip local $LOCAL remote $REMOTE ttl 255";;
   vxlan) MTU=1380; mk="ip link add $ifn type vxlan id $IDX local $LOCAL remote $REMOTE dstport $((4789+IDX)) nolearning";;
   gre6) MTU=1380; mk="ip link add $ifn type ip6gre local $LOCAL remote $REMOTE ttl 255";;
   ipip6) MTU=1380; mk="ip link add $ifn type ip6tnl mode ipip6 local $LOCAL remote $REMOTE";;
   wg) MTU=1380; mk="ip link add $ifn type wireguard";;
  esac
  echo "sysctl -qw net.ipv4.ip_forward=1 net.ipv4.conf.all.rp_filter=0 net.ipv4.conf.default.rp_filter=0"
  echo 'rules(){ local o=$1'
  if [ "$ROLE" = iran ]; then
    dst="10.$IDX.0.2"; [ "$TYPE" = dnat ] && dst=$REMOTE
    for tok in $(port_tokens); do for pr in tcp udp; do
      echo "  iptables -t nat \$o PREROUTING -p $pr --dport ${tok/-/:} -j DNAT --to-destination $dst"; done; done
    if [ "$TYPE" = dnat ]; then echo "  iptables -t nat \$o POSTROUTING -d $REMOTE -j MASQUERADE"
    else echo "  iptables -t nat \$o POSTROUTING -o $ifn -j MASQUERADE"
         echo "  iptables -t mangle \$o FORWARD -o $ifn -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu"; fi
  fi
  echo '  :'; echo '}'; echo 'case $1 in'; echo ' start)'
  if [ "$TYPE" = dnat ]; then echo "  rules -D 2>/dev/null; rules -A ;;"; echo " stop) rules -D 2>/dev/null ;;"
  else
    echo "  ip link del $ifn 2>/dev/null; $mk || exit 1"
    if [ "$TYPE" = wg ]; then wa="private-key $CONF/keys/$NAME.key listen-port $((51800+IDX))"
      [ -n "${PEER:-}" ] && { wa+=" peer $PEER allowed-ips 10.$IDX.0.0/30"; [ "$ROLE" = iran ] && wa+=" endpoint $REMOTE:$((51800+IDX)) persistent-keepalive 15"; }
      echo "  wg set $ifn $wa"; fi
    echo "  ip addr add 10.$IDX.0.$a/30 dev $ifn; ip link set $ifn mtu $MTU up"
    echo "  command -v ufw >/dev/null && ufw allow in on $ifn >/dev/null 2>&1"
    echo "  rules -D 2>/dev/null; rules -A ;;"
    echo " stop) rules -D 2>/dev/null; ip link del $ifn 2>/dev/null ;;"
  fi; echo 'esac'; }

gen_gost(){ local t=${TYPE#gost-} sch a=""; sch="relay+$t"; [ "$t" = tcp ] && sch=relay; echo 'case $1 in start)'
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
gen_chisel(){ local a="" p; echo 'case $1 in start)'
  if [ "$ROLE" = iran ]; then echo "  exec chisel server --port $CPORT --reverse --auth emad:$TOKEN ;;"
  else for p in $(port_list); do a+=" R:0.0.0.0:$p:127.0.0.1:$p"; done
       echo "  exec chisel client --auth emad:$TOKEN --keepalive 10s http://$REMOTE:$CPORT$a ;;"; fi; echo 'esac'; }
gen_socat(){ local pr=TCP p; [ "$TYPE" = socat-udp ] && pr=UDP; echo 'case $1 in start)'
  if [ "$ROLE" = iran ]; then for p in $(port_list); do echo "  socat $pr-LISTEN:$p,fork,reuseaddr $pr:$REMOTE:$p &"; done; echo "  wait ;;"
  else echo "  exec sleep infinity ;;"; fi; echo 'esac'; }
gen_haproxy(){ local f=$CFG/$NAME.cfg t; echo 'case $1 in start)'
  if [ "$ROLE" = iran ]; then { printf 'global\n  maxconn 100000\ndefaults\n  mode tcp\n  timeout connect 5s\n  timeout client 1h\n  timeout server 1h\n  option tcpka\nfrontend f\n'
      for t in $(port_tokens); do echo "  bind *:$t"; done; printf '  default_backend b\nbackend b\n  server s1 %s\n' "$REMOTE"; } >"$f"
    echo "  exec haproxy -db -f $f ;;"; else echo "  exec sleep infinity ;;"; fi; echo 'esac'; }

gen_run(){ local f=$RUN/$NAME.sh; SVC=simple
  { echo '#!/bin/bash'; echo "# Em4dloverS tunnel: $NAME ($TYPE, $ROLE)"
    case $TYPE in gre|gretap|ipip|vxlan|gre6|ipip6|wg|dnat) SVC=oneshot; gen_kernel;; gost-*) gen_gost;; rathole) gen_rathole;;
      backhaul-*) gen_backhaul;; frp-*) gen_frp;; chisel) gen_chisel;; socat-*) gen_socat;; haproxy) gen_haproxy;; esac; } >"$f"
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
   delete) sysd disable --now "emad-$2" >/dev/null 2>&1; rm -f "$UNITDIR/emad-$2.service" "$TUN/$2.conf" "$RUN/$2.sh" "$CFG/$2".* "$CONF/keys/$2".*; sysd daemon-reload; echo OK;;
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
  printf '  %ss%s start  %sx%s stop  %sr%s restart  %se%s edit  %sl%s logs  %sk%s WG peer key  %sd%s delete\n' "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N"
  ask "Action"; case $REPLY in s) act start "$n";; x) act stop "$n";; r) act restart "$n";; d) ask "Type YES to delete" no; [ "$REPLY" = YES ] && act delete "$n";;
   e) edit_menu "$n"; pause;;
   l) journalctl -u "emad-$n" -n 40 --no-pager; pause;;
   k) load "$n"; ask "Peer public key"; sed -i "s|^PEER=.*|PEER=$REPLY|" "$TUN/$n.conf"; load "$n"; gen_run; sysd restart "emad-$n" && echo "  Done.";; esac; done; }
install_menu(){ hdr "Install requirements"; local e i=0 list=(kernel wg socat haproxy gost rathole backhaul frp chisel all)
  for e in "${list[@]}"; do i=$((i+1)); printf '  %s%2d%s  %s\n' "$R" "$i" "$N" "$e"; done; ask "Number" 10; e=${list[$((REPLY-1))]:-}; [ -n "$e" ] || return
  if [ "$e" = all ]; then for e in "${list[@]:0:9}"; do hdr "Installing: $e"; install_engine "$e"; done; else install_engine "$e"; fi; }
support(){ hdr "Contact"; printf '  Channel : %st.me/Em4dloverS%s\n  Support : %st.me/kamr4%s\n' "$W" "$N" "$D" "$N"; }
menu(){ while :; do banner
  printf '\n  %s[1]%s Install requirements        %s[6]%s Web panel (status/manage)\n  %s[2]%s Create tunnel (wizard)       %s[7]%s Panel SSL (domain)\n  %s[3]%s Manage tunnels               %s[8]%s Reset panel login\n  %s[4]%s Tunnel Status (this server)  %s[9]%s Contact / Telegram\n  %s[5]%s Optimize network (BBR)       %s[0]%s Exit\n\n' \
    $R $N $R $N $R $N $R $N $R $N $R $N $R $N $R $N $R $N $R $N
  ask "Select"; case $REPLY in 1) install_menu;; 2) wizard;; 3) manage; continue;; 4) hdr "Tunnel Status"; status_table;; 5) hdr "Optimizer"; optimize && echo "  BBR, fq and buffers applied.";;
    6) panel_menu; continue;; 7) panel_ssl;; 8) panel_reset;; 9) support;; 0) printf '\n  %sBye. t.me/Em4dloverS%s\n\n' "$R" "$N"; exit 0;; *) continue;; esac; pause; done; }

# ---------- entry ----------
if [ "${1:-}" = api ]; then shift; need_root; case ${1:-} in
  catalog) echo "$CATALOG";; list) list_tunnels;; status) status_table machine;; ip) myip; echo "$MYIP";; act) act "$2" "$3";;
  edit) shift; edit_tunnel "$@";;
  create) NAME=$2 TYPE=$3 ROLE=$4 LOCAL=$5 REMOTE=$6 PORTS=$7 CPORT=$8 TOKEN=$9 IDX=${10} PEER=${11:-}; create_tunnel;; esac; exit 0; fi
need_root; detect_os; mkdir -p "$TUN" "$RUN" "$CFG" "$CONF/keys" "$ROOT/etc/sysctl.d" 2>/dev/null; menu
