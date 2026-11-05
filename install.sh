#!/usr/bin/env bash
# Em4dloverS Tunnel - one-line installer  |  t.me/Em4dloverS
GH="${EMAD_GH:-emdabsii/Em4dloverS-Tunnel}"; BR="${EMAD_BRANCH:-main}"
FILES="emad.sh panel/app.py"
APP="${EMAD_DIR:-/opt/emadlovers}"
R=$'\e[1;31m'; G=$'\e[1;32m'; W=$'\e[1;37m'; D=$'\e[2m'; N=$'\e[0m'
pal=(52 88 124 160 196 196 160 124 88 52 88 124 160 196 196 160 124 88); n=0
[ -n "${EMAD_TEST:-}" ] || clear
while IFS= read -r l; do printf '\e[38;5;%sm%s\e[0m\n' "${pal[$((n++ % 18))]}" "$l"; done <<'ART'
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
printf '\n  %sEm4dloverS Tunnel%s  installer\n  %sChannel%s t.me/Em4dloverS   %sSupport%s %st.me/kamr4%s\n\n' "$W" "$N" "$R" "$N" "$R" "$N" "$D" "$N"
[ -n "${EMAD_TEST:-}" ] || [ "$(id -u)" = 0 ] || { echo "  Run as root:  sudo -i   then run the command again"; exit 1; }
PCT=0; T0=$SECONDS
draw(){ local p=$1 f=$(( $1 * 36 / 100 )); [ "$p" -gt "$PCT" ] && PCT=$p
  printf '\r\e[K  %s[%s%s]%s %3d%%  %s%s%s' "$R" "$(printf '%.0s#' $(seq 1 $f))" "$(printf '%.0s-' $(seq 1 $((36-f))))" "$N" "$p" "$D" "$2" "$N"; }
ok(){ draw "$1" "$2"; printf '\n  %s[ OK ]%s %s\n' "$G" "$N" "$3"; }
fail(){ printf '\n  %s[FAIL]%s %s\n' "$R" "$N" "$1"; [ -s "${2:-/dev/null}" ] && tail -5 "$2" | sed 's/^/    /'; exit 1; }
# creeping bar while a command runs (apt has no real percent)
run_creep(){ local a=$1 b=$2 msg=$3 p=$1 i=0; shift 3; "$@" >/tmp/emad_i.log 2>&1 & local pid=$!
  while kill -0 $pid 2>/dev/null; do p=$(( p + (b - 1 - p) / 12 + (i++ % 3 == 0 ? 1 : 0) )); [ $p -ge $b ] && p=$((b-1)); draw $p "$msg  $((SECONDS-T0))s"; sleep 0.3; done
  wait $pid || fail "$msg failed" /tmp/emad_i.log; ok "$b" "$msg" "$msg"; }

draw 2 "Checking system"; sleep 0.3
. /etc/os-release 2>/dev/null
case "${ID:-}:${VERSION_ID:-}" in ubuntu:20.04|ubuntu:22.04|ubuntu:24.04|ubuntu:26.04|debian:11|debian:12|debian:13) ok 10 "${PRETTY_NAME}" "System supported: ${PRETTY_NAME}";;
  *) fail "Unsupported OS: ${PRETTY_NAME:-unknown} (Ubuntu 20.04/22.04/24.04/26.04 or Debian 11/12/13)";; esac
# curl is the only requirement; no apt update (slow on some networks)
if ! command -v curl >/dev/null; then
  run_creep 10 25 "Installing curl" bash -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates || { apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates; }'
else ok 25 "curl" "curl is already installed"; fi
# download only the files that are needed, GitHub first and a mirror as backup
SRC=("${EMAD_BASE:-https://raw.githubusercontent.com/$GH/$BR}" "https://cdn.jsdelivr.net/gh/$GH@$BR")
NAMES=("GitHub" "jsDelivr mirror"); TMP=$(mktemp -d); nf=$(echo $FILES | wc -w); k=0
for f in $FILES; do
  base=$((25 + k * 65 / nf)); top=$((25 + (k + 1) * 65 / nf)); got=0; mkdir -p "$TMP/$(dirname $f)"
  for si in 0 1; do
    for try in 1 2; do
      curl -fsSL --connect-timeout 8 --max-time 45 "${SRC[$si]}/$f" -o "$TMP/$f" 2>/tmp/emad_c.log &
      pid=$!; p=$base
      while kill -0 $pid 2>/dev/null; do p=$((p + (top - 1 - p) / 10 + 1)); [ $p -ge $top ] && p=$((top-1)); draw $p "$f via ${NAMES[$si]}  $((SECONDS-T0))s"; sleep 0.25; done
      if wait $pid && [ -s "$TMP/$f" ]; then got=1; break 2; fi
    done
  done
  [ $got = 1 ] || fail "Could not download $f from GitHub or the mirror. Check the repository name ($GH), that it is Public, and that the file exists." /tmp/emad_c.log
  ok "$top" "$f" "Downloaded $f"; k=$((k+1))
done
[ -s "$TMP/emad.sh" ] && head -1 "$TMP/emad.sh" | grep -q '^#!' && python3 -m py_compile "$TMP/panel/app.py" 2>/dev/null || [ ! -x "$(command -v python3)" ] || fail "Downloaded files look damaged. Run the command again."
draw 95 "Installing"; mkdir -p "$APP/panel"; cp "$TMP/emad.sh" "$APP/emad.sh"; cp "$TMP/panel/app.py" "$APP/panel/app.py"; chmod +x "$APP/emad.sh"; rm -rf "$TMP" "$APP/panel/__pycache__"
[ -n "${EMAD_TEST:-}" ] || ln -sf "$APP/emad.sh" /usr/local/bin/emad
ok 100 "Done in $((SECONDS-T0))s" "Installed. Starting the menu..."; sleep 1
[ -n "${EMAD_TEST:-}" ] && exit 0
# restart the panel so it runs the new code (login and port stay the same)
systemctl is-active --quiet emad-panel 2>/dev/null && systemctl restart emad-panel
exec emad
