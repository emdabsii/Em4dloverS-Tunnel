# Em4dloverS Tunnel Manager - tunnels: install the tools one tunnel type needs
# Sourced by emad.sh. Do not run directly.
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

