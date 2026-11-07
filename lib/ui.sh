# Em4dloverS Tunnel Manager - UI: banner, headings, animated install steps
# Sourced by emad.sh. Do not run directly.
STEPS=(); TOTAL=1; DONEN=0
banner(){
  [ -n "${EMAD_DEMO:-}" ] || clear
  local pal=(52 88 124 160 196 196 160 124 88 52 88 124 160 196 196 160 124 88) n=0 l
  while IFS= read -r l; do printf '\e[38;5;%sm%s\e[0m\n' "${pal[$((n++ % 18))]}" "$l"; nap 0.02; done <<'ART'
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
  myip
  printf '\n  %sEm4dloverS Tunnel Manager%s  %sv%s%s\n' "$W" "$N" "$D" "$VER" "$N"
  printf '  %s%s%s\n' "$DR" "$(printf '%.0s=' $(seq 1 62))" "$N"
  printf '  %sSystem%s  %s %s    %sServer IP%s  %s\n' "$D" "$N" "$OS_NAME" "$OS_VER" "$D" "$N" "$MYIP"
}
hdr(){ printf '\n  %s>> %s%s\n\n' "$R" "$1" "$N"; }
ask(){ local v; printf '  %s%s%s%s: ' "$W" "$1" "${2:+ [$2]}" "$N"; read -r v; REPLY=${v:-${2:-}}; }
pause(){ printf '\n  %sPress Enter to go back...%s' "$D" "$N"; read -r _; }
bar(){ local p=$((DONEN*100/TOTAL)) f=$((DONEN*40/TOTAL)); printf '  %s[%s%s]%s %3d%%\n' "$R" "$(printf '%.0s#' $(seq 1 $f 2>/dev/null))" "$(printf '%.0s-' $(seq 1 $((40-f)) 2>/dev/null))" "$N" "$p"; }
# job log for the web panel: lines "state|message" (run, ok, fail, done)
job_log(){ [ -n "${EMAD_JOB:-}" ] && printf '%s|%s\n' "$1" "$(printf %s "$2" | tr -d '\r\n|')" >>"$EMAD_JOB"; return 0; }
# one install step: spinner while it runs, then OK or FAIL with the log path
step(){ local msg=$1 p i=0 sp='|/-\' ; shift; job_log run "$msg"
  "$@" >>"$LOG" 2>&1 & p=$!
  while kill -0 $p 2>/dev/null; do printf '\r  %s%s%s  %s' "$R" "${sp:$((i++%4)):1}" "$N" "$msg"; sleep 0.1; done
  DONEN=$((DONEN+1))
  if wait $p; then printf '\r\e[K  %sOK%s    %s\n' "$G" "$N" "$msg"; STEPS+=("OK|$msg"); job_log ok "$msg"
  else printf '\r\e[K  %sFAIL%s  %s   (log: %s)\n' "$R" "$N" "$msg" "$LOG"; STEPS+=("FAIL|$msg"); job_log fail "$msg"; fi; bar; }
summary(){ printf '\n  %sDone%s\n' "$W" "$N"; local s; for s in "${STEPS[@]}"; do
  [ "${s%%|*}" = OK ] && printf '   %s+%s %s\n' "$G" "$N" "${s#*|}" || printf '   %sx%s %s\n' "$R" "$N" "${s#*|}"; done; nap 1; }
