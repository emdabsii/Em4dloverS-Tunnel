# Em4dloverS Tunnel Manager - engines: install the tools one tunnel type needs
# Sourced by emad.sh. Do not run directly.
# already installed? then nothing to do
deps_present(){ case $1 in
  kernel) command -v ip >/dev/null && command -v iptables >/dev/null;;
  wg) command -v wg >/dev/null;;
  socat) command -v socat >/dev/null;;
  haproxy) command -v haproxy >/dev/null;;
  gost) [ -x /usr/local/bin/gost ];;
  rathole) [ -x /usr/local/bin/rathole ];;
  backhaul) [ -x /usr/local/bin/backhaul ];;
  frp) [ -x /usr/local/bin/frps ] && [ -x /usr/local/bin/frpc ];;
  chisel) [ -x /usr/local/bin/chisel ];;
  hysteria) [ -x /usr/local/bin/hysteria ];;
  xray) [ -x /usr/local/bin/xray ];;
  *) return 1;; esac; }
# ---------- engines ----------
fetch_bin(){ local repo=$1 rx=$2 t=/tmp/emad_dl url b f; shift 2; rm -rf $t; mkdir -p $t
  url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 | grep -E "$rx" | head -1)
  [ -n "$url" ] || return 1; curl -fsSL "$url" -o $t/pkg || return 1
  case $url in *.zip) unzip -qo $t/pkg -d $t;; *.tar.gz) tar xzf $t/pkg -C $t;; *.gz) gunzip -c $t/pkg >$t/$1;; *) cp $t/pkg $t/$1;; esac
  for b in "$@"; do f=$(find $t -type f -name "$b" | head -1); [ -n "$f" ] || return 1; install -m755 "$f" /usr/local/bin/$b; done; }
install_engine(){ local e=$1; STEPS=(); DONEN=0; TOTAL=3; mkdir -p "$(dirname "$LOG")"
  if deps_present "$e"; then printf "  %sOK%s    %s tools already installed\n" "$G" "$N" "$e"; job_log ok "$e tools already installed"; return 0; fi
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

# called automatically when a tunnel is created: installs only what that type needs
ensure_deps(){ local e; e=$(engine_of "$1"); [ -n "$e" ] || return 1; install_engine "$e"; }
