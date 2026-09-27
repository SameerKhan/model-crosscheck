#!/usr/bin/env bash
# Repository invariants. Run locally before a release; CI runs it on every push.
# Each check exists because the thing it guards has broken before.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
err() { echo "FAIL: $*"; fail=1; }

SKILLS=plugins/crosscheck/skills
PLUGIN=plugins/crosscheck/.claude-plugin/plugin.json

# 1. Manifests and the receipt schema are valid JSON.
for f in .claude-plugin/marketplace.json "$PLUGIN" "$SKILLS"/*/*.json; do
  python3 -m json.tool "$f" >/dev/null 2>&1 || err "invalid JSON: $f"
done

# 2. Every skill's frontmatter name matches its directory, and every skill
#    is named in the README and in both manifest descriptions.
for dir in "$SKILLS"/*/; do
  skill=$(basename "$dir")
  name=$(sed -n 's/^name: *//p' "$dir/SKILL.md" | head -1)
  [ "$name" = "$skill" ] || err "$skill/SKILL.md frontmatter name is '$name'"
  grep -q "/$skill" README.md || err "README does not mention /$skill"
  grep -q "/$skill" "$PLUGIN" || err "plugin.json description omits /$skill"
  grep -q "/$skill" .claude-plugin/marketplace.json || err "marketplace.json description omits /$skill"
done

# 3. The plugin version has a CHANGELOG entry, and it is the newest one.
version=$(python3 -c "import json;print(json.load(open('$PLUGIN'))['version'])")
top=$(sed -n 's/^## \([0-9][0-9.]*\) .*/\1/p' CHANGELOG.md | head -1)
[ "$version" = "$top" ] || err "plugin.json is $version but the newest CHANGELOG entry is $top"

# 4. No em-dashes in any published text file (house style).
#    (Python, not grep: bash 3.2 on macOS lacks \u escapes in $'...'.)
python3 - "$SKILLS" <<'PY' || err "em-dash found"
import pathlib, sys
files = [f for f in sorted(pathlib.Path(".").rglob("*"))
         if f.is_file() and ".git" not in f.parts
         and f.suffix in {".md", ".sh", ".json", ".yml", ".yaml"}]
hits = [f"{f}:{n}" for f in files
        for n, line in enumerate(f.read_text().splitlines(), 1) if chr(0x2014) in line]
if hits: print("\n".join(hits[:5]))
sys.exit(1 if hits else 0)
PY

# 5. Every `codex exec` command line closes or feeds stdin. Without it a
#    background run waits for EOF forever (codex-cli 0.146). Checks lines
#    that start with `codex exec` or `cd ... && codex exec` inside the
#    skills; prose mentions are ignored.
bad=$(grep -rnE '^[[:space:]]*(cd [^&]*&& )?codex exec ' "$SKILLS" | grep -vE '< ' || true)
[ -z "$bad" ] || { echo "$bad"; err "codex exec command without stdin closed (add < /dev/null)"; }

# 6. Every `git reset --pathspec-from-file` is guarded against an empty
#    list, which would unstage the whole index.
bad=$(grep -rnE '^[[:space:]]*git reset .*--pathspec-from-file' "$SKILLS" || true)
[ -z "$bad" ] || { echo "$bad"; err "unguarded git reset --pathspec-from-file"; }

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "all checks passed"
