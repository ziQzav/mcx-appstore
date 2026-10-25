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

# OpenRouter defaults: openaiCompat needs baseUrl+model to register.
if [ -n "${OPENAI_COMPAT_API_KEY:-}" ]; then
  export OPENAI_COMPAT_ENABLED=true
  export OPENAI_COMPAT_BASE_URL="${OPENAI_COMPAT_BASE_URL:-https://openrouter.ai/api/v1}"
  export OPENAI_COMPAT_MODEL="${OPENAI_COMPAT_MODEL:-openai/gpt-4o-mini}"
  export DEFAULT_PROVIDER="${DEFAULT_PROVIDER:-openaiCompat}"
fi

# Dashboard login: umbrelOS app password (username: mercury)
if [ -n "${APP_PASSWORD:-}" ]; then
  mercury web-reset-password "${APP_PASSWORD}" >/dev/null 2>&1 || \
    echo "warn: web password reset failed"
fi

for v in OPENAI_API_KEY ANTHROPIC_API_KEY DEEPSEEK_API_KEY GROK_API_KEY OPENAI_COMPAT_API_KEY; do
  if [ -n "$(eval echo \$$v)" ]; then echo "diag: $v is SET"; else echo "diag: $v not set"; fi
done

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