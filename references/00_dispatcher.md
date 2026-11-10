# Anti-AI UI Architect: Dispatcher

Keeps coding agents from shipping generic, AI-looking UI in Next.js + React + shadcn/ui projects. It holds the design invariants, a component routing matrix, the steps to install those rules into a target project, and a deterministic gate script (`bin/verify-ui.sh`, copied to `<target>/scripts/verify-ui.sh`).

Announce use as: `Using kirby-anti-ai-ui-architect to <purpose>`.

Out of scope: Vite, CRA, Remix and Astro projects; machine-checking taste rules (palette ratios, font pairing); cleaning builder exports; writing a whole AGENTS.md; hiding AI authorship. The goal is UI quality, not detection evasion.

## Locked decisions

1. Beautiful UI is https://www.beautifului.dev, a shadcn-schema registry. Its `foundation` style is Tailwind v4 only and defines its own radii (6/8/10/14px). Install path under test, do not claim it works. On Tailwind v3 projects, route to `@prompt-kit` or `@assistant-ui` instead.
2. No vendoring. Bootstrap writes only `AGENTS.md`, `CLAUDE.md`, `scripts/verify-ui.sh`, the Stop hook in `.claude/settings.json` and the git hook (`.githooks/pre-push` plus `scripts.prepare` in `package.json`, or the pre-push step of an existing husky or lefthook setup) into the target. The optional CI workflow and the Beautiful UI foundation checklist (`03_bootstrap.md` 1f and section 2) write only after their own yes. The skill itself stays global.
3. The radius rule rejects the shadcn defaults only (`--radius: 0.5rem` or `0.625rem`). Other values are the project's choice.

## Step 0 in every mode: applicability check

Read the target's `package.json`. If `next` and `react` are not both in `dependencies` or `devDependencies`, reply "not applicable: kirby-anti-ai-ui-architect needs a Next.js + React project" and stop. Do not edit anything.

If there is no `app/` directory (at the root or under `src/`), the project is Pages Router only: RSC client-boundary rules do not apply. Say so and continue.

## Approval gate

Every write to a target project (files, `package.json`, hooks, `.claude/settings.json`, installs) needs the user's yes first. Show the exact diff or command, wait, then write. `audit` mode never writes. Do not run bulk `npm install`; add packages one routing row at a time with the package manager the lockfile indicates (`pnpm-lock.yaml`, `yarn.lock`, `bun.lock*`, else npm).

## Modes

Pick the mode from the request. If unclear, ask.

| Mode | When | Module | Writes? |
|---|---|---|---|
| `audit` | "check my UI", "is this AI-looking", review of an existing app | `04_verify.md` (run only) | Never |
| `bootstrap` | install the rules and gate into a project | `03_bootstrap.md` | Yes, after approval |
| `build` | UI work: new component, `shadcn add`, toast, drawer, command palette, animation, hero | `01_invariants.md` + `02_component_routing.md` | Yes, after approval |
| `verify` | after UI changes, before presenting work | `04_verify.md` | Fixes only after approval |

Module files live beside this dispatcher in `references/`. Read only the module the mode needs.

### audit

Run `bash scripts/verify-ui.sh --skip-tsc` in the target (or `bash <skill>/bin/verify-ui.sh --root <target> --skip-tsc` if the target has no copy). Output: the list of `FAIL UI00N <path>:<line>: <message>` findings grouped by check ID, the exit code, and a short note on what each check means. No edits, no installs.

### bootstrap

Follow `03_bootstrap.md`. Output: the proposed diff for each artefact (marked block in `AGENTS.md`, marked block plus `@AGENTS.md` in `CLAUDE.md`, `scripts/verify-ui.sh`, Stop hook in `.claude/settings.json`, git hook with its `package.json` `scripts.prepare` change), the approval prompt, then the applied changes and a gate run on the result. Bootstrap is idempotent: a second run replaces the marked blocks, never duplicates them. The CI template is optional and not installed by default.

### build

Read `01_invariants.md` and `02_component_routing.md`. Detect Tailwind v3 or v4 from `package.json` and `components.json` (an empty `tailwind.config` means v4). Preview registry items with `npx shadcn@latest view <item>` before `add`. Output: the change, the routing row used for each component, and a `verify` run before presenting.

### verify

Follow `04_verify.md`. Run the gate, fix findings in the order that module sets, re-run until exit 0. If the target copy of `verify-ui.sh` differs from `bin/verify-ui.sh`, report the drift and offer an update. Output: final gate result and the list of fixes. `next build` is the authority for client boundaries; recommend it as the CI step.

Exit codes from the gate: `0` clean, `1` violations, `2` usage or environment error (fix the environment, do not treat it as a pass).

## Related skills

| Situation | Use | Why this skill does not |
|---|---|---|
| Cleaning a Lovable, v0 or Bolt export, including repeated shadcn class strings | [kirby-ai-builder-hygiene](../../kirby-ai-builder-hygiene/SKILL.md) | Hygiene wins for export cleanup and class consolidation. This skill wins for new UI work and the gate. If both apply, run hygiene first, then `verify` here. |
| Contrast ratios, colour accessibility | [kirby-accessible-contrast](../../kirby-accessible-contrast/SKILL.md) | This skill checks semantic tokens, not contrast. |
| Generating or slimming a whole AGENTS.md | [kirby-agentmd-generation](../../kirby-agentmd-generation/SKILL.md) | Bootstrap only inserts one marked block. |
| Design critique, hierarchy, typography, visual polish | `impeccable` (separate skill, not in this repo) | Taste is guidance here, not a check. `impeccable` wins for critique; this skill wins for structural rules and the gate. |
