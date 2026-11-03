#!/bin/bash
# Runs dsh web as the node user. The container is the sandbox boundary.
set -eu

PUID=${PUID:-1000}
PGID=${PGID:-1000}
groupmod -o -g "$PGID" node
usermod -o -u "$PUID" node

# First start: seed the data volume with the template profile (dsh-web installed).
if [ ! -d /data/profiles/web ]; then
  mkdir -p /data
  cp -a /opt/dsh-template/. /data/
fi
find -P /data -xdev \( ! -uid "$PUID" -o ! -gid "$PGID" \) \
  -exec chown -h node:node -- {} +

mkdir -p /workspace
if [ -z "$(ls -A /workspace)" ]; then
  chown node:node /workspace
fi

# dsh web refuses wildcard hosts, so it binds loopback and socat publishes the
# port on every interface. The app proxy stays the network boundary.
LISTEN_PORT=${DSH_LISTEN_PORT:-3081}
EXPOSE_PORT=${DSH_EXPOSE_PORT:-3080}

socat "TCP-LISTEN:${EXPOSE_PORT},fork,reuseaddr" "TCP:127.0.0.1:${LISTEN_PORT}" &

cat > /tmp/listen.patch.yml <<EOF
- id: webserver
  config:
    host: 127.0.0.1
    port: $LISTEN_PORT
    compression: gzip
    compressionLevel: 1
    compressionThresholdBytes: 1024
EOF

set -- dsh --profile web --patch /tmp/listen.patch.yml --no-open "$@"

if [ -n "${DSH_TRUSTED_HOST:-}" ]; then
  old_ifs=$IFS
  IFS=','
  for trusted in $DSH_TRUSTED_HOST; do
    [ -n "$trusted" ] && set -- "$@" --trusted-host "$trusted"
  done
  IFS=$old_ifs
fi

export HOME=/home/node
cd /workspace
exec gosu node "$@"
