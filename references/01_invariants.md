# 01 Invariants

The rules a Next.js + React + Tailwind + shadcn/ui project must hold. The target's `AGENTS.md` block (`templates/AGENTS.section.md`) is a short copy of this file; when they differ, this file wins. Each rule says whether `bin/verify-ui.sh` checks it (check ID) or whether it is guidance only.

## Checked rules (the gate fails on these)

### R1. Client boundaries (UI001)

- In the App Router, a file that uses client-only APIs needs `'use client'` as its first statement. Comments and blank lines may come before it; an import may not. A directive after an import is ignored by Next.js.
- Client-only means: hooks such as `useState`, `useEffect`, `useRef`, `useContext`, `useRouter`, `usePathname`, `useTheme`; a `toast(` call; imports from `motion/react`, `vaul`, `cmdk`, `@number-flow/react`, `next-themes`; browser globals (`window.innerWidth`, `document.body`, `localStorage`) in any file; and, in `.tsx` and `.jsx` files, JSX event props such as `onClick={...}`. Not flagged: browser globals in a file that tests `typeof window`, `typeof document` or `typeof localStorage` anywhere (an SSR-safe module; hooks and client imports in it still count), test, spec, stories and `.d.ts` files, and a one-line `<Editor onSave={saveAction} />` (a server action or plain value, not an arrow function).
- A server component that only needs animated markup imports `motion/react-client`. That import alone does not trigger UI001.
- Pages Router files (`pages/`) have no RSC rules. The gate skips them.
- shadcn wrappers (`sonner`, `drawer`, `command`) already carry the directive. Do not add it a second time.
- UI001 is a heuristic. A directive-less leaf imported only by client files is legal. Mark it with `// verify-ui-ignore UI001` (one line) or `// verify-ui-ignore-file UI001` (the whole file) instead of adding a directive that is not needed. `next build` is the authority.

### R2. One animation runtime (UI002)

- The runtime is `motion` (import from `motion/react`). Banned as a direct dependency or an import: `framer-motion`, `gsap`, `lottie-web`, `lottie-react`, `@lottiefiles/*`, `react-spring`, `@react-spring/*`.
- `motion` itself depends on `framer-motion`, so every lockfile lists it. The gate reads `package.json` direct dependencies and import specifiers, never a lockfile.
- A registry item that imports a banned runtime is rewritten to `motion` or rejected. Run `npx shadcn@latest view <item>` before `add`.

### R3. Semantic colour tokens (UI003)

- No raw neutral palette surfaces: `bg-slate-*`, `bg-gray-*`, `bg-zinc-*`, `bg-neutral-*`, `bg-stone-*` at 500 to 950, with any variant prefix and any opacity suffix.
- Use `bg-background`, `bg-card`, `bg-muted`, `bg-popover`, `bg-primary` and friends. Files under `components/ui/` are shadcn-owned and are not scanned.

### R4. Reduced motion (UI004)

- If the project animates (imports `motion/react` or `motion/react-client`, writes `@keyframes`, uses an `animate-*` class other than `animate-spin`, `animate-pulse` or `animate-none`, runs `requestAnimationFrame`, renders `<canvas`), it needs a global handle: `prefers-reduced-motion` in a `*.css` file, a `motion-reduce:` or `motion-safe:` class, `useReducedMotion`, or `<MotionConfig reducedMotion="user">`.
- Each file with `requestAnimationFrame` or `<canvas` also needs its own guard: `prefers-reduced-motion` (for example `matchMedia('(prefers-reduced-motion: reduce)')`) or `useReducedMotion`. A colour-scheme query does not count.

### R5. Radius (UI005, UI007)

- `--radius` in the global CSS must not be a shadcn default (`0.5rem` for v3 styles, `0.625rem` for v4 styles). Pick the project's own value. `0.2rem` and `1rem` are fine starting points; they are suggestions, not checks.
- Leftover Beautiful UI foundation radii (`--radius-chip`, `--radius-control`, `--radius-card`, `--radius-window`) in the global CSS fail UI007. Reconcile them with the project radius (see `02_component_routing.md`).

### R6. Types (UI006)

- `node_modules/.bin/tsc --noEmit` must pass. The gate never runs `npx tsc` (it can fetch an unrelated package). Skipped with `--skip-tsc`.

## Tailwind v3 and v4 token rules

Detect the version before touching tokens: `tailwindcss` in `package.json`, and `components.json` `tailwind.config` (an empty string means v4).

| Item | Tailwind v3 | Tailwind v4 |
|---|---|---|
| Token values | HSL triplets in `:root`, for example `--background: 0 0% 100%` | `oklch(...)` values in `:root` |
| Token wiring | `tailwind.config.ts` `theme.extend.colors` | `@theme inline { --color-background: var(--background); }` in `globals.css` |
| Config file | `tailwind.config.ts` exists | none; `components.json` `tailwind.config` is `""` |
| Global CSS | `app/globals.css` with `@tailwind` directives | `@import "tailwindcss"` |

Never paste HSL into a v4 project or `oklch` into a v3 one. Read the values shadcn wrote at init and edit those.

## Guidance rules (not machine-checked)

- One standout per page: one hero treatment, one accent. Everything else is quiet.
- Palette ratio about 60 neutral, 30 secondary, 10 accent.
- Two type families at most, with a clear scale. No gradient text on body copy.
- Spacing on a scale (4px base). No nested cards, no uniform rounded-everything.
- Motion has a reason: it shows state change or hierarchy. Decoration loops are cut.
- Real content states: empty, loading, error. No lorem ipsum, no stock gradient blobs.
- Critique and polish: use `impeccable` (separate skill). Contrast ratios: `kirby-accessible-contrast`.

## What this skill never does

It does not hide AI authorship. The goal is UI quality, not detection evasion.
