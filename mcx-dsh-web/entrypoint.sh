#!/bin/bash
# Seeds the persistent DSH home from the image template on first start, then
# hands over to the upstream entrypoint: dsh web on 127.0.0.1:3079 plus the
# token-aware proxy on 0.0.0.0:3080 (umbrel app_proxy talks to that).
set -eu

export DSH_HOME="${DSH_HOME:-/data}"
mkdir -p "$DSH_HOME"
if [ ! -d "$DSH_HOME/profiles/web" ]; then
  echo "[mcx] seeding $DSH_HOME from the image template (dsh-web preinstalled)"
  cp -a /opt/dsh-template/. "$DSH_HOME"/
fi

mkdir -p /workspace
cd /workspace

exec /app/entrypoint.sh "$@"

# 0.4.14-3: image rebased on smanx/deepseek-harness:devtools (digest pinned in the Dockerfile).
