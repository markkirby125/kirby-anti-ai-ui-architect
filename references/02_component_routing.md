# 02 Component Routing

Which component or library to use for each UI need. Install one row at a time, with the package manager the lockfile indicates (`pnpm-lock.yaml`, `yarn.lock`, `bun.lock*`, else npm). No bulk install. Do not pin versions from this file; run `npm view <pkg> version` when a version matters.

Before every `add`: preview with `npx shadcn@latest view <item>`. After every `add`: run the gate (see `04_verify.md`). Rules behind the rows are in `01_invariants.md`.

## Routing matrix

| Need | Use | Install | Notes |
|---|---|---|---|
| Toast, notification | shadcn `sonner` | `npx shadcn@latest add sonner` | Brings `sonner` and `next-themes`. Wrapper has the directive. Mount `<Toaster />` once in the root layout. |
| Bottom sheet, mobile drawer | shadcn `drawer` | `npx shadcn@latest add drawer` | Depends on `vaul`, which is unmaintained (last publish 2024-12). Code is owned in the repo, so breakage stays local. Risk R4. |
| Command palette, search | shadcn `command` | `npx shadcn@latest add command` | Brings `cmdk`. Wrapper has the directive. |
| Animated number | `@number-flow/react` | package manager add | Client-only. Needs the directive in the importing file. |
| Component animation | `motion` | package manager add | Import from `motion/react` in client files, `motion/react-client` in server files. Never `framer-motion` or `gsap`. |
| Hero or marketing effect | `@magicui/<item>` | `npx shadcn@latest add @magicui/<item>` | Registry healthy. Run `view` first; run the gate after (UI002 catches a banned runtime). |
| Decorative effect | `@aceternity/<item>` | `npx shadcn@latest add @aceternity/<item>` | Registry degraded: sampled items fail validation and may import `framer-motion`. Prefer Magic UI. Always `view` first. |
| AI interface primitives (loading state, streaming text, approval card, tool chips, diff table, code block) | Beautiful UI | `npx shadcn@latest add https://www.beautifului.dev/r/<item>.json` | Tailwind v4 only. See the section below. |
| AI chat UI on Tailwind v3, or if Beautiful UI fails | `@prompt-kit` or `@assistant-ui` | `npx shadcn@latest add @prompt-kit/<item>` | `@ai-elements` is degraded; last resort. |
| Dialog, dropdown, tabs, form controls | shadcn core | `npx shadcn@latest add <item>` | Do not hand-roll these. |

Item names change. If `view` fails for a name, list the registry (`npx shadcn@latest --help`, then the registry's own listing) and pick the closest item; do not invent names.

## Beautiful UI (https://www.beautifului.dev)

Verified 2026-11-10 on Next 16.4.6, Tailwind 4.3.3, shadcn 4.23.0. Tested items: `foundation`, `approval-card`, `tool-chips`, `loading-state`, `diff-table`, `streaming-text` (install and `tsc` pass). Not tested: the `registries` namespace form, Next 15, visual rendering, lint, the dev server, the other 21 items. Do not claim they work.

- **Tailwind v4 only.** On v3, route to `@prompt-kit` or `@assistant-ui`.
- **Files land in `components/primitives/`** (under `src/` when the project uses it), not in a custom `ai/` folder.
- **`foundation` is a CSS file nothing imports.** It lands at `<app dir>/beautifui/foundation.css`. Importing it as documented breaks `next build` for two upstream reasons: a stray `}` near line 427 (brace depth ends at -1) and `@import "shadow-plugin/unprefixed"` with no dependency declared (`shadow-plugin` exists on npm, MIT).
- **Token clashes on import.** `foundation.css` overrides shadcn `--accent`, `--color-accent`, `--font-sans`, `--font-mono` and restyles `body`. It adds a second radius scale (6, 8, 10, 14px) and the components carry about 20 hard-coded `rounded-[Npx]` values. UI007 flags the leftover `--radius-*` names; it does not flag the literals.
- **The components work without `foundation.css` only partly.** Visual result is untested.
- **`LoadingState` hard-codes an external Vercel Blob video URL.** Replace it or accept the external request.
- **Licence:** MIT, Copyright (c) 2026 Shane Levine. Keep the notice.

Before wiring `foundation.css` in, follow the checklist in `03_bootstrap.md` (brace balance, `shadow-plugin`, token clash report). If the user declines foundation, install the items alone and tell them the result is partly styled.

## Motion routing

- Client component: `import { motion } from "motion/react"`.
- Server component that only needs animated markup: `import * as motion from "motion/react-client"`.
- Vanilla `animate()` imported from `"motion"` or `"motion/mini"` is allowed and counts as animation for the gate, so it needs the reduced-motion handle too.
- Every animated project needs the global reduced-motion handle from `01_invariants.md` R4.

## After adding anything

1. Run `bash scripts/verify-ui.sh --skip-tsc`.
2. If UI002 fires, the item pulled a banned runtime. Rewrite to `motion` or drop the item.
3. If UI003 fires in a new file outside `components/ui/`, swap raw palette classes for semantic tokens.
4. Run the full gate (with tsc) before presenting.
