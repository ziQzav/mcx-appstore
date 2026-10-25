#!/bin/bash
# Build every Puter "everything" app (src/<app>) into its own dist/,
# then generate the hub page (index.html) listing every built app.
# Resilient: a failing app is logged and skipped, it must not kill the image.
set -u
SRC=/src
FAILED=/tmp/build-failures.txt
: > "$FAILED"

# Skip non-apps / placeholders (matches upstream CI: assets is a placeholder).
SKIP="assets"

apps=$(ls -d "$SRC"/src/*/package.json 2>/dev/null | sed "s|$SRC/src/||; s|/package.json||" | grep -Fxv "$SKIP" | sort)
echo "Building apps: $(echo "$apps" | wc -l)"
echo "$apps" > /tmp/app-list.txt

build_one() {
  app="$1"
  cd "$SRC/src/$app" || { echo "$app: no dir" >> "$FAILED"; return; }
  echo "=== [$app] npm ci"
  if ! npm ci --no-audit --no-fund --loglevel=error; then
    echo "$app: npm ci failed" >> "$FAILED"; return
  fi
  echo "=== [$app] build"
  if ! npm run build --no-audit --no-fund --loglevel=error; then
    echo "$app: build failed" >> "$FAILED"; return
  fi
  if [ ! -d dist ]; then
    echo "$app: no dist/" >> "$FAILED"; return
  fi
  echo "$app: OK" >> /tmp/build-ok.txt
}
export -f build_one
export SRC FAILED

# 4 parallel builds keeps memory sane on hosted runners (vite is memory hungry).
echo "$apps" | xargs -P 4 -I{} bash -c 'build_one "$@"' _ {}

echo "=== FAILURES ==="
cat "$FAILED"
ok=$(comm -23 /tmp/app-list.txt <(sed 's/:.*//' "$FAILED" | sort))
printf '%s\n' "$ok" > /tmp/build-ok.txt
echo "built OK: $(echo "$ok" | grep -c .)"
# Fail the image build only if almost nothing built (real environment problem).
[ "$(echo "$ok" | wc -l)" -lt 25 ] && { echo "too many failures"; exit 1; }

# ---- hub page: replace __APPS__ with [slug, display name] for every OK app ----
node - "$SRC" <<'NODE'
const fs = require('fs');
const path = require('path');
const SRC = process.argv[2];
const ok = new Set(fs.readFileSync('/tmp/build-ok.txt', 'utf8').trim().split('\n').filter(Boolean));
const entries = [];
for (const app of [...ok].sort()) {
  let name = app;
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(SRC, 'src', app, 'package.json'), 'utf8'));
    if (pkg.description) {
      // Use the first sentence, trimmed, as a tooltip title; keep slug as label.
      name = app;
    }
  } catch {}
  entries.push([app, name.charAt(0).toUpperCase() + name.slice(1)]);
}
const html = fs.readFileSync('/tmp/hub-template.html', 'utf8');
fs.writeFileSync(path.join(SRC, 'hub-index.html'),
  html.replace('__APPS__', JSON.stringify(entries)));
console.log('hub entries:', entries.length);
NODE
cp "$SRC/hub-index.html" /tmp/hub-final.html
echo "hub written"
exit 0
