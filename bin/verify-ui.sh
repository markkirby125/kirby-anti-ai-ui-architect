#!/usr/bin/env bash
# skill-sha: unreleased
# verify-ui.sh: read-only UI gate for Next.js / React + shadcn/ui projects.
#
# Usage: bash verify-ui.sh [--root DIR] [--skip-tsc] [--dirs "a b"]
#   --root DIR    project root holding package.json (default: .)
#   --skip-tsc    skip UI006 (type check)
#   --dirs "a b"  scan these dirs (relative to ROOT unless absolute, space separated) instead of
#                 the existing members of app pages components hooks lib under
#                 BASE (ROOT/src when it holds app, pages or components and ROOT
#                 has no app/ or pages/, else ROOT plus src/components|hooks|lib)
#
# Exit codes:
#   0  no violations
#   1  one or more violations
#   2  usage or environment error: unknown argument, --root or --dirs without a
#      value, no such directory (ROOT or a --dirs entry), no package.json or one
#      node cannot parse, next or react not a direct dependency, node missing,
#      tsconfig.json present but TypeScript not installed and no --skip-tsc,
#      nothing to scan, an unreadable file or directory, no temp dir for UI006
#      (no tsconfig.json: UI006 is skipped with a stderr note, not an error)
#   -h or --help prints this usage and exits 0.
#
# Checks:
#   UI001  app-router file uses client-only APIs without a leading 'use client'
#   UI002  banned animation runtime (framer-motion, gsap, lottie, react-spring)
#   UI003  raw neutral palette background (bg-zinc-900 ...) outside components/ui/
#   UI004  animation without a reduced-motion handle (global, and per file for
#          requestAnimationFrame / <canvas)
#   UI005  shadcn default --radius (0.5rem or 0.625rem) in the global CSS
#   UI006  node_modules/.bin/tsc --noEmit fails
#   UI007  leftover Beautiful UI foundation radii (--radius-chip, -control,
#          -card, -window) in the global CSS
#
# Output: "FAIL UI00N <path>:<line>: <message>" per violation (path relative to
# ROOT), then "verify-ui: N violation(s)". UI001 and the UI004 loop check report
# the first hit per file, the global UI004 check the first hit per run.
# Ignore pragma: "verify-ui-ignore UI00N" inside any comment (//, /* */ or
# {/* */}) on the violating line or the line above. Several IDs may follow.
# File-level form: "verify-ui-ignore-file UI00N" anywhere in a file (for a legal
# directive-less hook module that would otherwise need a pragma on every line).
# The gate writes nothing into the project (UI006 sends the tsc build info to a temp dir it removes) and uses no network. Lockfiles are never read.
set -u
# No pipefail on purpose: "producer | grep -q" would fail on the producer's SIGPIPE.

usage() { sed -n '5,11p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "verify-ui: $*" >&2; exit 2; }

# ---------- arguments ----------
ROOT=.
SKIP_TSC=0
DIRS=""
DIRS_SET=0
while [ $# -gt 0 ]; do
  case $1 in
    --root) [ $# -ge 2 ] || die "--root needs a directory"; ROOT=$2; shift 2 ;;
    --root=*) ROOT=${1#--root=}; shift ;;
    --skip-tsc) SKIP_TSC=1; shift ;;
    --dirs) [ $# -ge 2 ] || die "--dirs needs a value"; DIRS=$2; DIRS_SET=1; shift 2 ;;
    --dirs=*) DIRS=${1#--dirs=}; DIRS_SET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $1" ;;
  esac
done

# ---------- environment ----------
[ -d "$ROOT" ] || die "no such directory: $ROOT"
ROOT=$(cd -- "$ROOT" && pwd) || die "cannot enter $ROOT"
[ -f "$ROOT/package.json" ] || die "no package.json in $ROOT"
command -v node >/dev/null 2>&1 || die "node not found on PATH"

DEPS=$(node -e '
  const p = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  for (const k of ["dependencies", "devDependencies"])
    for (const n of Object.keys(p[k] || {})) console.log(n);
' "$ROOT/package.json") || die "cannot parse $ROOT/package.json"

has_dep() { case $'\n'"$DEPS"$'\n' in *$'\n'"$1"$'\n'*) return 0 ;; esac; return 1; }

has_dep next && has_dep react || die "not a Next.js + React project (next and react must both be direct dependencies)"

TSC="$ROOT/node_modules/.bin/tsc"
if [ "$SKIP_TSC" = 0 ] && [ -f "$ROOT/tsconfig.json" ] && [ ! -x "$TSC" ]; then
  die "TypeScript missing (node_modules/.bin/tsc not found); install dependencies or pass --skip-tsc"
fi

# ---------- root discovery ----------
# Next.js uses a root app/ or pages/ and ignores src/app; shared src/ code is still scanned then.
BASE=$ROOT
EXTRA=()
if [ -d "$ROOT/app" ] || [ -d "$ROOT/pages" ]; then
  for d in components hooks lib; do
    [ -d "$ROOT/src/$d" ] && EXTRA+=("$ROOT/src/$d")
  done
  # Next.js ignores src/app and src/pages when a root app/ or pages/ exists, so the gate does too; say so instead of passing silently.
  if [ -d "$ROOT/src/app" ] || [ -d "$ROOT/src/pages" ]; then
    echo "verify-ui: root app/ or pages/ exists, so Next.js ignores src/app and src/pages; they are not scanned" >&2
  fi
elif [ -d "$ROOT/src/app" ] || [ -d "$ROOT/src/pages" ] || [ -d "$ROOT/src/components" ]; then
  BASE=$ROOT/src
  # The src layout scans only src/; say so when root-level shared dirs exist instead of passing silently.
  if [ "$DIRS_SET" != 1 ]; then
    for d in components hooks lib; do
      [ -d "$ROOT/$d" ] && echo "verify-ui: src/ layout in use, so root $d/ is not scanned (move it under src/ or pass --dirs)" >&2
    done
  fi
fi

SCAN=()
if [ "$DIRS_SET" = 1 ]; then
  # shortcut: --dirs splits on whitespace, so dir names with spaces need the default scan.
  read -r -a _dirs <<< "$DIRS"
  for d in ${_dirs[@]+"${_dirs[@]}"}; do
    case $d in /*) ;; *) d=$ROOT/$d ;; esac
    [ -d "$d" ] || die "--dirs: no such directory: $d"
    SCAN+=("$d")
  done
else
  for d in app pages components hooks lib; do
    [ -d "$BASE/$d" ] && SCAN+=("$BASE/$d")
  done
  SCAN+=(${EXTRA[@]+"${EXTRA[@]}"})
fi
[ "${#SCAN[@]}" -gt 0 ] || die "nothing to scan under $ROOT"

APP_ROUTER=0
[ -d "$BASE/app" ] && has_dep next && APP_ROUTER=1

GLOBAL_CSS=""
if [ -f "$ROOT/components.json" ]; then
  css=$(node -e '
    try {
      const c = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
      if (c.tailwind && typeof c.tailwind.css === "string") console.log(c.tailwind.css);
    } catch (e) {}
  ' "$ROOT/components.json")
  case $css in /*) ;; *) css=$ROOT/$css ;; esac
  [ -f "$css" ] && GLOBAL_CSS=$css
fi
if [ -z "$GLOBAL_CSS" ]; then
  for c in "$BASE/app/globals.css" "$BASE/styles/globals.css" "$ROOT/src/app/globals.css" \
           "$ROOT/src/styles/globals.css" "$ROOT/app/globals.css" "$ROOT/styles/globals.css"; do
    [ -f "$c" ] && { GLOBAL_CSS=$c; break; }
  done
fi
[ -n "$GLOBAL_CSS" ] || echo "verify-ui: no global stylesheet found, UI005 and UI007 skipped" >&2

# Global CSS plus the local files it @imports (Beautiful UI ships its foundation as one).
# shortcut: one level deep, relative "./" or "../" paths only.
GLOBAL_FILES=()
if [ -n "$GLOBAL_CSS" ]; then
  GLOBAL_FILES=("$GLOBAL_CSS")
  while IFS= read -r imp; do
    imp=$(dirname "$GLOBAL_CSS")/${imp#./}
    case " ${GLOBAL_FILES[*]} " in *" $imp "*) continue ;; esac
    [ -f "$imp" ] && GLOBAL_FILES+=("$imp")
  done < <(sed -nE "s#^[[:space:]]*@import[[:space:]]+(url\\()?['\"](\\.\\.?/[^'\"]+)['\"].*#\\2#p" "$GLOBAL_CSS")
fi

# Source (SRC) and stylesheet (CSS) files under the scan dirs.
# node_modules, .next, .turbo and .vercel are pruned at any depth. out, dist, build and coverage are skipped only
# directly under ROOT, because a route folder such as app/build is real source.
SRC=()
CSS=()
for d in ${SCAN[@]+"${SCAN[@]}"}; do
  # An unreadable directory or file is a gate error, never a pass.
  # shortcut: the directory check needs GNU find (-readable); elsewhere only unreadable files are caught.
  bad=$(find "$d" \( -type d \( -name node_modules -o -name .next -o -name .turbo -o -name .vercel \) \) -prune -o \
      -type d ! -readable -print -quit 2>/dev/null)
  [ -z "$bad" ] || die "cannot read directory: $bad"
  while IFS= read -r -d '' f; do
    case ${f#"$ROOT"/} in out/*|dist/*|build/*|coverage/*) continue ;; esac
    [ -r "$f" ] || die "cannot read file: $f"
    case $f in *.css) CSS+=("$f") ;; *) SRC+=("$f") ;; esac
  done < <(find "$d" \( -type d \( -name node_modules -o -name .next -o -name .turbo -o -name .vercel \) \) -prune -o \
      -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
      -o -name '*.mjs' -o -name '*.cjs' -o -name '*.css' \) -print0)
done

# ---------- reporting ----------
VIOL=()

# is_ignored FILE LINE ID: pragma on LINE or LINE-1.
is_ignored() {
  local from=$(( $2 > 1 ? $2 - 1 : 1 ))
  sed -n "${from},${2}p" "$1" 2>/dev/null | grep -qE "(//|/\\*).*verify-ui-ignore([[:space:],]+UI[0-9]+)*[[:space:],]+$3([^0-9]|\$)"
}

# fail ID FILE LINE MESSAGE: record unless ignored; returns 1 when ignored.
fail() {
  grep -qE "(//|/\\*).*verify-ui-ignore-file([[:space:],]+UI[0-9]+)*[[:space:],]+$1([^0-9]|\$)" "$2" 2>/dev/null && return 1
  if [ "$3" -gt 0 ] && is_ignored "$2" "$3" "$1"; then return 1; fi
  VIOL+=("FAIL $1 ${2#"$ROOT"/}:$3: $4")
}

Q="['\"]"
B='(^|[^A-Za-z0-9_$])'
# Browser globals only: a name after "." is a member of another object (obj.matchMedia, this.navigator), except after a spread or globalThis.
BG='(^|[^A-Za-z0-9_$.]|\.\.\.|globalThis\.)'

# ---------- UI001 ----------
HOOKS='useState|useEffect|useLayoutEffect|useReducer|useRef|useContext|useTransition|useOptimistic|useActionState|useAnimate|useInView|useScroll|useSpring|useTransform|useMotionValue|useReducedMotion|useTheme|useRouter|usePathname|useSearchParams|useParams|useSelectedLayoutSegments?|useSyncExternalStore|useImperativeHandle|useDeferredValue|useInsertionEffect|useFormStatus|createContext'
HOOK_RE="${B}(${HOOKS})[[:space:]]*[(<]"
TOAST_RE="${B}toast(\\.[A-Za-z]+)?[[:space:]]*\\("
# A line that only defines a toast helper (function toast(, const toast =) is not a toast call.
TOAST_DEF_RE="(function|const|let|var)[[:space:]]+toast[[:space:]]*[(=:]"
LIBIMPORT_RE="(from|import)[[:space:]]*${Q}(motion/react|vaul|cmdk|@number-flow/react|next-themes)${Q}"
# "import type" and "export type ... from" are erased at compile time: no 'use client' (UI001), no animation (UI004).
# shortcut: one-line statements only; a multi-line "import type {" still flags its "from" line (use the pragma).
TYPE_IMPORT_RE="^[[:space:]]*(import|export)[[:space:]]+type[[:space:]]"
# "document. Then" is prose; a property access needs a name after the dot. matchMedia counts only as a call.
BROWSER_RE="${BG}(window|document|navigator)\\.[A-Za-z_\$]|${BG}(localStorage|sessionStorage)([^A-Za-z0-9_\$]|\$)|${BG}matchMedia[[:space:]]*\\("
ONPROP_RE="[[:space:]]on[A-Z][A-Za-z0-9]*=\\{"
# A one-line <Component onX={name}> passes a server action or plain data; only an arrow or function value is client-only.
# shortcut: tags split over several lines are still flagged; use the pragma for those.
COMPONENT_PROP_RE="<[A-Z][A-Za-z0-9._]*[[:space:]][^<]*on[A-Z][A-Za-z0-9]*=\\{[^}>]*\\}"
# Any on* prop on the line whose value is an arrow or function expression. COMPONENT_PROP_RE only sees the first
# prop and stops at a '>', so a server action beside an arrow prop (<E onSave={act} onCancel={() => x} />) needs this.
FUNC_PROP_RE="on[A-Z][A-Za-z0-9]*=\\{[[:space:]]*(async[[:space:]]+)?(function([[:space:]]|\\()|\\([^)]*\\)[[:space:]]*(:[^=]*)?=>|[A-Za-z_\$][A-Za-z0-9_\$]*[[:space:]]*=>)"
STRONG_RE="${HOOK_RE}|${TOAST_RE}|${LIBIMPORT_RE}"
# on* props only mean something in JSX files. Browser globals count in every file unless the file tests
# typeof window/document/navigator/localStorage/sessionStorage/matchMedia somewhere (see check_ui001): such a module is written to run on the server too.

# has_use_client FILE: first statement, after blank lines and comments, is a 'use client' directive.
has_use_client() {
  LC_ALL=C awk -v q="'" '
    {
      line = $0
      sub(/\r$/, "", line)
      if (NR == 1) sub(/^\357\273\277/, "", line)
      while (1) {
        if (inc) { i = index(line, "*/"); if (!i) { line = ""; break }; line = substr(line, i + 2); inc = 0; continue }
        sub(/^[ \t\r]+/, "", line)
        if (line == "" || substr(line, 1, 2) == "//") { line = ""; break }
        if (substr(line, 1, 2) == "/*") { inc = 1; line = substr(line, 3); continue }
        break
      }
      if (line == "") next
      ok = (line ~ ("^[\"" q "]use client[\"" q "]([ \t;]|$)"))
      exit
    }
    END { exit ok ? 0 : 1 }
  ' "$1"
}

# shortcut: line-based, ignores strings and comments, cannot see that a leaf is only imported by client files (use the pragma).
check_ui001() {
  [ "$APP_ROUTER" = 1 ] || return 0
  local f m line re strong bro
  for f in ${SRC[@]+"${SRC[@]}"}; do
    case $f in "$BASE/pages/"*|*.d.ts|*.test.*|*.spec.*|*.stories.*|*/__tests__/*) continue ;; esac
    has_use_client "$f" && continue
    # shortcut: one typeof guard anywhere exempts the whole file from the browser-global check (hooks and imports still count).
    if grep -qE 'typeof[[:space:]]+(window|document|navigator|localStorage|sessionStorage|matchMedia)' -- "$f"; then bro=""; else bro="|${BROWSER_RE}"; fi
    case $f in
      *.tsx|*.jsx) re="${STRONG_RE}${bro}|${ONPROP_RE}"; strong="${STRONG_RE}${bro}" ;;
      *) re="${STRONG_RE}${bro}"; strong=$re ;;
    esac
    while IFS= read -r m; do
      line=${m#*:}
      [[ $line =~ $TYPE_IMPORT_RE ]] && continue
      if [[ $line =~ $TOAST_DEF_RE ]]; then
        rest=$(printf '%s\n' "$line" | sed -E "s/$TOAST_DEF_RE//g")
        [[ $rest =~ $re ]] || continue
      fi
      if [[ $line =~ $COMPONENT_PROP_RE ]] && ! [[ $line =~ $FUNC_PROP_RE ]] && ! [[ $line =~ $strong ]]; then continue; fi
      fail UI001 "$f" "${m%%:*}" "client-only API without a leading 'use client' directive" && break
    done < <(grep -nE -e "$re" -- "$f")
  done
}

# ---------- UI002 ----------
BANNED='framer-motion|gsap|lottie-web|lottie-react|@gsap/[^'"'"'"/]+|@lottiefiles/[^'"'"'"/]+|react-spring|@react-spring/[^'"'"'"/]+'
DEP_RE="^(${BANNED})\$"
IMPORT_RE="(from|import|require)[[:space:]]*\\(?[[:space:]]*${Q}(${BANNED})(/[^'\"]*)?${Q}"

check_ui002() {
  local dep n f m
  while IFS= read -r dep; do
    [[ -n $dep && $dep =~ $DEP_RE ]] || continue
    n=$(grep -nF -e "\"$dep\"" -- "$ROOT/package.json" | head -n 1 | cut -d: -f1)
    fail UI002 "$ROOT/package.json" "${n:-1}" "banned animation runtime '$dep' is a direct dependency; use motion"
  done <<< "$DEPS"
  for f in ${SRC[@]+"${SRC[@]}"}; do
    while IFS= read -r m; do
      fail UI002 "$f" "${m%%:*}" "import of a banned animation runtime; use motion"
    done < <(grep -nE -e "$IMPORT_RE" -- "$f")
  done
}

# ---------- UI003 ----------
# Variants may carry brackets (data-[state=open]:, [&>*]:) or a group/peer name (group-hover/nav:), the important marker may lead (!bg-...), opacity may be [.35].
PAL_RE="(^|[[:space:]'\"\`])((\\[[^]]*\\]|[a-z0-9-]+(\\[[^]]*\\])?(/[A-Za-z0-9_-]+)?):)*!?bg-(slate|gray|zinc|neutral|stone)-(500|600|700|800|900|950)(/([0-9]+|\\[[^]]*\\]))?([^A-Za-z0-9/-]|\$)"

# shortcut: class-token regex, misses classes built from string pieces.
check_ui003() {
  local f m
  for f in ${SRC[@]+"${SRC[@]}"} ${CSS[@]+"${CSS[@]}"}; do
    case $f in "$BASE/components/ui/"*|"$ROOT/src/components/ui/"*) continue ;; esac
    while IFS= read -r m; do
      fail UI003 "$f" "${m%%:*}" "raw neutral palette background; use a semantic token (bg-background, bg-muted, bg-card)"
    done < <(grep -nE -e "$PAL_RE" -- "$f")
  done
}

# ---------- UI004 ----------
ANIM_CORE_RE="${Q}motion/react(-client)?${Q}|(from|import|require)[[:space:]]*\\(?[[:space:]]*${Q}motion(/mini)?${Q}|@keyframes|requestAnimationFrame|<canvas"
# prefers-reduced-motion counts as the global handle only in CSS, so a TS comment cannot satisfy it.
HANDLE_RE="motion-reduce:|motion-safe:|useReducedMotion|reducedMotion=(${Q}(user|always)${Q}|\\{)"
CSS_HANDLE_RE="prefers-reduced-motion|${HANDLE_RE}"
ANIM_CLASS_RE='(^|[^A-Za-z0-9_-])animate-(\[[^]]*\]|[a-z0-9-]+)'
LOOP_RE='requestAnimationFrame|<canvas'
LOOP_GUARD_RE='prefers-reduced-motion|useReducedMotion'

# is_anim_line TEXT: animation import, keyframes, rAF/canvas, or an animate-* class other than spin/pulse/none.
is_anim_line() {
  [[ $1 =~ $TYPE_IMPORT_RE ]] && return 1
  [[ $1 =~ $ANIM_CORE_RE ]] && return 0
  local rest=$1
  # The class must start a token: "tw-animate-css" (the shadcn v4 default import) is not an animate-* class.
  while [[ $rest =~ $ANIM_CLASS_RE ]]; do
    case ${BASH_REMATCH[2]} in spin|pulse|none) ;; *) return 0 ;; esac
    rest=${rest#*"${BASH_REMATCH[0]}"}
  done
  return 1
}

# shortcut: any handle anywhere counts as global; it does not prove the handle covers every animation.
check_ui004() {
  local files=() f m
  files=(${SRC[@]+"${SRC[@]}"} ${CSS[@]+"${CSS[@]}"})
  # The global CSS and its @imported files may sit outside the scan dirs; a handle in any of them counts.
  for f in ${GLOBAL_FILES[@]+"${GLOBAL_FILES[@]}"}; do
    case " ${CSS[*]-} " in *" $f "*) ;; *) files+=("$f") ;; esac
  done
  local handle=0 re
  for f in ${files[@]+"${files[@]}"}; do
    case $f in *.css) re=$CSS_HANDLE_RE ;; *) re=$HANDLE_RE ;; esac
    grep -qE -e "$re" -- "$f" && { handle=1; break; }
  done
  if [ "$handle" = 0 ]; then
    for f in ${files[@]+"${files[@]}"}; do
      # shadcn vendor files (animate-in, animate-out) are not the project's own animation; UI003 skips them too.
      case $f in "$BASE/components/ui/"*|"$ROOT/src/components/ui/"*) continue ;; esac
      while IFS= read -r m; do
        is_anim_line "${m#*:}" || continue
        fail UI004 "$f" "${m%%:*}" "animation without a global reduced-motion handle (prefers-reduced-motion CSS, motion-reduce:, useReducedMotion or MotionConfig reducedMotion)" && break 2
      done < <(grep -nE -e "${ANIM_CORE_RE}|animate-[a-z[]" -- "$f")
    done
  fi
  for f in ${SRC[@]+"${SRC[@]}"}; do
    grep -qE -e "$LOOP_RE" -- "$f" || continue
    grep -qE -e "$LOOP_GUARD_RE" -- "$f" && continue
    while IFS= read -r m; do
      fail UI004 "$f" "${m%%:*}" "requestAnimationFrame/<canvas loop without its own reduced-motion check (prefers-reduced-motion media query or useReducedMotion)" && break
    done < <(grep -nE -e "$LOOP_RE" -- "$f")
  done
}

# ---------- UI005 / UI007 ----------
check_ui005() {
  local f m
  for f in ${GLOBAL_FILES[@]+"${GLOBAL_FILES[@]}"}; do
    while IFS= read -r m; do
      fail UI005 "$f" "${m%%:*}" "--radius is a shadcn default (0.5rem/0.625rem); pick a brand radius"
    done < <(grep -nE -e '--radius[[:space:]]*:[[:space:]]*0?\.(5|625)0*rem' -- "$f")
  done
}

check_ui007() {
  local f m
  for f in ${GLOBAL_FILES[@]+"${GLOBAL_FILES[@]}"}; do
    while IFS= read -r m; do
      fail UI007 "$f" "${m%%:*}" "leftover Beautiful UI foundation radius; derive radii from the single --radius"
    done < <(grep -nE -e '--radius-(chip|control|card|window)[[:space:]]*:' -- "$f")
  done
}

# ---------- UI006 ----------
# Runs with cwd ROOT so tsc paths are ROOT-relative; the build info goes to a temp dir so the project gets no .tsbuildinfo.
check_ui006() {
  [ "$SKIP_TSC" = 1 ] && return 0
  if [ ! -f "$ROOT/tsconfig.json" ]; then
    echo "verify-ui: no tsconfig.json, UI006 skipped" >&2
    return 0
  fi
  if grep -qF '.next/types' "$ROOT/tsconfig.json" && [ ! -d "$ROOT/.next/types" ]; then
    echo "verify-ui: .next/types missing; run 'next typegen' or 'next build' if typed-route errors appear" >&2
  fi
  local out code line p parsed=0
  # --incremental false would abort on composite projects (TS6379), so the build info goes to a temp dir instead.
  local tmp
  tmp=$(mktemp -d) || die "cannot create a temp dir"
  out=$(cd "$ROOT" && ./node_modules/.bin/tsc --noEmit --incremental --tsBuildInfoFile "$tmp/tsc.buildinfo" --pretty false -p . 2>&1)
  code=$?
  rm -rf "${tmp:?}"
  [ "$code" -eq 0 ] && return 0
  while IFS= read -r line; do
    if [[ $line =~ ^(.+)\(([0-9]+),[0-9]+\):\ error\ (.*)$ ]]; then
      # tsc paths are ROOT-relative; fail() needs the file path to read a pragma from it.
      p=${BASH_REMATCH[1]}
      case $p in /*) ;; *) p=$ROOT/$p ;; esac
      fail UI006 "$p" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
      parsed=1
    fi
  done <<< "$out"
  [ "$parsed" = 1 ] || fail UI006 "$ROOT/tsconfig.json" 1 "tsc --noEmit exited $code${out:+: ${out%%$'\n'*}}"
}

# ---------- run ----------
check_ui001
check_ui002
check_ui003
check_ui004
check_ui005
check_ui006
check_ui007

for v in ${VIOL[@]+"${VIOL[@]}"}; do printf '%s\n' "$v"; done
echo "verify-ui: ${#VIOL[@]} violation(s)"
[ "${#VIOL[@]}" -eq 0 ] || exit 1
exit 0
