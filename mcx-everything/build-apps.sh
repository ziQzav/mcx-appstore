#!/bin/bash
# Build every Puter "everything" app (src/<app>) into its own dist/,
# then generate the hub page (index.html) from the curated apps.json list.
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

# ---- hub page from apps.json ----
# status: ok | account | demo  -> shown in its own section
# status: broken               -> hidden from the hub and not shipped in the image
node - "$SRC" <<'NODE'
const fs = require('fs');
const ok = new Set(fs.readFileSync('/tmp/build-ok.txt', 'utf8').trim().split('\n').filter(Boolean));
const curated = JSON.parse(fs.readFileSync('/apps.json', 'utf8')).apps;
const known = new Set(curated.map(a => a.slug));

const entries = curated
  .filter(a => a.status !== 'broken' && ok.has(a.slug))
  .map(a => ({ slug: a.slug, name: a.name, status: a.status, ...(a.note ? { note: a.note } : {}) }));

const skipped = curated.filter(a => a.status === 'broken' && ok.has(a.slug)).map(a => a.slug);
fs.writeFileSync('/tmp/skip.txt', skipped.join('\n') + (skipped.length ? '\n' : ''));

const unlisted = [...ok].filter(s => !known.has(s)).sort();
if (unlisted.length) fs.writeFileSync('/tmp/unlisted.txt', unlisted.join('\n') + '\n');

const html = fs.readFileSync('/tmp/hub-template.html', 'utf8');
fs.writeFileSync('/tmp/hub-final.html', html.replace('__APPS__', JSON.stringify(entries)));
console.log('hub entries:', entries.length,
  '| ok:', entries.filter(e => e.status === 'ok').length,
  '| account:', entries.filter(e => e.status === 'account').length,
  '| demo:', entries.filter(e => e.status === 'demo').length,
  '| hidden broken:', skipped.join(',') || 'none',
  '| unlisted (not in hub):', unlisted.join(',') || 'none');
NODE
echo "hub written"
exit 0
