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

# dsh web refuses wildcard hosts, so bind the container's own interface IP.
# Docker publishes the port; the app proxy is the network boundary.
if [ -n "${DSH_HOST:-}" ]; then
  HOST=$DSH_HOST
else
  HOST=$(hostname -i 2>/dev/null | awk '{print $1}')
fi
if [ -z "$HOST" ] || [ "$HOST" = "0.0.0.0" ]; then
  echo "entrypoint: could not determine a concrete container IP; set DSH_HOST" >&2
  exit 1
fi
LISTEN_PORT=${DSH_LISTEN_PORT:-3080}

cat > /tmp/listen.patch.yml <<EOF
- id: webserver
  config:
    host: $HOST
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
