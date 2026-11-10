#!/usr/bin/env bash
# Checks for the parts of the skill that tests/run.sh cannot reach: the bootstrap snippets in
# references/03_bootstrap.md (1c SHA header, 1e core.hooksPath) and templates/githooks/pre-push.
# The snippets are extracted from the doc and run as written, in throwaway repos under a temp dir.
# Usage: bash tests/hooks.sh        Exit: 0 all pass, 1 any fail.
set -u

S="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$S/references/03_bootstrap.md"
T="$(mktemp -d "${TMPDIR:-/tmp}/aaui hooks.XXXXXX")" || { echo "ERROR: mktemp failed" >&2; exit 1; }
trap 'rm -rf "$T"' EXIT INT TERM
# A global core.hooksPath on the dev machine must not leak into the checks.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

passed=0
failed=0
ok() { passed=$((passed + 1)); echo "PASS $1"; }
bad() { failed=$((failed + 1)); echo "FAIL $1: $2"; }

# block HEADING-PREFIX: the first bash fence after the heading, printed verbatim.
block() {
  awk -v h="$1" 'index($0, h) == 1 { f = 1; next } f && /^```bash/ { g = 1; next } g && /^```/ { exit } g { print }' "$DOC"
}

# ---- 1c: skill-sha header when the skill dir is not a git checkout (LOW: empty header) ----
fake="$T/skill"
mkdir -p "$fake/bin" "$T/proj1"
cp "$S/bin/verify-ui.sh" "$fake/bin/verify-ui.sh"
block "### 1c" | sed "s#<skill>#$fake#g" > "$T/1c.sh"
(cd "$T/proj1" && bash "$T/1c.sh" >/dev/null 2>&1)
hdr="$(sed -n 2p "$T/proj1/scripts/verify-ui.sh" 2>/dev/null)"
if [ "$hdr" = "# skill-sha: unknown" ]; then ok "1c-sha-not-a-git-checkout"; else bad "1c-sha-not-a-git-checkout" "line 2 was [$hdr]"; fi

# ---- 1e: core.hooksPath already points elsewhere (MED: silently switched off) ----
block "### 1e" | grep -v '^$' > "$T/1e.sh"
mk_repo() { rm -rf "$1" && mkdir -p "$1" && git -C "$1" init -q && printf '{\n  "name": "x"\n}\n' > "$1/package.json"; }

mk_repo "$T/proj2"
git -C "$T/proj2" config core.hooksPath .husky
before="$(cat "$T/proj2/package.json")"
(cd "$T/proj2" && bash "$T/1e.sh" >/dev/null 2>"$T/1e.err"); rc=$?
after="$(cat "$T/proj2/package.json")"
hp="$(git -C "$T/proj2" config --get core.hooksPath)"
if [ "$rc" -ne 0 ] && [ "$before" = "$after" ] && [ "$hp" = ".husky" ] && grep -q 'core.hooksPath is already' "$T/1e.err"; then
  ok "1e-existing-hookspath-refused"
else
  bad "1e-existing-hookspath-refused" "rc=$rc hooksPath=$hp package.json changed=$([ "$before" = "$after" ] && echo no || echo yes)"
fi

mk_repo "$T/proj3"
(cd "$T/proj3" && bash "$T/1e.sh" >/dev/null 2>&1); rc1=$?
(cd "$T/proj3" && bash "$T/1e.sh" >/dev/null 2>&1); rc2=$?
hp="$(git -C "$T/proj3" config --get core.hooksPath)"
if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ] && [ "$hp" = ".githooks" ] && grep -q '"prepare": "git config core.hooksPath .githooks"' "$T/proj3/package.json"; then
  ok "1e-fresh-and-idempotent"
else
  bad "1e-fresh-and-idempotent" "rc1=$rc1 rc2=$rc2 hooksPath=$hp"
fi

# ---- pre-push: exit 2 is an environment error, not findings (LOW: misleading message) ----
mk_repo "$T/proj4"
mkdir -p "$T/proj4/scripts"
printf '#!/usr/bin/env bash\nexit 2\n' > "$T/proj4/scripts/verify-ui.sh"
(cd "$T/proj4" && bash "$S/templates/githooks/pre-push" 2>"$T/pp2.err"); rc=$?
if [ "$rc" -eq 1 ] && grep -q 'could not run' "$T/pp2.err" && ! grep -q 'Fix the findings' "$T/pp2.err"; then
  ok "pre-push-exit2-message"
else
  bad "pre-push-exit2-message" "rc=$rc stderr=$(cat "$T/pp2.err")"
fi
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/proj4/scripts/verify-ui.sh"
(cd "$T/proj4" && bash "$S/templates/githooks/pre-push" 2>"$T/pp1.err"); rc=$?
if [ "$rc" -eq 1 ] && grep -q 'Fix the findings' "$T/pp1.err"; then
  ok "pre-push-exit1-message"
else
  bad "pre-push-exit1-message" "rc=$rc stderr=$(cat "$T/pp1.err")"
fi

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
