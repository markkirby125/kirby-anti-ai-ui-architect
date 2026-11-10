# 04 Verify

Run the gate, read the result, fix in order, re-run. Used by `verify` mode (fixes after approval) and `audit` mode (run only, no edits).

## Run

In the target project:

```bash
bash scripts/verify-ui.sh --skip-tsc     # fast: used by the Stop hook and audit
bash scripts/verify-ui.sh                # full: includes tsc, used by the git hook
```

If the target has no copy, run the skill's own: `bash <skill>/bin/verify-ui.sh --root <target> --skip-tsc`.

Flags: `--root DIR`, `--skip-tsc`, `--dirs "a b"` (relative to the root unless absolute; an absolute entry is used as given), `-h` (usage, exit 0). The gate writes nothing into the project (UI006 keeps the tsc build info in a temp dir it removes), uses no network and no `eval`, and works under paths with spaces.

## Read the result

| Exit | Meaning | Action |
|---|---|---|
| 0 | No violations | Done. Report it. |
| 1 | One or more `FAIL UI00N <path>:<line>: <message>` lines (UI001 and the UI004 loop check report the first hit per file, the global UI004 check the first hit per run) | Fix in the order below. |
| 2 | Usage or environment error (unknown argument, `--root` or `--dirs` without a value, no such directory for the root or a `--dirs` entry, no `package.json` or one that does not parse, not a Next.js + React project, node missing, `tsconfig.json` present but TypeScript not installed and no `--skip-tsc`, nothing to scan, an unreadable file or directory, no temp dir for UI006; a project with no `tsconfig.json` skips UI006 with a stderr note and is not an error) | Fix the environment. Never treat 2 as a pass. |

A clean run is not proof the project is good. The gate does not check taste rules, and a silent pass can mean the scan list was wrong; confirm the scanned dirs when the result surprises you.

## Fix order

1. **UI002** banned runtime: it changes dependencies, so fix it first. Replace with `motion`, remove the dep.
2. **UI001** client boundary: add the directive as the first statement, or move client logic into a small client leaf, or use `motion/react-client` in server files. For a legal directive-less leaf, add the pragma instead.
3. **UI003** raw palette: swap to semantic tokens.
4. **UI005, UI007** radius: set a project `--radius`; reconcile foundation radii.
5. **UI004** reduced motion: add the global handle, then per-file guards.
6. **UI006** types: fix the type errors.

Re-run after each group. Stop when the exit code is 0.

## Ignore pragma

`verify-ui-ignore UI00N` inside any comment (`//`, `/* */`, `{/* */}`) on the violating line or the line above. Several IDs may follow. For a legal directive-less hook module that would otherwise need a pragma on every hook call, put `verify-ui-ignore-file UI00N` anywhere in the file (a comment at the top is the usual place). The ID must match: `verify-ui-ignore-file UI002` does not silence UI001. UI006 findings take the pragma too: put it on the file and line `tsc` reports (or the line above), or use the file form; an unparsed `tsc` failure is reported at `tsconfig.json:1`. Use a pragma for a real false positive and say why in the same comment. Never use it to silence a real violation.

## Known limits

- UI001 is a line-based heuristic. It skips browser-global matches in a file that tests `typeof window`, `typeof document`, `typeof navigator`, `typeof localStorage`, `typeof sessionStorage` or `typeof matchMedia` anywhere (hooks and client imports there still count), test, spec, stories and `.d.ts` files, and a one-line `<Component onX={name}>` without an arrow function; `on*` props count only in `.tsx` and `.jsx` files. An `import type` or `export type { ... } from` statement is erased at compile time, so UI001, UI002 and UI004 skip it, on one line or over several when the `{` opens on the first line (`import type\n{` is not recognised: use a pragma). A direct dependency on a banned package is still caught from `package.json`. Browser globals count as bare names, after a spread or after `globalThis.` (`window.innerWidth`, `localStorage`, `[...window.frames]`, `globalThis.localStorage`); member access on another object (`obj.matchMedia(`, `this.navigator.userAgent`) is not flagged. Still a false positive: a directive-less leaf used only by client files, and a component tag split over several lines whose prop is a server action (use a pragma). False negatives: custom hooks that wrap client-only APIs, and strings or comments are not told apart from code. Node 21 and later define a global `navigator`, so a server file that reads `navigator.userAgent` runs but is still flagged: the rule targets browser APIs. `next build` is the authority for client boundaries; recommend it as the CI step.
- UI004's per-file guard needs `prefers-reduced-motion` or `useReducedMotion` in the file; a colour-scheme query does not count. A reduced-motion handle anywhere in the project counts as the global handle, even if it does not cover every animation. Vanilla `motion` and `motion/mini` imports count as animation.
- UI001 does not count a line that only defines a `toast` helper (`function toast(`, `const toast =`); a call such as `toast("x")` still counts. UI004's per-file animation flag skips `components/ui/` vendor files.
- The `components/ui/` vendor skip (UI003, and UI004's animation flag) covers only `components/ui/` under the detected base (the root or `src/`). A shadcn folder elsewhere, such as `packages/design/components/ui/` scanned with `--dirs packages/design`, is checked like project code, so a vendor `bg-zinc-900` there fails UI003. Workarounds: put `// verify-ui-ignore-file UI003` (add `UI004` if the file animates) at the top of each such vendor file, and add it again after `shadcn add --overwrite`; or run the gate with `--root packages/design`, which works only when that package's own `package.json` lists `next` and `react` (otherwise the gate exits 2).
- When a root `app/` or `pages/` exists next to `src/app` or `src/pages`, Next.js ignores the `src` tree, so the gate does too and prints a stderr note instead of passing silently. Move or delete one of the two layouts to get the `src` tree scanned. The mirror case: in a `src/` layout the gate scans `src/` only, so a root `components/`, `hooks/` or `lib/` is skipped with a stderr note (move it under `src/` or pass `--dirs`).
- An unreadable file or directory makes the gate exit 2 instead of passing. The directory check needs GNU find (`-readable`); elsewhere only unreadable files are caught.
- UI006 runs the checked repository's own `node_modules/.bin/tsc`. That is code from the target's dependencies, so run it only on projects you trust.
- With no global stylesheet (`components.json` `tailwind.css` or a standard `globals.css`), UI005 and UI007 are skipped with a stderr note.
- Accepted limits, each by design or not worth its cost; report one as a gate limit if it affects a result:
  - A pragma must follow `//` or `/*` on its line, so a string holding one of those plus the pragma still suppresses; telling strings from comments needs a parser.
  - UI001 misses aliased hooks (`useState as s`) and an `on*` prop at column 0, and UI002 misses a specifier split from its `from` across lines; Prettier never writes the last two, and `next build` catches the boundary errors.
  - UI001 misses optional chaining and bracket access on a browser global (`window?.innerWidth`, `window["innerWidth"]`): matching them without new false hits needs a parser, and the server render throws on them.
  - UI002 reads only `dependencies` and `devDependencies` and does not resolve npm aliases (`"x": "npm:framer-motion@11"`); an alias is a deliberate choice, not the default the rule exists to stop.
  - `.mdx` files are not scanned: their fenced code samples would be flagged, and the components they import are scanned.
  - Symlinked sources are skipped: following them risks loops and reads outside the root.
  - `@import` following stops after one quoted, relative level, and a commented-out radius token still counts: delete the dead line or add a pragma.
  - `"use client"` after `"use strict"` or followed by a comment on the same line, and a `'use server'` file that matches, need a pragma; all are rare.
  - A very long minified line makes UI003 slow: keep vendored minified files out of the scan dirs.
  - An absolute `--dirs` entry, `components.json` `tailwind.css` and a relative `@import` can read outside the root; this is read-only and the gate writes nothing.
  - The Stop hook passes the turn on gate exit 2 on purpose, so a broken environment cannot trap the agent in a loop; the git hook and CI still fail on it.
- Taste rules (palette ratio, font pairing, one standout per page) are not checked.

## Copy drift (R5)

The target holds a copy of the script with a `skill-sha` header. In `verify` mode compare it with the skill's copy:

```bash
diff <(sed 1,2d scripts/verify-ui.sh) <(sed 1,2d "<skill>/bin/verify-ui.sh") && echo same
```

If they differ, say so and offer to update the copy (an approval-gated write). The `skill-sha` line is the first comment line after the shebang, so the `sed` skips the shebang and that line.

## Recommended CI step

`bash scripts/verify-ui.sh && next build`. CI is the only layer `git commit --no-verify` or `git push --no-verify` cannot skip. The optional template is in `templates/` (see `03_bootstrap.md`); it is not installed by default.

## Output of verify mode

The final gate result (exit code and the violation list, or "0 violations"), the list of fixes made, anything pragma'd with the reason, and any copy drift found.
