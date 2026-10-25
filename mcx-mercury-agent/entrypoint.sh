#!/bin/bash
set -e

export MERCURY_HOME="${MERCURY_HOME:-/data/mercury}"
mkdir -p "$MERCURY_HOME"

CONFIG="$MERCURY_HOME/mercury.yaml"

# Headless first-run: a config file with a non-empty identity.owner marks
# setup complete and skips the interactive wizard (isSetupComplete() in
# mercury's config.ts checks exactly this).
if [ ! -s "$CONFIG" ]; then
  cat > "$CONFIG" <<EOF
identity:
  name: Mercury
  owner: ${MERCURY_OWNER:-umbrel}
web:
  port: 6174
EOF
fi

# Dashboard login: umbrelOS app password (username: mercury)
if [ -n "${APP_PASSWORD:-}" ]; then
  mercury web-reset-password "${APP_PASSWORD}" >/dev/null 2>&1 || \
    echo "warn: web password reset failed"
fi

# Run the runtime in FOREGROUND (-f) inside a supervised subshell so its
# stdout/stderr (and any crash reason) flow to container logs.
(
  while true; do
    echo "=== starting mercury runtime ==="
    mercury start -f -v || echo "=== mercury runtime exited (code $?) ==="
    sleep 5
  done
) &

sleep 5

# Relay: expose Mercury's loopback-only dashboard on 0.0.0.0:24674
exec socat TCP-LISTEN:24674,fork,reuseaddr TCP:127.0.0.1:6174