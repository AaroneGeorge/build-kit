---
name: hackathon-build
description: >
  Hackathon mode - ship a demoable crypto app before a hard wall-clock deadline.
  Ruthless scoping, mock-vs-build triage, thin vertical slices with a commit each,
  deploy in the first hour and keep it green, and take every shortcut along
  scale-later seams so the simplest version can scale horizontally after the event.
  Use when the builder mentions a hackathon, demo day, a submission deadline,
  a 24/48-hour build, "ship by tonight", or building something fast for judges.
---

You are in **hackathon-build** mode: the buidl-kit flow compressed against a wall clock. Everything below overrides the normal 6-12h pacing. Load `${CLAUDE_PLUGIN_ROOT}/knowledge/stack-defaults.md` (stack is locked — never ask about it) and the archetype recipe once known.

## 1. Clock first
Before any code: get the **hard deadline** (submission time, timezone). Write `.buidl/clock.json` in the project:
```json
{ "start": "<ISO now>", "deadline": "<ISO deadline>", "slices_planned": 0 }
```
`/burn` reads this. Update `slices_planned` after planning. Re-check the clock at every checkpoint below.

## 2. Scope ruthlessly — the build/mock triage
One **core demo loop** only — the single path a judge walks. For every capability the idea implies, decide:
- **BUILD** it if: judges interact with it live, OR funds/tokens flow through it on-chain.
- **MOCK** it if anything else: hardcode the second user, seed the leaderboard, stub the oracle price, fake the notification. Every mock lives **behind its own module/interface** so the real thing slots in later — see the seams doc.
- **CUT** everything that is neither. Say out loud what was cut and what was mocked; the builder can veto.

No full `/brief`: a 5-minute spec — goal, the demo loop, chain (default Solana devnet), what's mocked/cut — confirmed in one round, written to `SPEC.md` (short is fine).

## 3. Scout — timeboxed
One `repo-scout` pass, **for the core primitive only** (the escrow, the AMM math, the mint flow), ~10 minutes. Fork the best hit; don't comparison-shop five candidates like normal `/scout`. Everything peripheral uses the stack defaults' scaffolds (`create-solana-dapp`).

## 4. Plan 2–4 vertical slices
Each slice is **end-to-end and demoable** (program instruction + client call + visible UI change), never a layer. Slice 1 is the **walking skeleton**: the thinnest version of the core loop, deployed. Write the slice list, update `slices_planned`.

## 5. Build slice by slice — always demoable
For each slice: implement (parallelize program vs frontend vs services with subagents where independent) → tests for fund paths green → **commit `slice-N: <what demos now>`** → redeploy. The last green slice is the demo floor; **never leave the tree broken** when a checkpoint or the deadline could land.

## 6. Deploy in hour one, keep it green
Slice 1 ends with: program on **devnet** + frontend on a public URL (Vercel default — it's stateless-by-default, which is also your scaling story). Redeploy after every slice. A local-only app at judging time is a failed hackathon. Never deploy mainnet.

## 7. Simplest now, horizontally scalable later
Every shortcut must fall along a **scale-later seam** — read `${CLAUDE_PLUGIN_ROOT}/knowledge/hackathon/scale-later-seams.md` before writing services. The one-liner: state in Postgres/on-chain never in process memory, idempotent handlers, side effects and mocks behind module boundaries, config via env. Simplest possible code, but a second instance must never corrupt anything.

## 8. Checkpoints
At ~50% and ~75% of the clock (and whenever the builder asks), run the `/burn` math: slices shipped vs elapsed. **Behind → cut the last slice or demote a BUILD to a MOCK.** Never respond to being behind by rushing the fund-path code.

## 9. Security floor — even at hackathon speed
Non-negotiable on any fund-moving path: signer + owner checks, checked arithmetic, no unconstrained `UncheckedAccount`. Before submission, run `solana-security-auditor` (or the EVM one) **scoped to fund-moving files only** — a 15-minute pass, criticals fixed or disclosed. Secrets stay in env; devnet only.
