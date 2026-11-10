<!-- kirby-anti-ai-ui:start -->
## UI rules (kirby-anti-ai-ui-architect)

Do not ship generic AI-looking UI. The gate is `bash scripts/verify-ui.sh`; run it before presenting UI work. The skill `kirby-anti-ai-ui-architect` holds the full rules and the routing table.

- Client boundaries: a file that uses hooks, `on*` handlers, `window`, `document`, `navigator`, `localStorage`, `sessionStorage`, `matchMedia(`, `toast(`, or imports `motion/react`, `vaul`, `cmdk`, `@number-flow/react` or `next-themes` starts with `'use client'` as its first statement. Server files use `motion/react-client`.
- One animation runtime: `motion`. Never add `framer-motion`, `gsap`, `lottie-*`, `react-spring` or `@react-spring/*`.
- Colour: semantic tokens only (`bg-background`, `bg-card`, `bg-muted`). No raw `bg-zinc-900`, `bg-slate-800` and friends outside `components/ui/`.
- Radius: set the project's own `--radius`. Never leave the shadcn default (`0.5rem` or `0.625rem`).
- Reduced motion: any animation needs a global `prefers-reduced-motion` handle, and `requestAnimationFrame` or `<canvas` files need their own guard.
- Tokens: Tailwind v3 uses HSL triplets plus `tailwind.config.ts`; Tailwind v4 uses `oklch(...)` plus `@theme inline` in `globals.css`. Detect the version first.
- Components: use shadcn (`sonner`, `drawer`, `command`) before hand-rolling. Run `npx shadcn@latest view <item>` before `add`, then the gate after.
- Install one package at a time with the project's package manager. No bulk installs.
- A false positive gets `// verify-ui-ignore UI00N` with a reason. Never use it to hide a real violation.
- `next build` is the authority for client boundaries.
<!-- kirby-anti-ai-ui:end -->
