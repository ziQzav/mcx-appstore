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
    echo "warn: web password reset failed (dashboard keeps its own init password)"
fi

# Supervisor: keep the background runtime alive; echo daemon logs to stdout
# so `get_app_logs` can show why the dashboard is (not) listening.
(
  while true; do
    mercury start >/dev/null 2>&1 || true
    sleep 10
    if ! kill -0 "$(pgrep -f 'mercury.*daemon' | head -1)" 2>/dev/null; then
      echo "--- daemon.log (last 40 lines) ---"
      tail -n 40 "$MERCURY_HOME/daemon.log" 2>/dev/null || echo "(no daemon.log)"
    fi
    sleep 20
  done
) &

# Relay: expose Mercury's loopback-only dashboard on 0.0.0.0:24674
exec socat TCP-LISTEN:24674,fork,reuseaddr TCP:127.0.0.1:6174
