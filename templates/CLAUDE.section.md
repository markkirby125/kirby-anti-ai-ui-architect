<!-- kirby-anti-ai-ui:start -->
## UI workflow (kirby-anti-ai-ui-architect)

Commands:
- Dev server: `npm run dev` (use the project's package manager)
- Types: `node_modules/.bin/tsc --noEmit`
- UI gate: `bash scripts/verify-ui.sh` (add `--skip-tsc` for a fast run)
- Add a shadcn item: `npx shadcn@latest add <item>` (preview first with `npx shadcn@latest view <item>`)

Workflow for any UI change:
1. Use the skill `kirby-anti-ai-ui-architect` (modes: audit, bootstrap, build, verify). Announce it.
2. Detect Tailwind v3 or v4 from `package.json` and `components.json` (`tailwind.config` empty means v4) before touching tokens.
3. Route each component through the skill's routing table. Do not hand-roll toasts, drawers or command palettes.
4. Run `bash scripts/verify-ui.sh` before presenting. Fix findings until it exits 0. Exit 2 is an environment error, not a pass.
5. Recommend `next build` as the final check for client boundaries.

The full rules are in `AGENTS.md`. The Stop hook in `.claude/settings.json` runs the gate after each turn.
<!-- kirby-anti-ai-ui:end -->
