# buidl-kit

Reuse-first Claude Code plugin for shipping **production-grade crypto products in 6–12 hours**. Solana-primary, EVM-secondary. Its job is to make **find → evaluate → adapt proven code** the default, and to spend your scarce attention on **verification** — security, latency, and the few things worth your eyeballs.

Eleven commands, six subagents, a **hackathon-build** skill that kicks in when a deadline looms, and a curated `knowledge/` base (the brain) that every command reads.

> Plugin commands are namespaced — they appear as `/buidl-kit:brief`, `/buidl-kit:scout`, etc. (written `/brief` … below for brevity).

---

## Table of contents

- [Install](#install)
- [The philosophy](#the-philosophy)
- [Commands](#commands)
- [Cheatsheet — which command, when](#cheatsheet--which-command-when)
- [Hackathon mode](#hackathon-mode)
- [The agents (usable standalone)](#the-agents-usable-standalone)
- [The knowledge base](#the-knowledge-base)
- [Archetypes](#archetypes)
- [Try it — the vulnerable fixtures](#try-it--the-vulnerable-fixtures)
- [Files the commands write into your repo](#files-the-commands-write-into-your-repo)
- [Customizing](#customizing)
- [Guardrails and posture](#guardrails-and-posture)
- [Troubleshooting](#troubleshooting)
- [Publishing updates](#publishing-updates)
- [Contributing](#contributing)
- [License](#license)

---

## Install

From a Claude Code session — **from GitHub** (published):

```
/plugin marketplace add AaroneGeorge/build-kit
/plugin install buidl-kit@buidl-kit-marketplace
```

Or **from a local clone** (development — reads the working tree, no commit needed):

```
/plugin marketplace add /path/to/build-kit
/plugin install buidl-kit@buidl-kit-marketplace
```

Verify with `/plugin` (Installed tab); the `buidl-kit:*` commands appear in `/help`. After editing plugin files, run `/reload-plugins` or restart the session. Pull published updates with `/plugin marketplace update buidl-kit-marketplace` (or `/buidl-kit:update`).

The plugin declares the official **Solana Developer MCP** in `.mcp.json`, so on install Claude Code offers to connect it (free, no key — docs search + `program_autofixer`). Approve it and `/build` and `/debrief` use it automatically; `/doctor` tells you if it isn't connected.

**Where to run it:** the commands operate on *your product repo*, not on this one. Install once, then `cd` into whatever you're building. The only exception is `/kb-update`, which edits the plugin's own `knowledge/` files.

---

## The philosophy

~90% of what you need already exists publicly. So the default path is **find → evaluate → adapt** proven code, not generate it from scratch — and the bottleneck that's left is **verification**, not typing. Every command optimizes for one of those two things: locking reuse, or telling you exactly what to eyeball before funds are at risk. Devnet-first, always; gates are **advisory, never blocking** — criticals surface loudly, but you decide.

---

## Commands

The core flow is **`/brief` → `/scout` → `/build` → `/debrief` → `/ship`**; the rest stand alone. Each command's full behavior lives in its file under [`commands/`](./commands) — the source is the spec.

| Command | What it does | Writes |
|---|---|---|
| [`/brief`](./commands/brief.md) | Requirements interrogator — batched tappable questions, each round pushing one idea you didn't ask for, until it can restate the whole picture and you confirm. | `SPEC.md` |
| [`/scout`](./commands/scout.md) | The reuse engine — parallel `repo-scout` agents across the local index + GitHub/crates/npm/SDK docs; ranked forkable candidates scored on fit/maintenance/audit/license/effort. | appends to `reuse-index/` |
| [`/build`](./commands/build.md) | Orchestrator — scouts first, then builds in thin end-to-end vertical slices: each slice tested, committed `slice-N:`, and redeployed to devnet, so there's always a demoable state. Chains `/debrief`. | code, commits, devnet deploy |
| [`/debrief`](./commands/debrief.md) | Verify-while-you-learn — four reviewers in parallel, synthesized into five sections ending in **the 5 things to eyeball before deploy**. Runs on any repo or diff. | `DEBRIEF.md` |
| [`/audit`](./commands/audit.md) | Standalone security pass — the chain-matched auditor(s) on a path/diff *now*, criticals first, no spec or build history needed. `--deep` adds test-gap + invariant suggestions. | `AUDIT.md` |
| [`/ship`](./commands/ship.md) | Advisory pre-deploy gate — fresh security pass on the diff + the ship-gate checklist, criticals loud at the top (non-blocking), then a devnet-first deploy runbook. | — |
| [`/kb-update`](./commands/kb-update.md) | Keeps the brain fresh — parallel research refreshes the reuse-index and incident lessons, every change dated and sourced. | edits `knowledge/` |
| [`/doctor`](./commands/doctor.md) | Environment preflight — toolchain versions (esp. Anchor-vs-project), wallet, devnet SOL, RPC, boosters; PASS/WARN/FAIL with the exact fix command per row. | — |
| [`/handoff`](./commands/handoff.md) | Session state — a snapshot so a fresh session resumes in minutes. Env var **names** only, never values. | `STATE.md` |
| [`/burn`](./commands/burn.md) | Hackathon clock — elapsed vs. slices shipped, pace verdict, exactly what to cut or mock if behind. | `.buidl/clock.json` |
| [`/update`](./commands/update.md) | Self-updater — sync to latest `main` with a changelog; backs up your customized `knowledge/` edits first. `check` mode is read-only. | — |

---

## Cheatsheet — which command, when

| You have… | Run |
|---|---|
| A rough idea | `/brief "<idea>"` |
| A need or SPEC.md | `/scout "<need>"` |
| A confirmed SPEC.md | `/build SPEC.md` (chains `/debrief`) |
| Freshly built code (or any repo/diff) | `/debrief [path]` |
| A contract to security-review right now | `/audit [path] [--deep]` |
| Something about to deploy | `/ship [path]` |
| A hackathon deadline | say "hackathon" (or `/buidl-kit:hackathon-build`) |
| A fresh machine / flaky toolchain | `/doctor` |
| A session about to end | `/handoff` |
| Mid-sprint "are we on pace?" | `/burn` |
| A stale plugin install | `/update [check]` |

`/debrief`, `/audit`, and `/ship` each run standalone on any repo or diff — point them at an unfamiliar codebase to understand or vet it fast.

---

## Hackathon mode

Mention a hackathon, a submission deadline, or "ship by tonight" and Claude loads the [`hackathon-build`](./skills/hackathon-build/SKILL.md) skill (or call `/buidl-kit:hackathon-build` explicitly). It's the buidl-kit flow compressed against a wall clock: clock into `.buidl/clock.json` first, ruthless **build/mock/cut** triage (build only if judges touch it live or funds flow), one timeboxed scout for the core primitive, 2–4 vertical slices with the walking skeleton **deployed in hour one** and kept green, every shortcut landing on a scale-later seam, checkpoints at 50%/75%, and a non-negotiable 15-minute security floor on fund-moving files before submission.

---

## The agents (usable standalone)

The commands orchestrate these, but each is useful on its own — just ask for it by name ("use the solana-security-auditor on `programs/vault`"). All **return findings rather than writing files** unless you ask them to write. Full definitions in [`agents/`](./agents).

| Agent | Use it for |
|---|---|
| [`repo-scout`](./agents/repo-scout.md) | "Does this already exist?" Ranked forkable/importable candidates (≥5 for a well-known need) + a fork/adapt plan + an index delta. |
| [`solana-security-auditor`](./agents/solana-security-auditor.md) | Any Anchor/native Rust program or diff. Ranks entry points by blast radius, walks the 15-category checklist, proves-or-flags every `AccountInfo`/`UncheckedAccount`. |
| [`evm-security-auditor`](./agents/evm-security-auditor.md) | Any Solidity repo or diff. Slither/Aderyn first when installed, then access control → reentrancy → CEI → arithmetic → oracle → approvals → EIP-712 → upgradeability → DoS/MEV. |
| [`logic-explainer`](./agents/logic-explainer.md) | Understanding an unfamiliar crypto repo fast: architecture map, the 5–10 files that matter, invariants, where funds flow. |
| [`latency-reviewer`](./agents/latency-reviewer.md) | Slow apps and dropped transactions: hot paths, CU/priority fees/ALTs/retries, polling→push swaps, pooling, and where paying for speed is worth it. |
| [`test-gap-finder`](./agents/test-gap-finder.md) | "What must exist before this ships?" Missing non-negotiables and untested fund-flow paths, plus which invariants are worth fuzzing. |

Security auditors report each finding as **[SEVERITY] + `file:line` + issue + concrete exploit + the safe fix**, naming the exact Anchor constraint or OZ/Solady primitive — never "review access control."

---

## The knowledge base

`knowledge/` is the brain every command and agent reads. Each file is ≤400 lines and carries frontmatter (`title`, `description`, `applies_to`, `sources`, `last_verified`) so claims stay dated and sourced.

```
knowledge/
├── stack-defaults.md          ← edit this first: your locked stack + RPC/latency defaults + posture
├── solana/                    anchor-idioms · token-2022 · tx-landing · client-patterns
├── evm/                       foundry-and-patterns (Foundry + OZ/Solady + vuln patterns)
├── security/                  solana + evm audit checklists · incident-lessons · ship-gate-checklist
├── latency/                   rpc-and-realtime · indexing-caching-db
├── testing/                   frameworks-and-matrix · per-archetype-tests · fuzz-and-invariants
├── hackathon/                 scale-later-seams
├── reuse-index/               ← the crown jewel: curated forkable implementations per archetype
└── recipes/                   "ship it in ~6h" playbooks per archetype
```

**`stack-defaults.md` is load-bearing** — it's why `/brief` never asks about Anchor vs. native or which RPC. Current defaults: Solana primary (Anchor, `@solana/kit`, `@solana/wallet-adapter`, Next.js App Router from `create-solana-dapp`, Node/TS services, Neon Postgres), EVM secondary (Foundry + OZ/Solady), devnet-first, advisory gates.

---

## Archetypes

Everything — recipes, reuse-index files, and the 5 non-negotiable tests — is organized by these five. `/brief`, `/scout`, `/build`, and the agents infer the archetype from your need; if one guesses wrong, just say so.

| Archetype | Covers |
|---|---|
| **consumer-sites** | Deposit / escrow / payout, auction-style apps *(the flagship recipe)* |
| **defi-trading** | DEX/AMM, aggregators, vaults, staking |
| **launch-mint** | Launchpads, presales, bonding curves, mints, vesting |
| **bots-infra** | Sniper/copy-trade bots, Jito/MEV, indexers, price APIs, TG bots |
| **wallets-payments** | Smart wallets, account abstraction, escrow, payments |

---

## Try it — the vulnerable fixtures

Two intentionally vulnerable fixtures for exercising the review path. **Do not deploy either.**

- **`samples/vulnerable-escrow/`** — an Anchor program with 3 seeded bugs (unsigned `settle` drain, unconstrained `vault`/`recipient`, unchecked arithmetic).
- **`samples/vulnerable-vault/`** — a Solidity vault with 3 seeded bugs (reentrancy/CEI in `withdraw`, missing access control on `setFeeRecipient`, share-accounting rounding/inflation).

```
/audit samples/vulnerable-escrow      # Solana — expect the 3 bugs, criticals first, file:line
/audit samples/vulnerable-vault       # EVM — same
/debrief samples/vulnerable-escrow    # full five-section review
/ship samples/vulnerable-vault        # criticals loud at the top, non-blocking
```

Each fixture's `ANSWERS.md` is the key — don't feed it to the reviewer, or you defeat the test.

---

## Files the commands write into your repo

The commands drop a few working files into *your* product repo:

| File | Written by | Commit it? |
|---|---|---|
| `SPEC.md` | `/brief` | Yes — it's the build contract. |
| `DEBRIEF.md` / `AUDIT.md` | `/debrief` / `/audit` | Optional — review artifacts. |
| `STATE.md` | `/handoff` | **Yes** — env var *names* only, safe to commit; the next session/teammate resumes from it. |
| `.buidl/clock.json` | `/burn`, hackathon mode | **No** — local sprint ephemera; add `.buidl/` to your `.gitignore`. |

---

## Customizing

**The knowledge base is yours to edit.** Anything under `knowledge/*.md` is fair game:

- Start with **`stack-defaults.md`** — edit the defaults (RPC provider, env var names, DB choice) and any stack pick you disagree with. `/brief`, `/build`, `/doctor`, `/update`, the `logic-explainer` agent, and hackathon mode all load it, so one edit changes them all.
- **Add reuse candidates** you trust to `reuse-index/<archetype>.md` using the entry format in its README — the highest-leverage edit, since `/scout` and `/build` start from your index before searching the web.
- **Tighten the checklists** in `security/` with the bug classes you keep hitting.
- **Add an archetype** by creating `recipes/<name>.md` + `reuse-index/<name>.md` and listing it in `reuse-index/README.md`.

Keep the conventions: frontmatter intact, files ≤400 lines. Editing commands or agents? They're plain markdown with YAML frontmatter in `commands/` and `agents/`; reference knowledge files via `${CLAUDE_PLUGIN_ROOT}` so paths resolve wherever the plugin is installed. Run `/reload-plugins` after editing. See [`CLAUDE.md`](./CLAUDE.md) for the full contributor conventions.

---

## Guardrails and posture

- **Devnet/demo first, always.** `/build` never touches mainnet. `/ship` stops and requires an explicit "yes, mainnet" before any mainnet command.
- **Gates are advisory, never blocking.** Criticals are surfaced loudly and never silently passed — but you're never stopped. You decide.
- **Secrets never in the repo.** Env or keychain only; runbooks and `STATE.md` reference env var *names* only.
- **Reuse posture: anything public is fair game.** License and audit status are recorded so you can decide; they don't veto a candidate. Check each cited repo's own license before forking.

---

## Troubleshooting

- **Commands don't appear in `/help`.** Check `/plugin` → Installed, then `/reload-plugins` or restart. They're namespaced: `/buidl-kit:brief`.
- **Edits to knowledge or commands aren't taking effect.** `/reload-plugins`. Local installs read the working tree — no commit needed.
- **The Solana MCP isn't connected.** Run `/doctor`, or `/mcp` to approve/reconnect `solana-mcp` (or `claude mcp add --transport http solana-mcp https://mcp.solana.com/mcp`).
- **`/debrief` or `/audit` picked the wrong auditor.** It detects the chain from the files present — point it at the specific subdir (`/audit programs/my-program`) or say which chain.
- **`/scout` returns thin results.** Narrow the need to one capability, or run it against `SPEC.md` so it splits the search across sub-needs.

---

## Publishing updates

Live at **[github.com/AaroneGeorge/build-kit](https://github.com/AaroneGeorge/build-kit)**. The whole release is `git add -A && git commit && git push` — the marketplace entry is **unpinned** (no `version` field), so installs track the latest commit on `main`. Users get it via Claude Code's background refresh, `/buidl-kit:update`, or `/plugin marketplace update buidl-kit-marketplace` + `/reload-plugins`. Run `claude plugin validate .` and `bash scripts/validate.sh` before pushing (CI runs both).

---

## Contributing

See [`CLAUDE.md`](./CLAUDE.md) for conventions (frontmatter shapes, the 400-line rule, the repo/plugin/marketplace naming, the release process) and the pre-push validation steps.

---

## License

MIT — see [`LICENSE`](./LICENSE), © 2026 Aarone George. Knowledge files cite their sources; check each cited repo's own license before forking its code.
