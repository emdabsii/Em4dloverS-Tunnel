# Em4dloverS Tunnel Manager - status and optimizer: install the tools one tunnel type needs
# Sourced by emad.sh. Do not run directly.
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
