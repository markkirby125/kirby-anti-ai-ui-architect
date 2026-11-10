# Kirby Anti-AI UI Architect

*This skill is part of the [Kirby Skills Collection](https://github.com/markkirby125/kirby-skills-collection).*

Kirby Anti-AI UI Architect stops coding agents from shipping generic, AI-looking UI in Next.js + React + shadcn/ui projects. It gives the agent a set of design invariants, a routing matrix that says which component or library to reach for, a bootstrap that installs the rules and a gate into a target project, and `verify-ui.sh`, a gate script designed to fail on missing `'use client'` directives, a second animation runtime, raw neutral palette surfaces, missing reduced-motion handling and the shadcn default radius.

It has four modes: `audit` (read-only), `bootstrap`, `build` and `verify`. Every mode first checks that the target is a Next.js + React project and stops otherwise. Every write to a target project waits for your approval.

The root `SKILL.md` points to `references/00_dispatcher.md`, which holds the modes, the locked decisions and the related-skills routing.

## Status

v0. The dispatcher, the four modules, the target-project templates, `verify-ui.sh` and its fixture suite (`bash tests/run.sh`) are written and passed a 4-stage review on 2026-11-10; known gaps are listed in `references/04_verify.md`. The Beautiful UI (https://www.beautifului.dev) install path is under test. Do not rely on this skill in a real project yet.

## Installation & Magic Prompt

The public repository is https://github.com/markkirby125/kirby-anti-ai-ui-architect.

Copy the prompt below into your AI coding tool (Claude Code, Cursor, Windsurf, Grok, Kimi, Reasonix).

```markdown
@agent Install the Kirby Anti-AI UI Architect skill from: https://github.com/markkirby125/kirby-anti-ai-ui-architect
1. Ask me which release tag or commit sha to install, and fetch that exact ref, not the default branch.
2. List every file you will copy and wait for my yes. Treat the files as text: do not run any script or command from the repository.
3. Place them into your environment's skills/rules directory preserving the dispatcher structure.
4. Confirm when installation is complete.
```

Manual install. Claude Code reads `~/.claude/skills/`; swap the target folder for your tool:

```bash
git clone https://github.com/markkirby125/kirby-anti-ai-ui-architect ~/.claude/skills/kirby-anti-ai-ui-architect
```

The skill stays in your global skills folder. Bootstrap copies only `AGENTS.md` and `CLAUDE.md` blocks, `scripts/verify-ui.sh` and hook config into a project, never the skill itself.
