#!/usr/bin/env bash
# Em4dloverS Tunnel - one-line installer  |  t.me/Em4dloverS
REPO="${EMAD_REPO:-https://github.com/Em4dLoverS/Em4dloverS-Tunnel.git}"
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

draw 2 "Checking system"; sleep 0.4
. /etc/os-release 2>/dev/null
case "${ID:-}:${VERSION_ID:-}" in ubuntu:20.04|ubuntu:22.04|ubuntu:24.04|ubuntu:26.04|debian:11|debian:12|debian:13) ok 10 "${PRETTY_NAME}" "System supported: ${PRETTY_NAME}";;
  *) fail "Unsupported OS: ${PRETTY_NAME:-unknown} (Ubuntu 20.04/22.04/24.04/26.04 or Debian 11/12/13)";; esac
export DEBIAN_FRONTEND=noninteractive
if [ -z "${EMAD_TEST:-}" ]; then
  run_creep 10 30 "Updating package index" apt-get update -qq
  run_creep 30 42 "Installing git and curl" apt-get install -y -qq git curl ca-certificates
fi
# real percentage from git
git_progress(){ local msg=$1 tmp=/tmp/emad_git.log p=0 q; shift; : >$tmp; "$@" --progress >$tmp 2>&1 & local pid=$!
  while kill -0 $pid 2>/dev/null; do q=$(tr '\r' '\n' <$tmp | grep -oE '[0-9]+%' | tail -1 | tr -d %); [ -n "$q" ] && [ "$q" -gt "$p" ] && p=$q
    draw $((42 + p * 50 / 100)) "$msg  $((SECONDS-T0))s"; sleep 0.15; done
  wait $pid || fail "Could not download the project from GitHub. Check that the repository is Public and the link is correct." $tmp; ok 92 "$msg" "$msg"; }
draw 42 "Connecting to GitHub"
if [ -d "$APP/.git" ]; then git -C "$APP" config core.fileMode false; git -C "$APP" reset -q --hard; git -C "$APP" clean -fdq
  git_progress "Downloading latest version" git -C "$APP" pull -q
else rm -rf "$APP"; git_progress "Downloading project from GitHub" git clone -q --depth 1 "$REPO" "$APP"; git -C "$APP" config core.fileMode false; fi
[ -f "$APP/emad.sh" ] && [ -f "$APP/panel/app.py" ] || fail "Project files are incomplete (emad.sh or panel/app.py missing in the repository)."
draw 95 "Finishing"; chmod +x "$APP/emad.sh"
[ -n "${EMAD_TEST:-}" ] || ln -sf "$APP/emad.sh" /usr/local/bin/emad
ok 100 "Done in $((SECONDS-T0))s" "Installed. Starting the menu..."; sleep 1
[ -n "${EMAD_TEST:-}" ] && exit 0; exec emad
