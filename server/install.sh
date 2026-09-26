#!/bin/sh
# Installs/updates the DynMagic dedicated server (one room, UDP 7777) from a GitHub release.
set -e
TAG="${1:-v1.1.0-alpha}"
URL="https://github.com/VSennaa/DynMagic/releases/download/$TAG/DynMagic-server-$TAG-linux-x64.tar.gz"
TMP=/tmp/dynmagic-server
rm -rf "$TMP"; mkdir -p "$TMP"
curl -fsSL "$URL" -o "$TMP/server.tar.gz"
tar -xzf "$TMP/server.tar.gz" -C "$TMP"
BIN=$(find "$TMP" -name 'DynMagic-server.x86_64' | head -1)
[ -n "$BIN" ] || { echo "binary not found"; ls -R "$TMP"; exit 1; }
SRC=$(dirname "$BIN")
id dynmagic >/dev/null 2>&1 || sudo useradd -r -s /usr/sbin/nologin dynmagic
sudo mkdir -p /opt/dynmagic /etc/dynmagic
sudo cp -r "$SRC"/. /opt/dynmagic/
sudo chmod +x /opt/dynmagic/DynMagic-server.x86_64
sudo cp /opt/dynmagic/dynmagic@.service /etc/systemd/system/dynmagic@.service
if [ ! -f /etc/dynmagic/room1.env ]; then
  printf 'DYNMAGIC_PORT=7777\nDYNMAGIC_NAME=DynMagic VPS\nDYNMAGIC_EXTRA=--overtime collapse --arena rotation\n' | sudo tee /etc/dynmagic/room1.env >/dev/null
fi
echo "$TAG" | sudo tee /opt/dynmagic/VERSION >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable dynmagic@room1 >/dev/null 2>&1
sudo systemctl restart dynmagic@room1
sleep 4
systemctl is-active dynmagic@room1
sudo journalctl -u dynmagic@room1 -n 8 --no-pager | cut -c1-160
ss -ulpn 2>/dev/null | grep -E ':777[0-9]|:7778' || true
systemctl show -p MemoryCurrent dynmagic@room1
