---
description: Hackathon burn report - elapsed vs remaining wall-clock, slices shipped vs planned, pace verdict, and exactly what to cut or mock if behind.
argument-hint: "[deadline e.g. 21:00 or 2026-08-30T09:00 - only needed when no .buidl/clock.json]"
---

You are running **/burn**, buidl-kit's wall-clock tracker. Wall-clock is the scarce hackathon resource (for token spend, point the builder at the built-in `/cost`).

## Process
1. **Load the clock.** Read `.buidl/clock.json` (`start`, `deadline`, `slices_planned` — written by hackathon-build). Missing → take the deadline from $ARGUMENTS (else ask one question), set `start` to the first commit timestamp of the current sprint (fall back: now), and write the file.
2. **Compute** elapsed, remaining, and % of clock used (`date` via Bash for current time; mind the deadline's timezone).
3. **Count shipped work:** `git log --oneline` — `slice-N:` commits are the primary signal (slices shipped vs `slices_planned`); other commits are secondary. Check the demo floor is green: last slice deployed (STATE.md deploy state, or ask) and tree not broken (`git status`).
4. **Verdict — compare % of slices shipped vs % of clock used:**
   - **AHEAD / ON PACE** — say so in one line, plus the single next milestone.
   - **BEHIND** — be concrete, per the hackathon triage: which remaining slice to **cut**, which BUILD to demote to a **MOCK** (behind its seam), and what the demo floor is if nothing else lands. Never suggest rushing fund-path code or skipping the security floor — cut scope instead.
5. If past ~50% or ~75% of the clock and the corresponding checkpoint hasn't happened, flag it.

## Output
Compact — glanceable mid-sprint:
```
⏱ 4h 12m elapsed · 1h 48m left (70% used)
📦 slices: 2/4 shipped · demo floor: slice-2 deployed ✅ (devnet + Vercel)
⚖️ verdict: BEHIND — cut slice 4, demote oracle to mock
→ next: finish slice-3 settle path (programs/…/lib.rs:142)
```
Then at most 3 lines of reasoning. Update `.buidl/clock.json` if `slices_planned` changed.
