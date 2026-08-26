# buidl-kit

Reuse-first Claude Code plugin for shipping **production-grade crypto products in 6–12 hours**. Solana-primary, EVM-secondary. Its job is to make **find → evaluate → adapt proven code** the default, and to spend your scarce attention on **verification** — security, latency, and the few things worth your eyeballs.

Six commands — **/brief → /scout → /build → /debrief → /ship**, plus **/kb-update** — backed by a curated `knowledge/` base (the brain) and six reusable subagents.

> Plugin commands are namespaced, so they appear as `/buidl-kit:brief`, `/buidl-kit:scout`, etc. (written as `/brief` … below for brevity).

## Install

From a Claude Code session — **from GitHub** (published):

```
/plugin marketplace add AaroneGeorge/build-kit
/plugin install buidl-kit@buidl-kit-marketplace
```

Or **from a local clone** (development):

```
/plugin marketplace add /Users/aarone/programs/claude/build-kit
/plugin install buidl-kit@buidl-kit-marketplace
```

Local installs need no git commit — Claude Code reads the working tree. Verify with `/plugin` (Installed tab); you'll see the `buidl-kit:*` commands in `/help`. After editing plugin files, run `/reload-plugins` or restart the session.

## 60-second cheatsheet — which command, when

| You have… | Run | You get |
|---|---|---|
| A rough idea | `/brief "<idea>"` | Batched tappable questions → `SPEC.md` + a scout-first build plan |
| A need or SPEC.md | `/scout "<need>"` | Ranked existing repos/SDKs to fork/import + a fork plan (appended to the reuse-index) |
| A confirmed SPEC.md | `/build SPEC.md` | Scout-first implementation, tests, devnet deploy → auto-chains `/debrief` |
| Freshly built code (or any repo/diff) | `/debrief [path]` | `DEBRIEF.md`: walkthrough, security, latency, test gaps, **the 5 to eyeball** |
| Something about to deploy | `/ship [path]` | Advisory gate: criticals loud at top (non-blocking) + deploy runbook |
| Stale knowledge | `/kb-update [reuse\|security\|all]` | Refreshed reuse-index + incident lessons, dated + sourced |

Typical flow: `/brief` → `/scout` → `/build` (chains `/debrief`) → `/ship`. Each also stands alone — `/debrief` and `/ship` run on any repo or diff.

## What's inside

- **`knowledge/`** — the brain. Each file ≤400 lines with front-matter (description, sources, last-verified):
  - `stack-defaults.md` — your locked stack + RPC/latency defaults (**edit this first**).
  - `solana/` — anchor idioms, Token-2022 traps, the tx-landing playbook, client patterns (@solana/kit).
  - `evm/` — Foundry + OZ/Solady + vuln patterns.
  - `security/` — Solana + EVM audit checklists, incident lessons, the `/ship` gate.
  - `latency/` — RPC/realtime + indexing/caching/Neon.
  - `testing/` — frameworks, the minimum matrix, per-archetype non-negotiables.
  - `reuse-index/` — **the crown jewel**: curated forkable/importable implementations per archetype (license, audit, maintenance, fork-vs-import).
  - `recipes/` — per-archetype "ship it in ~6h" playbooks (the consumer deposit/auction site is the flagship).
- **`commands/`** — the six slash commands above.
- **`agents/`** — `solana-security-auditor`, `evm-security-auditor`, `logic-explainer`, `latency-reviewer`, `test-gap-finder`, `repo-scout` (invoked by the commands; usable standalone).
- **`samples/vulnerable-escrow/`** — an intentionally vulnerable Anchor program for trying `/debrief` and `/ship` (see its `ANSWERS.md`).

## Try it (sanity check)

```
/debrief samples/vulnerable-escrow
```

Expect all five DEBRIEF sections and the seeded bugs — missing signer check, missing owner check, unchecked arithmetic — each reported with `file:line`. Then `/ship samples/vulnerable-escrow` surfaces them loudly without blocking.

## Editing the knowledge base

It's yours — edit any `knowledge/*.md`. Keep the front-matter (`description`, `sources`, `last_verified`) and the ≤400-line limit. `/scout` and `/kb-update` append to `reuse-index/` and re-stamp `last_verified` as they learn.

## Published

Live at **[github.com/AaroneGeorge/build-kit](https://github.com/AaroneGeorge/build-kit)** — install with the GitHub commands above. To ship updates:

```
cd /Users/aarone/programs/claude/build-kit
git add -A && git commit -m "your message"
git push
```

Users pull updates with `/plugin marketplace update buidl-kit-marketplace`.

> The plugin lives in its own folder (`build-kit/`) with its own git repo, fully separate from your product projects (`NFA/` etc.). `.gitignore` covers build artifacts and secrets.

## License

MIT — see [`LICENSE`](./LICENSE), © 2026 Aarone George. Knowledge files cite their sources; check each cited repo's own license before forking its code.
