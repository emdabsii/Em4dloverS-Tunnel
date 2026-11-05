#!/usr/bin/env bash
# Em4dloverS Tunnel - one-line installer  |  t.me/Em4dloverS
REPO="https://github.com/Em4dLoverS/Em4dloverS-Tunnel.git"
[ "$(id -u)" = 0 ] || { echo "Run as root: sudo bash install.sh"; exit 1; }
. /etc/os-release
case "$ID:$VERSION_ID" in ubuntu:20.04|ubuntu:22.04|ubuntu:24.04|ubuntu:26.04|debian:11|debian:12|debian:13) ;;
  *) echo "Unsupported OS: $PRETTY_NAME (Ubuntu 20.04/22.04/24.04/26.04 or Debian 11/12/13)"; exit 1;; esac
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq git curl ca-certificates >/dev/null
if [ -d /opt/emadlovers/.git ]; then git -C /opt/emadlovers pull -q; else rm -rf /opt/emadlovers; git clone -q --depth 1 "$REPO" /opt/emadlovers; fi
chmod +x /opt/emadlovers/emad.sh; ln -sf /opt/emadlovers/emad.sh /usr/local/bin/emad
exec emad
