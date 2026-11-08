# Em4dloverS Tunnel Manager - web panel: install the tools one tunnel type needs
# Sourced by emad.sh. Do not run directly.
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

