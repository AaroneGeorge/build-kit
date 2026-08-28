# buidl-kit

Reuse-first Claude Code plugin for shipping **production-grade crypto products in 6–12 hours**. Solana-primary, EVM-secondary. Its job is to make **find → evaluate → adapt proven code** the default, and to spend your scarce attention on **verification** — security, latency, and the few things worth your eyeballs.

Ten commands — the core flow **/brief → /scout → /build → /debrief → /ship**, plus **/kb-update**, **/doctor**, **/handoff**, **/burn**, and **/update** — a **hackathon-build** skill that kicks in automatically when a deadline looms, a curated `knowledge/` base (the brain), and six reusable subagents.

> Plugin commands are namespaced, so they appear as `/buidl-kit:brief`, `/buidl-kit:scout`, etc. (written as `/brief` … below for brevity).

---

## Table of contents

- [Install](#install)
- [60-second cheatsheet](#60-second-cheatsheet--which-command-when)
- [The commands in depth](#the-commands-in-depth)
  - [/brief](#brief--requirements-interrogator)
  - [/scout](#scout--the-reuse-engine)
  - [/build](#build--the-orchestrator)
  - [/debrief](#debrief--verify-while-you-learn)
  - [/ship](#ship--advisory-pre-deploy-gate)
  - [/kb-update](#kb-update--keep-the-brain-fresh)
  - [/doctor](#doctor--environment-preflight)
  - [/handoff](#handoff--session-state)
  - [/burn](#burn--the-hackathon-clock)
  - [/update](#update--pull-latest-from-main)
- [Hackathon mode — the hackathon-build skill](#hackathon-mode--the-hackathon-build-skill)
- [The agents (usable standalone)](#the-agents-usable-standalone)
- [Usage patterns](#usage-patterns)
- [The knowledge base](#the-knowledge-base)
- [Archetypes](#archetypes)
- [Try it — the vulnerable-escrow fixture](#try-it--the-vulnerable-escrow-fixture)
- [Customizing](#customizing)
- [Guardrails and posture](#guardrails-and-posture)
- [Troubleshooting](#troubleshooting)
- [Publishing updates](#publishing-updates)
- [License](#license)

---

## Install

From a Claude Code session — **from GitHub** (published):

```
/plugin marketplace add AaroneGeorge/build-kit
/plugin install buidl-kit@buidl-kit-marketplace
```

Or **from a local clone** (development):

```
/plugin marketplace add /path/to/build-kit
/plugin install buidl-kit@buidl-kit-marketplace
```

Local installs need no git commit — Claude Code reads the working tree. Verify with `/plugin` (Installed tab); you'll see the `buidl-kit:*` commands in `/help`. After editing plugin files, run `/reload-plugins` or restart the session.

Pull published updates with:

```
/plugin marketplace update buidl-kit-marketplace
```

**Where to run it:** the commands operate on *your product repo*, not on this one. Install the plugin once, then `cd` into whatever you're building and run `/brief`, `/build`, `/debrief` there. The only exception is `/kb-update`, which edits the plugin's own `knowledge/` files.

---

## 60-second cheatsheet — which command, when

| You have… | Run | You get |
|---|---|---|
| A rough idea | `/brief "<idea>"` | Batched tappable questions → `SPEC.md` + a scout-first build plan |
| A need or SPEC.md | `/scout "<need>"` | Ranked existing repos/SDKs to fork/import + a fork plan (appended to the reuse-index) |
| A confirmed SPEC.md | `/build SPEC.md` | Scout-first implementation, tests, devnet deploy → auto-chains `/debrief` |
| Freshly built code (or any repo/diff) | `/debrief [path]` | `DEBRIEF.md`: walkthrough, security, latency, test gaps, **the 5 to eyeball** |
| Something about to deploy | `/ship [path]` | Advisory gate: criticals loud at top (non-blocking) + deploy runbook |
| Stale knowledge | `/kb-update [reuse\|security\|all]` | Refreshed reuse-index + incident lessons, dated + sourced |
| A hackathon deadline | just say "hackathon" (or `/buidl-kit:hackathon-build`) | Clock-driven sprint: ruthless scoping, vertical slices, deploy-early, scale-later seams |
| A fresh machine / flaky toolchain | `/doctor` | PASS/WARN/FAIL preflight + the exact fix command for each failure |
| A session about to die (or done for the day) | `/handoff` | `STATE.md` — the next session resumes in minutes, not re-derivation |
| Mid-sprint "are we on pace?" | `/burn` | Elapsed vs slices shipped, pace verdict, what to cut if behind |
| A stale plugin install | `/update [check]` | Latest main + a changelog; your local knowledge edits protected |

Typical flow: `/brief` → `/scout` → `/build` (chains `/debrief`) → `/ship`. Each also stands alone — `/debrief` and `/ship` run on any repo or diff.

---

## The commands in depth

### `/brief` — requirements interrogator

```
/brief "an outbid-style auction site where the last bidder before the timer wins the pot"
/brief                       # no argument: it asks what you're building
```

**What it does.** Turns a rough idea into a spec you confirm. It loads `stack-defaults.md` first — the stack is **locked**, so it will never ask you about Anchor vs. native, Next.js, Node, Neon, or RPC choice. It infers your archetype and pulls concrete candidates out of the reuse-index to ground its questions.

**How it asks.** Batched rounds of up to 4 tappable questions (via `AskUserQuestion`), unlimited rounds. **Every round pushes at least one thing you didn't ask for** — an adjacent feature, a better architecture call, or an existing library/protocol you may not know about.

**When it stops.** Only when it can restate the whole picture and you confirm it: goal · users · chain · archetype + matched reuse candidates · in scope · out of scope · key security/latency risks · success criteria.

**Output.** `SPEC.md` in your project, with those 8 sections plus a **Recommended build plan** that is scout-first: what to fork/import, the 3 dangerous parts for your archetype, the minimum tests, and the devnet-first deploy path.

**Next:** `/scout` to lock candidates, then `/build`.

---

### `/scout` — the reuse engine

```
/scout "solana escrow vault with PDA-held SOL and a settle instruction"
/scout SPEC.md               # reads the spec and scouts every need in it
/scout "EVM merkle airdrop claim contract"
```

**What it does.** Determines the archetype, loads the reuse-index scoring rules, then launches **`repo-scout` agents in parallel** across non-overlapping search lanes: (a) the local reuse-index + adjacent archetypes, (b) GitHub, (c) crates.io / npm, (d) protocol SDK docs. For a broad need it runs one agent per sub-need. Results are merged, de-duplicated, and scored on **fit / maintenance / audit status / license / adaptation effort**.

**Output.**
- **Ranked candidates** — ≥5 for a well-known need. Each with: name, link, what you get, audit status, license (copyleft/BUSL flagged), maintenance signal, fork-vs-import verdict, known pitfalls.
- **Fork/adapt plan** for the top 1–2: what to keep, what to change, integration risks.
- **Index delta** — new finds are appended to `knowledge/reuse-index/<archetype>.md` in the standard entry format, and that file's `last_verified` is bumped. It reports what it added, so the index compounds as you use it.

**Posture:** anything public is fair game. License and audit status are *recorded so you can decide*, never used to block you.

---

### `/build` — the orchestrator

```
/build SPEC.md
/build                       # looks for ./SPEC.md; if absent, runs a quick /brief-style clarification first
```

**The process.**
1. Reads `SPEC.md` + `stack-defaults.md` (and `STATE.md`, if a previous session left one via `/handoff` — it resumes rather than replans), identifies the archetype, loads `knowledge/recipes/<archetype>.md`.
2. **Scouts first** — launches `repo-scout` to lock reuse candidates *before* any code is written. Writing from scratch has to be justified in the plan.
3. **Plans vertical slices** off the recipe's 6-hour spine: 2–5 thin **end-to-end** slices (program instruction + client call + visible UI change — never a layer like "all models, then all views"). Slice 1 is the walking skeleton: the thinnest fund-flow loop, deployable. The 3 dangerous parts are named and assigned to their slices.
4. **Implements slice by slice** — forks/imports the chosen candidates and adapts them, parallelizing independent work (program vs. frontend vs. services) across subagents within a slice. After each slice: tests green → commit `slice-N: …` → redeploy devnet — so **there is always a demoable state**. Fund-moving paths follow `solana/anchor-idioms.md` and the security checklist, safe-by-construction rather than fixed later.
5. **Tests** per `knowledge/testing/` — fund-path tests land inside their slice; all 5 of the archetype's non-negotiables are green by the final slice. LiteSVM/bankrun for speed.
6. **Uses the official Solana Developer MCP when installed** — docs lookups instead of guessing APIs, plus a `program_autofixer` check→fix→recheck loop before review. Not installed? It suggests the one-liner once and moves on (`/doctor` checks for it too).
7. **Deploys to devnet only.**
8. **Always chains `/debrief`** on what it built, so you get the walkthrough and review while it's fresh.

**Guardrails.** Devnet/demo first, always — mainnet requires an explicit human "yes" and it will stop and ask. Secrets and keys never land in the repo (env/keychain only). Any unaudited logic it ported is called out and handed to the `/debrief` security pass.

---

### `/debrief` — verify while you learn

```
/debrief                      # current project / working diff
/debrief samples/vulnerable-escrow
/debrief programs/my-program/src/lib.rs
/debrief "the diff on this branch"
```

**What it does.** Detects the chain(s) — Anchor/Rust or native Solana → `solana-security-auditor`; Solidity/Foundry → `evm-security-auditor`; both if both are present — then launches four reviewers **in parallel** (plus the official Solana MCP's `program_autofixer` when it's installed, deduped against the auditor's own findings) and synthesizes their returns into one report, resolving overlaps and ranking findings by severity.

**Output — `DEBRIEF.md`, exactly five sections:**

1. **Walkthrough** — architecture map, the handful of files/functions that actually matter, invariants, where funds flow.
2. **Security** — findings vs. the checklists, severity-ranked, each with `file:line`, the concrete exploit, and the fix.
3. **Latency / efficiency** — hot paths, compute-unit notes, tx-landing strategy.
4. **Test gaps** — the non-negotiables and other untested paths.
5. **Eyeball these 5 before deploy** — *this section is the point*: the 5 things you personally must look at, most dangerous first, each with a `file:line` and the one question to ask yourself.

Runs on any repo or diff, not just code `/build` produced — point it at an unfamiliar codebase to understand it fast.

---

### `/ship` — advisory pre-deploy gate

```
/ship
/ship samples/vulnerable-escrow
```

**What it does.** Loads `security/ship-gate-checklist.md`, runs a **fresh security pass on the diff** (Solana and/or EVM auditor by chain), then walks the gate: secrets/keys, upgrade authority, program verification, security criticals, tests/build, monitoring.

**Output.**
- **Critical banner first** — every CRITICAL/HIGH finding, loud, at the very top, with `file:line`. Nothing is ever silently passed. Then, plainly: *advisory only — you decide.* **The gate does not block.**
- **Gate results** — each checklist section marked pass / warn / fail, with specifics.
- **Deploy runbook** — devnet-first steps to do now, then the mainnet steps for later, covering key handling (env/keychain), upgrade authority (Squads multisig or immutable), verifiable builds (`solana-verify`), and monitoring.

**Mainnet requires your explicit "yes, mainnet."** It states this and stops for confirmation before running any mainnet command.

---

### `/kb-update` — keep the brain fresh

```
/kb-update                   # default: all
/kb-update reuse             # just the reuse-index
/kb-update security          # just incident-lessons + checklists
```

**What it does.** Launches `repo-scout` and research agents in parallel — one per archetype for reuse, one per source for security — using live web search.

- **reuse-index:** re-verifies each existing candidate still exists and is maintained (updating maintenance/audit/license notes, marking dead ones) and adds notable new candidates in the standard entry format.
- **security/incident-lessons.md:** adds significant new exploits with the root-cause class mapped to a checklist item, and refreshes checklist items when tooling or best practice moved.

**Rules it follows.** Every change carries a source URL and today's date; every touched file's `last_verified` is bumped; files stay ≤400 lines (older entries get tightened rather than the file growing unbounded). It ends with a concise changelog of what changed and why.

Run it every few weeks, or before starting a build in an archetype you haven't touched in a while.

---

### `/doctor` — environment preflight

```
/doctor                      # infers scope from the project
/doctor solana | evm | all
```

Verifies the toolchain **before** a build burns its first hour on drift: Solana CLI, **Anchor version vs. what `Anchor.toml`/`Cargo.toml` expect** (the #1 real-world failure mode), Rust, Node ≥ 20, wallet keypair, **devnet SOL balance** (offers the airdrop), RPC reachability, Foundry when EVM is in scope — plus WARN-level boosters: the official Solana Developer MCP and Slither/Aderyn for the EVM auditor. Output is a PASS/WARN/FAIL table with **the exact fix command per failure**, ending in "safe to `/build`" or an ordered fix list. It never installs or overwrites anything without your yes.

---

### `/handoff` — session state

```
/handoff
/handoff "stopping for dinner — settle path half done"
```

Writes **`STATE.md`**: goal, done (from `slice-N:` commits), in-progress with `file:line`, ordered next steps, decisions made and why, git state, deploy state (program IDs, URLs, env var *names* — never values), open security flags, and the literal command to resume with. `/build` reads it and resumes instead of replanning. Run it when a session is about to die, before compaction, or at end of day — a lost session should cost minutes, not a re-derivation.

---

### `/burn` — the hackathon clock

```
/burn                        # reads .buidl/clock.json (hackathon mode writes it)
/burn 21:00                  # or set the deadline directly
```

Wall-clock burn report: elapsed vs. remaining, slices shipped vs. planned (counted from `slice-N:` commits), whether the demo floor is still deployed and green, and a pace verdict. **Behind** never means "rush the fund path" — it answers with exactly which slice to cut or which BUILD to demote to a MOCK. Token spend is the built-in `/cost`; `/burn` tracks the resource hackathons actually run out of.

---

### `/update` — pull latest from main

```
/update                      # sync to latest main + changelog
/update check                # read-only: just tell me if I'm behind
```

The marketplace entry is unpinned, so installs track the **latest commit on `main`**. `/update` compares your install against upstream, shows what changed grouped by area (commands / agents / skills / knowledge), and — before touching anything — detects `knowledge/` files you've customized, asks, and backs them up to `~/.claude/buidl-kit-backup-<date>/`, offering to re-merge them after. Works for both marketplace installs (via the `claude plugin` CLI) and local clones (`git pull --ff-only`). Finishes by reminding you to `/reload-plugins`.

---

## Hackathon mode — the hackathon-build skill

You don't invoke this one — mention a hackathon, a submission deadline, or "ship by tonight" and Claude loads it (or call `/buidl-kit:hackathon-build` explicitly). It's the buidl-kit flow compressed against a wall clock:

1. **Clock first** — the hard deadline goes into `.buidl/clock.json`; `/burn` and the built-in checkpoints (at 50% and 75%) run against it.
2. **Ruthless scoping** — one core demo loop. Everything else hits the **build/mock triage**: *build* it only if judges touch it live or funds flow through it; *mock* it behind a module interface otherwise; *cut* the rest, out loud.
3. **Timeboxed scout** — one `repo-scout` pass (~10 min) for the core primitive only; scaffolds for everything else.
4. **2–4 vertical slices** — slice 1 is the walking skeleton, **deployed in hour one** (devnet + public URL) and kept green after every slice. The last green slice is always your demo floor.
5. **Simplest now, horizontally scalable later** — every shortcut lands on a seam from `knowledge/hackathon/scale-later-seams.md`: state in Postgres/on-chain never in process memory, idempotent handlers, correctness from the DB (not from being single-instance), mocks and side effects behind module boundaries, config via env. The simple version must survive running two copies — that's the whole scaling story, and it costs ~zero extra time during the event.
6. **Security floor** — signer/owner checks and checked math on fund paths are never traded for speed; a 15-minute auditor pass scoped to fund-moving files runs before submission. Devnet only.

---

## The agents (usable standalone)

The commands orchestrate these, but each is useful on its own — just ask for it by name ("use the solana-security-auditor on `programs/vault`"). All of them **return findings rather than writing files**, unless you ask them to write.

| Agent | Use it for | Loads |
|---|---|---|
| **`repo-scout`** | "Does this already exist?" Ranked forkable/importable candidates + a fork/adapt plan + an index delta. Returns ≥5 candidates for a well-known need. | `reuse-index/` |
| **`solana-security-auditor`** | Any Anchor/native Rust program or diff. Ranks entry points by blast radius, maps fund flow, walks the checklist (signer, owner, discriminator, PDA/bump, arithmetic, CPI/program-id, account substitution, sysvar, close/revival, duplicate-mut, reinit, oracle, SPL/Token-2022, upgrade authority, MEV), and proves or flags every `AccountInfo`/`UncheckedAccount`. Cross-checks with the Solana MCP autofixer and Solodit when available. | `security/solana-audit-checklist.md`, `incident-lessons.md`, `solana/anchor-idioms.md`, `solana/token-2022.md` |
| **`evm-security-auditor`** | Any Solidity repo or diff. Runs Slither/Aderyn first when installed (triaged, noise discarded), ranks entry points by blast radius, then walks: access control, reentrancy (incl. read-only), CEI/external calls, arithmetic, oracle/TWAP manipulation, approvals, EIP-712 signatures/replay, upgradeability & storage layout, DoS/gas, MEV. Flags anything reinventing an OZ/Solady primitive; cites Solodit/Cyfrin precedents for known classes. | `security/evm-audit-checklist.md`, `incident-lessons.md`, `evm/foundry-and-patterns.md` |
| **`logic-explainer`** | Understanding an unfamiliar crypto repo fast: architecture map, the 5–10 files/functions that matter, the invariants, and every place value moves with the guard on each. | `stack-defaults.md`, the archetype recipe |
| **`latency-reviewer`** | Slow apps and dropped transactions: hot paths, compute-unit limits, priority fees, ALTs, retry/rebroadcast, commitment level, polling→websocket/Geyser swaps, `getProgramAccounts` scans, caching, Neon pooling — plus where paying for speed (staked RPC, Jito) is actually worth it. | `solana/tx-landing.md`, `latency/rpc-and-realtime.md`, `latency/indexing-caching-db.md` |
| **`test-gap-finder`** | "What must exist before this ships?" Missing per-archetype non-negotiables, untested auth/arithmetic/state-transition/fund-flow paths with the assertion each should make, and the fastest framework for each gap. | `testing/frameworks-and-matrix.md`, `testing/per-archetype-tests.md` |

Security auditors report each finding as **[SEVERITY] + `file:line` + issue + concrete exploit + the safe fix**, naming the exact Anchor constraint or OZ/Solady primitive — never "review access control."

---

## Usage patterns

**Full green-field build (the happy path)**
```
/brief "auction site where the last bidder wins the pot"
/scout SPEC.md
/build SPEC.md          # chains /debrief automatically
/ship
```

**You already know what to build — skip the interrogation**
```
/scout "solana PDA escrow vault with timed settle"
/build SPEC.md
```

**Audit code you didn't write**
```
/debrief ../some-forked-protocol
```
Five sections, `file:line` throughout, and the 5 things to look at yourself.

**Pre-deploy check on an existing project**
```
/ship
```
No SPEC, no build history needed — it works off the diff.

**Evaluating a fork candidate before committing to it**
```
/scout "<the need>"
/debrief <path to the cloned candidate>
```
Scout ranks it; debrief tells you what you'd be inheriting.

**Speed triage on a live app** — ask for `latency-reviewer` directly on the repo; you get hot paths, landing strategy, and the pay-for-speed calls without the full debrief.

**Keeping the brain current**
```
/kb-update all
```

---

## The knowledge base

`knowledge/` is the brain every command and agent reads. Each file is ≤400 lines and carries front-matter (`title`, `description`, `applies_to`, `sources`, `last_verified`) so claims stay dated and sourced.

```
knowledge/
├── stack-defaults.md          ← edit this first: your locked stack + RPC/latency defaults + posture
├── solana/
│   ├── anchor-idioms.md       safe-by-construction constraints
│   ├── token-2022.md          extension traps (transfer hooks, fees, non-transferable…)
│   ├── tx-landing.md          priority fees, CU limits, ALTs, retries, commitment
│   └── client-patterns.md     @solana/kit patterns
├── evm/
│   └── foundry-and-patterns.md  Foundry + OZ/Solady picks + vuln patterns
├── security/
│   ├── solana-audit-checklist.md   risk / spot-pattern / safe-pattern per category
│   ├── evm-audit-checklist.md
│   ├── incident-lessons.md          real exploits → root-cause class → checklist item
│   └── ship-gate-checklist.md       what /ship walks
├── latency/
│   ├── rpc-and-realtime.md    RPC choice, websockets, Geyser, webhooks
│   └── indexing-caching-db.md indexing, caching, Neon pooling & cold starts
├── hackathon/
│   └── scale-later-seams.md   simplest-now shortcuts that still scale horizontally later
├── testing/
│   ├── frameworks-and-matrix.md  LiteSVM vs bankrun vs local validator vs forge
│   └── per-archetype-tests.md    the 5 non-negotiables per archetype
├── reuse-index/               ← the crown jewel
│   ├── README.md              entry format + the 5 scoring criteria
│   └── <archetype>.md         curated forkable/importable implementations
└── recipes/
    └── <archetype>.md         "ship it in ~6h" playbooks
```

**`stack-defaults.md` is load-bearing.** It's why `/brief` never asks you about Anchor vs. native or which RPC to use. Current defaults: Solana primary (Anchor, `@solana/kit`, `@solana/wallet-adapter`, Next.js App Router scaffolded from `create-solana-dapp`, Node/TS services, Neon Postgres), EVM secondary (Foundry + OZ/Solady), devnet-first, advisory-never-blocking gates.

---

## Archetypes

Everything — recipes, reuse-index files, and the 5 non-negotiable tests — is organized by these five:

| Archetype | Covers |
|---|---|
| **consumer-sites** | Deposit / escrow / payout, auction-style apps *(the flagship recipe)* |
| **defi-trading** | DEX/AMM, aggregators, vaults, staking |
| **launch-mint** | Launchpads, presales, bonding curves, mints, vesting |
| **bots-infra** | Sniper/copy-trade bots, Jito/MEV, indexers, price APIs, TG bots |
| **wallets-payments** | Smart wallets, account abstraction, escrow, payments |

`/brief`, `/scout`, `/build`, and the agents infer the archetype from your need and load the matching recipe + reuse-index file. If it guesses wrong, just say so — it'll switch.

---

## Try it — the vulnerable-escrow fixture

`samples/vulnerable-escrow/` is an intentionally vulnerable Anchor program for exercising the review path. **Do not deploy it.**

```
/debrief samples/vulnerable-escrow
```

Expect all five DEBRIEF sections and the three seeded bugs, each with `file:line`:

1. **Missing signer / authority check** in `settle()` — `authority` is an `UncheckedAccount`, never signs, never compared to `auction.authority`; anyone can drain the vault.
2. **Missing owner / account validation** — `vault` and `recipient` are unconstrained `UncheckedAccount`s, so any accounts can be substituted.
3. **Unchecked arithmetic** — `+=` / `-` on `total_deposited` instead of `checked_add` / `checked_sub`.

A good run also flags the missing previous-bidder refund, the absent auction-end/`settled` guard, and direct lamport manipulation on the vault.

Then:

```
/ship samples/vulnerable-escrow
```

surfaces the criticals loudly at the top — without blocking.

> The full answer key lives in `samples/vulnerable-escrow/ANSWERS.md`. Don't feed it to the reviewer or you defeat the test.

---

## Customizing

**The knowledge base is yours to edit.** Anything under `knowledge/*.md` is fair game:

- Start with **`stack-defaults.md`** — swap the ALL-CAPS placeholders and any stack choice you disagree with. Every command reads it, so one edit changes all six.
- **Add reuse candidates** you trust to `reuse-index/<archetype>.md` using the entry format in its README. This is the highest-leverage edit: `/scout` and `/build` start from your index before searching the web.
- **Tighten the checklists** in `security/` with the classes of bug you keep hitting.
- **Add an archetype** by creating `recipes/<name>.md` + `reuse-index/<name>.md` and listing it in `reuse-index/README.md`.

**Keep the conventions:** front-matter (`description`, `sources`, `last_verified`) intact, files ≤400 lines. `/scout` and `/kb-update` append to `reuse-index/` and re-stamp `last_verified` as they learn, so hand edits and automated ones stay in the same shape.

Editing commands or agents? They're plain markdown with YAML front-matter in `commands/` and `agents/`. Use `${CLAUDE_PLUGIN_ROOT}` to reference knowledge files so paths resolve wherever the plugin is installed. Run `/reload-plugins` after editing.

---

## Guardrails and posture

- **Devnet/demo first, always.** `/build` never touches mainnet. `/ship` stops and requires an explicit "yes, mainnet" before any mainnet command.
- **Gates are advisory, never blocking.** Criticals are surfaced loudly and never silently passed — but you're never stopped. You decide.
- **Secrets never in the repo.** Env or keychain only.
- **Reuse posture: anything public is fair game.** License and audit status are recorded so you can decide; they don't veto a candidate. Check each cited repo's own license before forking its code.
- **Ported unaudited logic is always disclosed** and handed to the security pass.

---

## Troubleshooting

**Commands don't appear in `/help`.** Check `/plugin` → Installed. If it's there, run `/reload-plugins` or restart the session. Remember they're namespaced: `/buidl-kit:brief`.

**Edits to knowledge or commands aren't taking effect.** `/reload-plugins`. For local installs there's no need to commit — the working tree is read directly.

**`/build` can't find a spec.** Pass the path (`/build path/to/SPEC.md`) or run `/brief` first. With no spec at all it falls back to a quick clarification round.

**`/debrief` picked the wrong auditor.** It detects the chain from the files present. Point it at the specific subdirectory (`/debrief programs/my-program`) or just tell it which chain.

**`/scout` returns thin results.** Narrow the need to one capability rather than a whole product, or run it against `SPEC.md` so it can split the search across sub-needs.

**The reuse-index looks stale.** `/kb-update reuse` re-verifies every candidate and refreshes `last_verified`.

---

## Publishing updates

Live at **[github.com/AaroneGeorge/build-kit](https://github.com/AaroneGeorge/build-kit)**. To ship changes:

```
git add -A && git commit -m "your message"
git push
```

That's the whole release: the marketplace entry is **unpinned** (no `version` field), so installs track the latest commit on `main` — no version bump needed. Users get it via Claude Code's background marketplace refresh, or on demand with `/buidl-kit:update` (which also shows them what changed and protects their local knowledge edits) or `/plugin marketplace update buidl-kit-marketplace`, followed by `/reload-plugins`.

> The plugin lives in its own repo, fully separate from your product projects. `.gitignore` covers build artifacts and secrets.

---

## License

MIT — see [`LICENSE`](./LICENSE), © 2026 Aarone George. Knowledge files cite their sources; check each cited repo's own license before forking its code.
