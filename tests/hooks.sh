#!/usr/bin/env bash
# Checks for the parts of the skill that tests/run.sh cannot reach: the bootstrap snippets in
# references/03_bootstrap.md (1c SHA header, 1e core.hooksPath), templates/githooks/pre-push, the Stop hook in
# templates/claude-settings.stop-hook.json, the at= checks of tests/run.sh itself, and a gate case a fixture cannot
# hold (an absolute components.json tailwind.css path).
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
# sha1c SKILL PROJ: makes SKILL/bin/verify-ui.sh, runs the 1c snippet for SKILL in a new PROJ, prints line 2 of the copy.
sha1c() {
  mkdir -p "$1/bin" "$2"
  [ -f "$1/bin/verify-ui.sh" ] || cp "$S/bin/verify-ui.sh" "$1/bin/verify-ui.sh"
  block "### 1c" | sed "s#<skill>#$1#g" > "$T/1c.sh"
  (cd "$2" && bash "$T/1c.sh" >/dev/null 2>&1)
  sed -n 2p "$2/scripts/verify-ui.sh" 2>/dev/null
}
commit() { git -C "$1" add -A && git -C "$1" -c user.name=x -c user.email=x@example.invalid commit -qm x; }
hdr="$(sha1c "$T/skill" "$T/proj1")"
if [ "$hdr" = "# skill-sha: unknown" ]; then ok "1c-sha-not-a-git-checkout"; else bad "1c-sha-not-a-git-checkout" "line 2 was [$hdr]"; fi

# ---- 1c: git -C searches upward, so only a skill dir at the top of its own repo records a SHA (LOW) ----
own="$T/own skill"
mkdir -p "$own/bin" && cp "$S/bin/verify-ui.sh" "$own/bin/verify-ui.sh" && git -C "$own" init -q && commit "$own"
sha="$(git -C "$own" rev-parse --short HEAD)"
hdr="$(sha1c "$own" "$T/proj1b")"
touch "$own/new-file"
hdr2="$(sha1c "$own" "$T/proj1c")"
if [ "$hdr" = "# skill-sha: $sha" ] && [ "$hdr2" = "# skill-sha: $sha-dirty" ]; then ok "1c-sha-own-repo"; else bad "1c-sha-own-repo" "clean [$hdr] dirty [$hdr2] want $sha"; fi
outer="$T/outer"
mkdir -p "$outer" && git -C "$outer" init -q && touch "$outer/x" && commit "$outer" && touch "$outer/y"
hdr="$(sha1c "$outer/vendor/skill" "$T/proj1d")"
if [ "$hdr" = "# skill-sha: unknown" ]; then ok "1c-sha-nested-in-other-repo"; else bad "1c-sha-nested-in-other-repo" "line 2 was [$hdr]"; fi

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

# ---- Stop hook: exit 2 only for gate findings (exit 1); stop_hook_active, env errors and no gate pass ----
cmd="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).hooks.Stop[0].hooks[0].command)' "$S/templates/claude-settings.stop-hook.json")"
P="$T/proj5"
mkdir -p "$P/scripts" "$T/proj6"
cat > "$P/scripts/verify-ui.sh" <<'EOF'
echo "$*" > gate-args
echo "FAIL UI001 src/x.ts:1: stub finding"
exit "${STUB_RC:-0}"
EOF
# hook DIR STUB_RC PAYLOAD: runs the command from another dir under bash and sh (dash on Debian); prints "bash:RC sh:RC ".
hook() {
  for sh in bash sh; do
    rm -f "$1/gate-args"
    (cd "$T" && printf '%s' "$3" | STUB_RC=$2 CLAUDE_PROJECT_DIR="$1" "$sh" -c "$cmd" >/dev/null 2>"$T/stop-$sh.err")
    printf '%s:%s ' "$sh" "$?"
  done
}
r="$(hook "$P" 1 '{"session_id":"s","stop_hook_active":true}')"
if [ "$r" = "bash:0 sh:0 " ] && [ ! -f "$P/gate-args" ]; then ok "stop-hook-active-skips-gate"; else bad "stop-hook-active-skips-gate" "$r"; fi
r="$(hook "$P" 1 '{"session_id":"s","stop_hook_active":false}')"
if [ "$r" = "bash:2 sh:2 " ] && grep -qF 'FAIL UI001 src/x.ts:1: stub finding' "$T/stop-bash.err" && grep -qF 'FAIL UI001 src/x.ts:1: stub finding' "$T/stop-sh.err"; then
  ok "stop-hook-findings-exit2"
else
  bad "stop-hook-findings-exit2" "$r stderr=$(cat "$T/stop-sh.err")"
fi
r="$(hook "$P" 2 '{"stop_hook_active":false}')"
if [ "$r" = "bash:0 sh:0 " ]; then ok "stop-hook-env-error-passes"; else bad "stop-hook-env-error-passes" "$r"; fi
r="$(hook "$P" 0 '{"stop_hook_active":false}')"
if [ "$r" = "bash:0 sh:0 " ] && [ "$(cat "$P/gate-args" 2>/dev/null)" = "--skip-tsc" ]; then ok "stop-hook-clean-skip-tsc"; else bad "stop-hook-clean-skip-tsc" "$r args=[$(cat "$P/gate-args" 2>/dev/null)]"; fi
r="$(hook "$T/proj6" 1 '{"stop_hook_active":false}')"
if [ "$r" = "bash:0 sh:0 " ]; then ok "stop-hook-no-gate"; else bad "stop-hook-no-gate" "$r"; fi

# ---- gate: an absolute components.json tailwind.css is used as given (LOW: UI005 and UI007 skipped) ----
# Fixtures are copied to a temp dir by tests/run.sh, so a fixed absolute path cannot live in tests/fixtures.
A="$T/proj7"
cp -R "$S/tests/fixtures/fail-radius-default/project" "$A"
mv "$A/src/app/globals.css" "$A/src/app/brand.css"
printf '{ "tailwind": { "css": "%s/src/app/brand.css" } }\n' "$A" > "$A/components.json"
bash "$S/bin/verify-ui.sh" --root "$A" --skip-tsc > "$T/abs.out" 2>&1; rc=$?
if [ "$rc" -eq 1 ] && grep -qF 'FAIL UI005 src/app/brand.css:4:' "$T/abs.out" && ! grep -q 'no global stylesheet' "$T/abs.out"; then
  ok "gate-absolute-tailwind-css"
else
  bad "gate-absolute-tailwind-css" "rc=$rc $(head -n 1 "$T/abs.out")"
fi

# ---- tests/run.sh: at= lines pin the path and line of each finding ----
# A copy of the runner reads the fixtures beside it, so the cases live in the temp dir. The fake gate prints $T/gate.out.
R="$T/runner"
mkdir -p "$R/tests/fixtures/pinned/project" "$R/tests/fixtures/unpinned/project"
cp "$S/tests/run.sh" "$R/tests/run.sh"
printf 'exit=1\nids=UI001\nat=UI001 src/my card.tsx:4\n' > "$R/tests/fixtures/pinned/EXPECT"
printf 'exit=1\nids=UI001\n' > "$R/tests/fixtures/unpinned/EXPECT"
printf '#!/usr/bin/env bash\ncat "%s"\nexit 1\n' "$T/gate.out" > "$T/fake-gate.sh"
# runner CASE GATE-OUTPUT: runs the copied runner on one case; sets rc, output in $T/runner.out.
runner() { printf '%s\n' "$2" > "$T/gate.out"; VERIFY_UI_BIN="$T/fake-gate.sh" bash "$R/tests/run.sh" "$1" > "$T/runner.out" 2>&1; rc=$?; }
runner pinned 'FAIL UI001 src/my card.tsx:4: msg'
if [ "$rc" -eq 0 ]; then ok "runner-at-match"; else bad "runner-at-match" "rc=$rc $(head -n 1 "$T/runner.out")"; fi
runner pinned 'FAIL UI001 src/my card.tsx:5: msg'
if [ "$rc" -eq 1 ] && grep -q '^FAIL pinned' "$T/runner.out"; then ok "runner-at-wrong-line"; else bad "runner-at-wrong-line" "rc=$rc"; fi
runner pinned "$(printf 'FAIL UI001 src/my card.tsx:4: msg\nFAIL UI001 src/card.tsx:4: msg')"
if [ "$rc" -eq 1 ] && grep -q '^FAIL pinned' "$T/runner.out"; then ok "runner-at-extra-path"; else bad "runner-at-extra-path" "rc=$rc"; fi
runner unpinned 'FAIL UI001 src/x.ts:1: msg'
if [ "$rc" -eq 2 ] && grep -q '^ERROR unpinned' "$T/runner.out"; then ok "runner-at-required"; else bad "runner-at-required" "rc=$rc"; fi

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
