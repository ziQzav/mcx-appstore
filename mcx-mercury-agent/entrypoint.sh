#!/bin/bash
set -e

export MERCURY_HOME="${MERCURY_HOME:-/data/mercury}"
export MERCURY_WEB_ENABLED=true
mkdir -p "$MERCURY_HOME"

CONFIG="$MERCURY_HOME/mercury.yaml"

# Config: write provider config directly (env is the source of truth).
# A stored config with identity.owner set skips the interactive wizard
# (isSetupComplete() checks exactly this), and openaiCompat registers only
# when baseUrl+model are non-empty (registry.ts + isProviderConfigured()).
cat > "$CONFIG" <<EOF
identity:
  name: ${MERCURY_NAME:-Mercury}
  owner: ${MERCURY_OWNER:-umbrel}
web:
  port: 6174
providers:
  default: ${DEFAULT_PROVIDER:-openaiCompat}
  openaiCompat:
    name: openaiCompat
    apiKey: ${OPENAI_COMPAT_API_KEY:-}
    baseUrl: ${OPENAI_COMPAT_BASE_URL:-https://openrouter.ai/api/v1}
    model: ${OPENAI_COMPAT_MODEL:-openai/gpt-4o-mini}
    enabled: true
EOF

# OpenRouter defaults: openaiCompat needs baseUrl+model to register.
if [ -n "${OPENAI_COMPAT_API_KEY:-}" ]; then
  export OPENAI_COMPAT_ENABLED=true
  export OPENAI_COMPAT_BASE_URL="${OPENAI_COMPAT_BASE_URL:-https://openrouter.ai/api/v1}"
  export OPENAI_COMPAT_MODEL="${OPENAI_COMPAT_MODEL:-openai/gpt-4o-mini}"
  export DEFAULT_PROVIDER="${DEFAULT_PROVIDER:-openaiCompat}"
fi

# Dashboard login (username: mercury). Password source order:
# user-set MERCURY_PASSWORD env -> umbrelOS app password (APP_PASSWORD).
DASH_PW="${MERCURY_PASSWORD:-${APP_PASSWORD:-}}"
if [ -n "$DASH_PW" ]; then
  mercury web-reset-password "$DASH_PW" >/dev/null 2>&1 && \
    echo "diag: dashboard password set from env" || \
    echo "warn: web password reset failed"
else
  echo "diag: no dashboard password env found (MERCURY_PASSWORD/APP_PASSWORD empty)"
fi

for v in OPENAI_API_KEY ANTHROPIC_API_KEY DEEPSEEK_API_KEY GROK_API_KEY OPENAI_COMPAT_API_KEY; do
  if [ -n "$(eval echo \$$v)" ]; then echo "diag: $v is SET"; else echo "diag: $v not set"; fi
done

# Clear stale runtime state from a previous container run: the pid/attach
# files live on the persistent volume, and a stale pid makes `mercury start`
# attach instead of boot (then the watchdog kills it in a loop).
mercury stop >/dev/null 2>&1 || true
sleep 2

# Run the runtime in FOREGROUND (-f) inside a supervised subshell so its
# stdout/stderr (and any crash reason) flow to container logs.
(
  while true; do
    echo "=== entrypoint v8: starting mercury runtime ==="
    # Feed the boot-time permission prompt: arrow-down selects "Ask Me",
    # Enter confirms; keep stdin open afterwards so the TUI stays alive.
    ( printf '\033[B\n'; sleep infinity ) | script -qfc "mercury start -f -v" /dev/null || echo "=== mercury runtime exited (code $?) ==="
    sleep 5
  done
) &

sleep 5

# Relay: expose Mercury's loopback-only dashboard on 0.0.0.0:24674
exec socat TCP-LISTEN:24674,fork,reuseaddr TCP:127.0.0.1:6174