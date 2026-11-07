# Em4dloverS Tunnel Manager - menu: the terminal screens
# Sourced by emad.sh. Do not run directly.

row(){ printf '  %s|%s %s[%s]%s %-21s %s[%s]%s %-21s %s|%s\n' "$R" "$N" "$R" "$1" "$N" "$2" "$R" "$3" "$N" "$4" "$R" "$N"; }
frame_top(){ printf '  %s+%s+%s\n' "$R" "$(printf '%.0s-' $(seq 1 53))" "$N"; }
frame_bot(){ printf '  %s+%s+%s\n' "$R" "$(printf '%.0s-' $(seq 1 53))" "$N"; }

# grouped picker: every type shows its family as a heading
pick_type(){ local i=0 t n d g last=""; hdr "Choose tunnel type  (70 types)"
  while IFS='|' read -r t n d g; do i=$((i+1))
    if [ "$g" != "$last" ]; then printf '\n  %s%s%s\n' "$W" "$g" "$N"; last=$g; fi
    printf '   %s%2d%s  %-20s %s%s%s\n' "$R" "$i" "$N" "$n" "$D" "$d" "$N"
  done <<<"$CATALOG"
  ask "Number" 1; TYPE=$(echo "$CATALOG" | sed -n "${REPLY}p" | cut -d'|' -f1); [ -n "$TYPE" ]; }

# create a tunnel: pick type, side, IPs, ports, ID, control port, token
wizard(){ local again=y; while [ "$again" = y ]; do
  pick_type || { echo "  Invalid choice."; return; }
  local e; e=$(engine_of "$TYPE"); hdr "Create: $(type_name "$TYPE")"
  ask "Tunnel name (a-z 0-9 - _)" "t$(next_idx)"; NAME=$REPLY
  printf '  This server is:  %s1%s Iran (entry, enter ports here)   %s2%s Foreign (exit, no ports)\n' "$R" "$N" "$R" "$N"
  ask "Role" 1; [ "$REPLY" = 2 ] && ROLE=foreign || ROLE=iran
  myip; ask "This server public IP" "$MYIP"; LOCAL=$REPLY; ask "Other server IP"; REMOTE=$REPLY
  ask "Tunnel ID 1-250 (use the SAME on both servers)" "$(next_idx)"; IDX=$REPLY; PORTS=""; CPORT=""; TOKEN=""
  if [ "$ROLE" = iran ] || [[ $TYPE =~ $REVERSE_RX ]]; then ask "Ports (e.g. 80,443,2000-2100)" "443"; PORTS=$REPLY; else PORTS=1; fi
  if [[ $e =~ ^(gost|rathole|backhaul|frp|chisel|hysteria|xray)$ ]]; then ask "Control port (same on both servers)" "$((33000+IDX))"; CPORT=$REPLY
    ask "Token (same on both servers, Enter = new)"; TOKEN=${REPLY:-$(rand_str 16)}; printf '  Token: %s%s%s\n' "$W" "$TOKEN" "$N"; fi
  PEER=""; if [ "$TYPE" = wg ]; then echo "  WireGuard needs the other side's public key."
    ask "Peer public key (Enter = create keys now, set it later)"; PEER=$REPLY; fi
  echo; hdr "Preparing tools for $(type_name "$TYPE")"; STEPS=(); DONEN=0; TOTAL=1; ensure_deps "$TYPE"
  local out; out=$(create_tunnel); printf '\n  Result: %s%s%s\n' "$W" "$out" "$N"
  [ "$TYPE" = wg ] && printf '  Your public key: %s%s%s\n' "$W" "$(cat "$CONF/keys/$NAME.pub" 2>/dev/null)" "$N"
  if [ "$ROLE" = iran ]; then printf '\n  %sLink for the foreign server%s (run on it: emad apply-link LINK)\n  %s%s%s\n' "$W" "$N" "$W" "$(make_link "$NAME")" "$N"; fi
  ask "Add another tunnel? (y/n)" n; again=$REPLY; done; }

edit_menu(){ load "$1"; hdr "Edit $1  ($TYPE, $ROLE)"; local a=()
  ask "Other server IP" "$REMOTE"; [ "$REPLY" != "$REMOTE" ] && a+=("remote=$REPLY")
  ask "This server IP" "$LOCAL"; [ "$REPLY" != "$LOCAL" ] && a+=("local=$REPLY")
  if [ "$PORTS" != 1 ]; then ask "Ports (add or remove, e.g. 80,443,2000-2100)" "$PORTS"; [ "$REPLY" != "$PORTS" ] && a+=("ports=$REPLY"); fi
  if [ -n "$CPORT" ]; then ask "Control port" "$CPORT"; [ "$REPLY" != "$CPORT" ] && a+=("cport=$REPLY"); ask "Token" "$TOKEN"; [ "$REPLY" != "$TOKEN" ] && a+=("token=$REPLY"); fi
  [ ${#a[@]} -eq 0 ] && { echo "  Nothing changed."; return; }
  printf '  Result: %s%s%s\n  %sApply the same IP, port, control port and token changes on the other server.%s\n' "$W" "$(edit_tunnel "$1" "${a[@]}")" "$N" "$D" "$N"; }

manage(){ while :; do hdr "Tunnels"; local i=0 names=() n t r rem p s c
  printf '  %s%-4s %-14s %-18s %-8s %-18s %s%s\n' "$D" "No." "Name" "Type" "Role" "Ports" "State" "$N" "" 
  while IFS='|' read -r n t r rem p s; do [ -n "$n" ] || continue; i=$((i+1)); names+=("$n"); c=$R; [ "$s" = active ] && c=$G
    printf '  %s%-4s%s %-14s %-18s %-8s %-18s %s%s%s\n' "$R" "$i" "$N" "$n" "$(type_name "$t")" "$r" "${p:0:18}" "$c" "$s" "$N"; done < <(list_tunnels)
  [ $i -eq 0 ] && { echo "  No tunnels yet."; pause; return; }
  ask "Select number (0 = back)" 0; [ "$REPLY" = 0 ] && return; local sel=${names[$((REPLY-1))]:-}; [ -n "$sel" ] || continue
  printf '\n  %s[s]%s start  %s[x]%s stop  %s[r]%s restart  %s[e]%s edit  %s[g]%s setup guide  %s[l]%s logs  %s[k]%s WireGuard key  %s[d]%s delete\n' "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N" "$R" "$N"
  ask "Action"; case $REPLY in s) act start "$sel";; x) act stop "$sel";; r) act restart "$sel";; d) ask "Type YES to delete" no; [ "$REPLY" = YES ] && act delete "$sel" && echo "  Deleted.";;
   e) edit_menu "$sel"; pause;;
   g) hdr "Setup guide"; echo "  Open this link in your browser (closes after 30 minutes):"; echo "  $(guide_make "$sel")"; pause;;
   l) journalctl -u "emad-$sel" -n 40 --no-pager; pause;;
   k) load "$sel"; ask "Peer public key"; sed -i "s|^PEER=.*|PEER=$REPLY|" "$TUN/$sel.conf"; load "$sel"; gen_run; sysd restart "emad-$sel" && echo "  Done.";; esac; done; }

install_menu(){ hdr "Install tools"; local e i=0 list=(kernel wg socat haproxy gost rathole backhaul frp chisel hysteria xray all)
  for e in "${list[@]}"; do i=$((i+1)); printf '   %s%2d%s  %s\n' "$R" "$i" "$N" "$e"; done
  ask "Number" 12; e=${list[$((REPLY-1))]:-}; [ -n "$e" ] || return
  if [ "$e" = all ]; then for e in "${list[@]:0:11}"; do hdr "Installing: $e"; STEPS=(); DONEN=0; TOTAL=3; install_engine "$e"; done; else STEPS=(); DONEN=0; TOTAL=3; install_engine "$e"; fi; summary; }

support(){ hdr "Contact"; printf '  Channel  %st.me/Em4dloverS%s\n  Support  %st.me/KaMr4ng%s\n' "$W" "$N" "$D" "$N"; }

menu(){ while :; do banner
  printf '\n'; frame_top
  row 1 "Install tools" 6 "Web panel"
  row 2 "Create tunnel" 7 "Panel SSL (domain)"
  row 3 "Manage tunnels" 8 "Reset panel login"
  row 4 "Tunnel status" 9 "Contact"
  row 5 "Optimize network" 0 "Exit"
  frame_bot
  printf '\n'; ask "Select"; case $REPLY in
    1) install_menu;; 2) wizard;; 3) manage; continue;; 4) hdr "Tunnel status (this server)"; status_table;;
    5) hdr "Optimizer"; optimize && echo "  BBR, fq and buffers applied.";;
    6) panel_menu; continue;; 7) panel_ssl;; 8) panel_reset;; 9) support;;
    0) printf '\n  %sBye.  t.me/Em4dloverS%s\n\n' "$R" "$N"; exit 0;; *) continue;; esac; pause; done; }
