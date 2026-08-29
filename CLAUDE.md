# buidl-kit — contributor & maintenance guide

This repo **is** a Claude Code plugin. The commands operate on the *user's product repo*, not on this one — the only command that edits this repo's own files is `/kb-update` (it maintains `knowledge/`). See `README.md` for the user-facing tour; this file is for editing the kit itself.

## Naming (all three are load-bearing)
- **Repo:** `build-kit` (the GitHub repo / directory).
- **Plugin:** `buidl-kit` (in `.claude-plugin/plugin.json`; commands are namespaced `/buidl-kit:brief` etc.).
- **Marketplace:** `buidl-kit-marketplace` (in `.claude-plugin/marketplace.json`).

Don't "fix" the `build`/`buidl` split — both spellings are intentional and referenced in install instructions.

## Layout
```
.claude-plugin/   plugin.json + marketplace.json (manifests)
.mcp.json         declares the Solana Developer MCP (auto-configured on install)
commands/*.md     slash commands (11): brief, scout, build, debrief, ship, audit,
                  kb-update, doctor, handoff, burn, update
agents/*.md       subagents (6): repo-scout, {solana,evm}-security-auditor,
                  logic-explainer, latency-reviewer, test-gap-finder
skills/<name>/SKILL.md   skills (1): hackathon-build
knowledge/        the brain — every command/agent Reads these via ${CLAUDE_PLUGIN_ROOT}
samples/          intentionally-vulnerable fixtures (vulnerable-escrow=Anchor, vulnerable-vault=EVM)
scripts/          validate.sh (run before pushing)
```

## Frontmatter conventions
- **Commands** (`commands/*.md`): `description` + `argument-hint` always; add `allowed-tools` when the command needs a specific toolset (network/edit/bash) — omit it for the broad orchestrators (`brief`/`build`/`debrief`/`ship`) that use many tools.
- **Agents** (`agents/*.md`): `name` + `description` + `tools` + `model`. Model policy: `opus` for the two security auditors (depth matters most there); `sonnet` for `repo-scout`, `latency-reviewer`, `logic-explainer`, `test-gap-finder`.
- **Skills** (`skills/<name>/SKILL.md`): `name` + a folded (`>`) `description` that lists the trigger phrases (so the model auto-loads it). Plugin skills are also slash-invocable as `/buidl-kit:<name>`.
- Reference knowledge files with `${CLAUDE_PLUGIN_ROOT}/knowledge/...` so paths resolve wherever the plugin is installed — never a bare relative path.

## Knowledge-file rules
- YAML frontmatter: `title`, `description`, `applies_to`, `sources`, `last_verified`.
- **≤400 lines** per file. If one grows past, tighten old entries rather than let it balloon.
- Every claim carries a source URL; every change bumps `last_verified` to the day it was verified. `/kb-update` automates this.

## Local dev loop
```
/plugin marketplace add /path/to/build-kit    # reads the working tree, no commit needed
/plugin install buidl-kit@buidl-kit-marketplace
# edit files, then:
/reload-plugins                                # or restart the session
```

## Before pushing
1. `claude plugin validate .` — checks manifest + all frontmatter (needs Claude Code ≥ 2.1.233).
2. `bash scripts/validate.sh` — checks `${CLAUDE_PLUGIN_ROOT}` references resolve, knowledge files ≤400 lines, and reports stale `last_verified`.

## Releasing
`plugin.json` has **no `version` field on purpose** — the marketplace entry is unpinned, so installs track the latest commit on `main`. The whole release is:
```
git add -A && git commit -m "..." && git push
```
Users pull it via Claude Code's background refresh, `/buidl-kit:update`, or `/plugin marketplace update buidl-kit-marketplace` + `/reload-plugins`.
