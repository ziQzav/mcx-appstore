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

# dsh web refuses a wildcard --host, so an overlay binds all interfaces instead;
# the published port is the network boundary.
HOST=${DSH_HOST:-0.0.0.0}
LISTEN_PORT=${DSH_LISTEN_PORT:-3080}
case "$HOST" in
  0.0.0.0|127.0.0.1) ;;
  *) echo "entrypoint: DSH_HOST must be 0.0.0.0 or 127.0.0.1 (got '$HOST')" >&2; exit 1 ;;
esac

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
