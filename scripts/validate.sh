#!/usr/bin/env bash
# buidl-kit structural validator. Run before pushing; also runs in CI.
# Fails (exit 1) on: unresolved ${CLAUDE_PLUGIN_ROOT} refs, knowledge files > 400
# lines, or malformed frontmatter. Warns (does not fail) on stale last_verified.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
MAX_LINES=400
STALE_DAYS=60

warn() { printf '::warning %s\n' "$1" 2>/dev/null; printf 'WARN:  %s\n' "$2"; }
err()  { printf 'ERROR: %s\n' "$1"; fail=1; }
ok()   { printf 'ok:    %s\n' "$1"; }

# Portable "days since YYYY-MM-DD" (GNU date, then BSD/macOS date).
days_since() {
  local d="$1" then now
  then=$(date -d "$d" +%s 2>/dev/null) || then=$(date -j -f %Y-%m-%d "$d" +%s 2>/dev/null) || return 1
  now=$(date +%s)
  echo $(( (now - then) / 86400 ))
}

echo "== 1. \${CLAUDE_PLUGIN_ROOT} references resolve =="
# Every concrete .md reference must exist. Skip directory refs (end in /) and
# placeholders (contain <...>, e.g. <archetype>).
missing=0
while IFS= read -r ref; do
  rel="${ref#\$\{CLAUDE_PLUGIN_ROOT\}/}"
  case "$rel" in
    */) continue ;;          # directory reference
    *"<"*) continue ;;       # placeholder like recipes/<archetype>.md
  esac
  if [ ! -e "$rel" ]; then
    err "referenced file not found: $rel"
    missing=1
  fi
done < <(grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./<>-]+' commands agents skills 2>/dev/null | sort -u)
[ "$missing" -eq 0 ] && ok "all concrete knowledge references resolve"

echo "== 2. knowledge files <= $MAX_LINES lines =="
while IFS= read -r f; do
  n=$(wc -l < "$f" | tr -d ' ')
  if [ "$n" -gt "$MAX_LINES" ]; then
    err "$f is $n lines (limit $MAX_LINES)"
  fi
done < <(find knowledge -name '*.md' -type f)
[ "$fail" -eq 0 ] && ok "all knowledge files within $MAX_LINES lines"

echo "== 3. frontmatter present and closed =="
# Commands, agents, skills, and knowledge all use YAML frontmatter.
while IFS= read -r f; do
  first=$(head -n1 "$f")
  if [ "$first" != "---" ]; then
    err "$f does not start with '---' frontmatter"
    continue
  fi
  # a closing --- must exist somewhere after line 1
  if ! awk 'NR>1 && $0=="---"{found=1; exit} END{exit !found}' "$f"; then
    err "$f frontmatter is not closed with '---'"
  fi
done < <(find commands agents skills knowledge -name '*.md' -type f)
[ "$fail" -eq 0 ] && ok "frontmatter present and closed in all command/agent/skill/knowledge files"

echo "== 4. last_verified staleness (warn only) =="
while IFS= read -r f; do
  lv=$(grep -m1 -E '^last_verified:' "$f" | sed -E 's/^last_verified:[[:space:]]*//; s/["'"'"']//g' | tr -d ' ')
  [ -z "$lv" ] && continue
  age=$(days_since "$lv") || { warn "file=$f::could not parse last_verified '$lv'" "$f: unparseable last_verified '$lv'"; continue; }
  if [ "$age" -gt "$STALE_DAYS" ]; then
    warn "file=$f::last_verified is $age days old (>$STALE_DAYS) — consider /kb-update" "$f: last_verified $lv is $age days old"
  fi
done < <(find knowledge -name '*.md' -type f)

echo
if [ "$fail" -ne 0 ]; then
  echo "VALIDATION FAILED"
  exit 1
fi
echo "VALIDATION PASSED"
