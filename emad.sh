#!/usr/bin/env bash
# Em4dloverS Tunnel Manager  |  t.me/Em4dloverS  |  support: t.me/KaMr4ng
LIBDIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/lib"
for m in core ui engines tunnels status guide link panel menu; do . "$LIBDIR/$m.sh"; done
# ---------- entry ----------
if [ "${1:-}" = api ]; then shift; need_root; case ${1:-} in
  catalog) echo "$CATALOG";; list) list_tunnels;; status) status_table machine;; ip) myip; echo "$MYIP";; act) act "$2" "$3";;
  edit) shift; edit_tunnel "$@";;
  tune) tune_all;;
  link) make_link "$2";;
  apply-link) apply_link "$2";;
  guide) guide_make "$2";;
  create) NAME=$2 TYPE=$3 ROLE=$4 LOCAL=$5 REMOTE=$6 PORTS=$7 CPORT=$8 TOKEN=$9 IDX=${10} PEER=${11:-}; _o=$(create_tunnel); job_log done "$_o"; echo "$_o";; esac; exit 0; fi
need_root; detect_os; mkdir -p "$TUN" "$RUN" "$CFG" "$CONF/keys" "$ROOT/etc/sysctl.d" 2>/dev/null; menu
