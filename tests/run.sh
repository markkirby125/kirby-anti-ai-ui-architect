#!/usr/bin/env bash
# Fixture runner for bin/verify-ui.sh.
# Usage: bash tests/run.sh [case-glob]   (default: all cases)
# Env:   VERIFY_UI_BIN overrides the gate path (used to test the runner itself).
# Exit:  0 all selected cases pass, 1 any case fails, 2 runner error.
set -u

S="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="$S/tests/fixtures"
GATE="${VERIFY_UI_BIN:-$S/bin/verify-ui.sh}"
PATTERN="${1:-*}"

if [ ! -f "$GATE" ]; then
  echo "ERROR: gate not found: $GATE" >&2
  exit 2
fi

# The space in the temp dir name catches unquoted paths in the gate.
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/verify ui.XXXXXX")" || { echo "ERROR: mktemp failed" >&2; exit 2; }
# Fixtures with an unreadable.in file are chmod 000 at run time, so permissions come back before the cleanup.
trap 'chmod -R u+rwx "$TMPROOT" 2>/dev/null; rm -rf "$TMPROOT"' EXIT INT TERM

passed=0
failed=0
errors=0
matched=0

norm_ids() { tr ',' '\n' | sed '/^[[:space:]]*$/d' | sort -u | paste -sd, -; }

for dir in "$FIXTURES"/$PATTERN/; do
  [ -d "$dir" ] || continue
  matched=$((matched + 1))
  case_name="$(basename "$dir")"
  expect_file="$dir/EXPECT"
  if [ ! -f "$expect_file" ] || [ ! -d "$dir/project" ]; then
    echo "ERROR $case_name: missing EXPECT or project/"
    errors=$((errors + 1))
    continue
  fi

  exp_exit="$(sed -n 's/^exit=//p' "$expect_file" | head -n 1)"
  exp_ids="$(sed -n 's/^ids=//p' "$expect_file" | head -n 1 | norm_ids)"
  raw_args="$(sed -n 's/^args=//p' "$expect_file" | head -n 1)"
  if [ -z "$exp_exit" ]; then
    echo "ERROR $case_name: EXPECT has no exit= line"
    errors=$((errors + 1))
    continue
  fi
  args=()
  if [ -z "$raw_args" ]; then
    args=(--skip-tsc)
  elif [ "$raw_args" != "NONE" ]; then
    read -r -a args <<< "$raw_args"
  fi

  work="$TMPROOT/$case_name/project"
  mkdir -p "$TMPROOT/$case_name"
  cp -R "$dir/project" "$work"
  # Fixtures cannot ship real node_modules/.next dirs, so they carry stand-ins.
  [ -d "$work/node_modules.in" ] && mv "$work/node_modules.in" "$work/node_modules"
  [ -d "$work/dot-next.in" ] && mv "$work/dot-next.in" "$work/.next"
  # unreadable.in lists project-relative paths to chmod 000 (git cannot store that mode). Not run as root: root reads anyway.
  if [ -f "$work/unreadable.in" ]; then
    if [ "$(id -u)" = 0 ]; then echo "SKIP $case_name: running as root"; continue; fi
    while IFS= read -r p; do [ -n "$p" ] && chmod 000 "$work/$p"; done < "$work/unreadable.in"
    rm -f "$work/unreadable.in"
  fi

  out="$(bash "$GATE" --root "$work" ${args[@]+"${args[@]}"} 2>&1)"
  code=$?
  act_ids="$(printf '%s\n' "$out" | grep -oE '^FAIL UI[0-9]+' | awk '{print $2}' | sort -u | paste -sd, -)"

  if [ "$code" = "$exp_exit" ] && [ "$act_ids" = "$exp_ids" ]; then
    echo "PASS $case_name"
    passed=$((passed + 1))
  else
    echo "FAIL $case_name: expected exit=$exp_exit ids=[$exp_ids], got exit=$code ids=[$act_ids]"
    printf '%s\n' "$out" | head -n 10 | sed 's/^/    | /'
    failed=$((failed + 1))
  fi
done

if [ "$matched" -eq 0 ]; then
  echo "ERROR: no fixtures match '$PATTERN' in $FIXTURES" >&2
  exit 2
fi

echo "$passed passed, $failed failed"
[ "$errors" -gt 0 ] && exit 2
[ "$failed" -gt 0 ] && exit 1
exit 0
