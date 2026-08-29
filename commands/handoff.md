---
description: Write STATE.md - a session-handoff snapshot (done, in progress, next steps, decisions, git + deploy state) so a fresh session resumes the build instantly.
argument-hint: "[optional note for the next session]"
allowed-tools: Read, Grep, Glob, Bash, Write
---

You are running **/handoff**, buidl-kit's session-state writer. Optional note from the builder: $ARGUMENTS. Purpose: a crashed, compacted, or ended session must cost minutes, not a re-derivation of everything. Write it so a fresh session (or another person) can resume **without reading this conversation**.

## Gather (from the conversation, the repo, and the filesystem)
- **Goal** — one sentence, from `SPEC.md` if present.
- **Done** — completed slices/tasks; use `git log --oneline` (note `slice-N:` commits) plus what this session finished.
- **In progress** — exactly where work stopped, with `file:line` and what remains to make it green.
- **Next steps** — ordered; the first one should be startable immediately.
- **Decisions made** — anything chosen in-session that isn't obvious from the code (fork picked and why, what's mocked vs built, scope cuts, seams promised in SPEC.md).
- **Git state** — branch, HEAD sha, dirty/untracked files (`git status --porcelain`).
- **Deploy state** — devnet program ID(s), frontend URL, cluster, and the env var **names** required (`RPC_URL`, `DATABASE_URL`…). **Never write secret values — names only.**
- **Open flags** — unresolved security findings, disclosed unaudited ported code, failing tests.
- **Clock** — if `.buidl/clock.json` exists: deadline, elapsed, slices shipped/planned.

## Output
Write **`STATE.md`** at the project root with those sections in that order, the builder's note (if given) at top, and a final **"To resume"** line — the literal next command to run (e.g. `/build SPEC.md` — it reads STATE.md and continues, or the specific test/deploy command mid-flight). Overwrite any previous STATE.md; it is a snapshot, not a log. STATE.md holds env var **names only** (never values), so it's safe to commit — do, so the next session or teammate picks it up from the repo. Confirm with a 3-line summary: where things stand, the first next step, and any open flag.
