# 03 Bootstrap

Install the rules and the gate into a target project. Every write needs the user's yes after you show the exact diff or command. Bootstrap is idempotent: a second run replaces the marked blocks and never duplicates them. No vendoring: the skill itself is not copied into the target. No bulk `npm install`.

`<skill>` below is the skill directory (resolve it from this file's location). `<target>` is the project root.

## 0. Preconditions

1. Applicability check from the dispatcher passes (`next` and `react` in `package.json`).
2. The target is a git repo (`git -C <target> rev-parse --is-inside-work-tree`). If not, say so and ask before `git init`; do not commit.
3. Record the package manager from the lockfile: `pnpm-lock.yaml`, `yarn.lock`, `bun.lock` or `bun.lockb`, else npm.
4. Run `bash <skill>/bin/verify-ui.sh --root <target> --skip-tsc` first and show the baseline. Bootstrap does not fix existing violations; `verify` mode does.

## 1. Artefacts

Marker pair used in `AGENTS.md` and `CLAUDE.md`:

```text
<!-- kirby-anti-ai-ui:start -->
<!-- kirby-anti-ai-ui:end -->
```

### 1a. AGENTS.md

Insert or replace only the block from `templates/AGENTS.section.md`. Never overwrite the file. Run from `<target>`:

```bash
node -e '
const fs=require("fs");const [f,blk]=process.argv.slice(1);
const S="<!-- kirby-anti-ai-ui:start -->",E="<!-- kirby-anti-ai-ui:end -->";
let t=fs.existsSync(f)?fs.readFileSync(f,"utf8"):"";
const n=t.split(S).length-1, m=t.split(E).length-1;
if(n!==m||n>1){console.error("refusing: "+n+" start and "+m+" end markers in "+f);process.exit(2)}
const b=fs.readFileSync(blk,"utf8").trim();
const i=t.indexOf(S),j=t.indexOf(E);
if(n===1&&j>i) t=t.slice(0,i)+b+t.slice(j+E.length);
else if(n===1) {console.error("refusing: end marker before start in "+f);process.exit(2)}
else t=t+(t===""||t.endsWith("\n")?"":"\n")+(t===""?"":"\n")+b+"\n";
fs.writeFileSync(f,t)' AGENTS.md "<skill>/templates/AGENTS.section.md"
```

Post-condition: `grep -c 'kirby-anti-ai-ui:start' AGENTS.md` prints `1`. If the script refuses, show the marker problem to the user; do not repair by hand without asking.

### 1b. CLAUDE.md

Same snippet with `CLAUDE.md` and `templates/CLAUDE.section.md`. Then, only if `grep -Fxq '@AGENTS.md' CLAUDE.md` fails, add the line `@AGENTS.md` at the top of the file (Claude Code imports AGENTS.md through it). The block lists the commands (dev, `node_modules/.bin/tsc --noEmit`, `bash scripts/verify-ui.sh`, `npx shadcn@latest add <item>`) and the workflow.

### 1c. scripts/verify-ui.sh

```bash
mkdir -p scripts
SHA=$(git -C "<skill>" rev-parse --short HEAD)$([ -n "$(git -C "<skill>" status --porcelain)" ] && echo -dirty)
sed "2s/.*/# skill-sha: $SHA/" "<skill>/bin/verify-ui.sh" > scripts/verify-ui.sh
chmod +x scripts/verify-ui.sh
```

Line 2 of the script is the `skill-sha` header, so a later diff shows drift (see `04_verify.md`). If `scripts/verify-ui.sh` exists and differs, show the diff and ask before replacing it.

### 1d. Claude Code Stop hook

Merge `templates/claude-settings.stop-hook.json` into `.claude/settings.json`. The hook runs `bash scripts/verify-ui.sh --skip-tsc` at the end of each agent turn. On exit 1 it prints the findings to stderr and exits 2, which sends them back to Claude. It reads `stop_hook_active` from stdin and exits 0 when true, so it cannot loop. Environment errors (exit 2 from the gate) do not block the turn.

```bash
node -e '
const fs=require("fs");const [f,tpl]=process.argv.slice(1);
const cur=fs.existsSync(f)?JSON.parse(fs.readFileSync(f,"utf8")):{};
const add=JSON.parse(fs.readFileSync(tpl,"utf8"));
cur.hooks=cur.hooks||{};cur.hooks.Stop=cur.hooks.Stop||[];
const has=cur.hooks.Stop.some(g=>(g.hooks||[]).some(h=>/verify-ui\.sh/.test(h.command||"")));
if(!has)cur.hooks.Stop.push(...add.hooks.Stop);
fs.mkdirSync(require("path").dirname(f),{recursive:true});
fs.writeFileSync(f,JSON.stringify(cur,null,2)+"\n")' .claude/settings.json "<skill>/templates/claude-settings.stop-hook.json"
```

Existing settings keys are kept. Running it twice adds the hook once. If `.claude/settings.json` is not valid JSON the snippet throws; show the error and stop.

### 1e. Git hook (all agents and humans)

- If the project uses husky (`.husky/`) or lefthook (`lefthook.yml`), add `bash scripts/verify-ui.sh` to its pre-push step instead of the steps below, and tell the user which file you changed.
- Otherwise copy `templates/githooks/pre-push` to `.githooks/pre-push` (`chmod +x`) and set `scripts.prepare` in `package.json` to `git config core.hooksPath .githooks`:

```bash
node -e '
const fs=require("fs");const p=JSON.parse(fs.readFileSync("package.json","utf8"));
const cmd="git config core.hooksPath .githooks";
p.scripts=p.scripts||{};
if(!p.scripts.prepare)p.scripts.prepare=cmd;
else if(!p.scripts.prepare.includes(cmd)){console.error("prepare already set: "+p.scripts.prepare+" ; ask the user how to combine");process.exit(2)}
fs.writeFileSync("package.json",JSON.stringify(p,null,2)+"\n")' && git config core.hooksPath .githooks
```

The `&&` matters: when `prepare` is already set the script exits 2, and `core.hooksPath` must stay untouched (repointing it would silently switch off an existing husky or custom hook setup).

The git hook runs the full gate including tsc. `--no-verify` skips it; only CI closes that gap.

### 1f. CI (optional, not installed by default)

`templates/ci/verify-ui.yml` runs `bash scripts/verify-ui.sh` then `next build`. Offer it once; copy it to `.github/workflows/verify-ui.yml` only on a yes. Adjust the install step to the project's package manager.

## 2. Beautiful UI foundation checklist

Run this only if the user wants `foundation.css` wired in (`02_component_routing.md` explains the risks). The items work without it, only partly styled.

1. Tailwind v4 only. On v3, stop and route to `@prompt-kit` or `@assistant-ui`.
2. Check brace balance of the installed `foundation.css`: strip comments, count `{` and `}`, and compare. Upstream had a stray `}` near line 427 (verified 2026-11-10). Show the user the line before fixing it.
3. If the CSS has `@import "shadow-plugin/unprefixed"`, add the dependency (`shadow-plugin`, MIT) with the project's package manager, after approval.
4. Report token clashes before importing: `--accent`, `--color-accent`, `--font-sans`, `--font-mono`, a `body` rule, and the second radius scale (6, 8, 10, 14px). Ask whether to keep the project's values.
5. After import, run `next build` and the gate. UI007 flags leftover `--radius-chip|control|card|window`.

## 3. Verify the result

Run `bash scripts/verify-ui.sh --skip-tsc` in the target and show the result. A second run of this module must leave exactly one start marker per file and an unchanged diff.

## 4. Skill deployment paths

How the skill reaches each AI tool on this machine (symlink the skill directory into the tool's skills directory; skip a tool whose directory does not exist):

```bash
TARGET="${SKILL_DIR:?set SKILL_DIR to the directory that holds this skill}"
for d in ~/.gemini/config/skills ~/.cursor/skills ~/.codeium/windsurf/skills ~/.grok/skills \
         ~/.kimi-code/skills ~/.reasonix/skills ~/.claude/skills ~/.codex/skills ~/.agents/skills; do
  [ -d "$d" ] || continue
  # A real directory or file under that name (a vendored copy) is left alone: ln -sfn would nest the link inside it.
  if [ -e "$d/kirby-anti-ai-ui-architect" ] && [ ! -L "$d/kirby-anti-ai-ui-architect" ]; then
    echo "skip $d: kirby-anti-ai-ui-architect exists and is not a symlink; ask the user" >&2
    continue
  fi
  ln -sfn "$TARGET" "$d/kirby-anti-ai-ui-architect"
done
```

Check each link with `test -e "$d/kirby-anti-ai-ui-architect/SKILL.md"`.

Skill scan paths for Codex and Cursor, read from the tools' own docs on 2026-11-10 (neither page shows a date or a version for the skills feature):

| Tool | Project directory | User directory | Reads other tools' folders |
|---|---|---|---|
| Codex | `.agents/skills` in the working directory and in every parent up to the repo root | `$HOME/.agents/skills` (admins also have `/etc/codex/skills`) | Not stated. No `.claude/skills` or `.codex/skills` path is listed for skills. |
| Cursor | `.agents/skills/` and `.cursor/skills/` (nested ones anywhere in the repo too) | `~/.agents/skills/` and `~/.cursor/skills/` | Yes: `.claude/skills/`, `.codex/skills/`, `~/.claude/skills/` and `~/.codex/skills/` |

Sources: https://learn.chatgpt.com/docs/build-skills (Codex; `https://developers.openai.com/codex/skills` redirects there with a 308) and https://cursor.com/docs/context/skills. So `~/.codex/skills` is not a documented Codex skill path; `~/.agents/skills` is. Because Cursor reads several of these folders, the same skill can be found through more than one link; how Cursor treats duplicates is not documented, so check the skill list if a duplicate shows up. Vendoring into a target project is not done (locked decision 2); the project-level paths above are for reference only.
