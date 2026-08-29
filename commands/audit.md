---
description: Standalone security audit - run the chain-matched security auditor(s) on a path, repo, or diff right now, and write AUDIT.md with severity-ranked findings. No spec, build history, or full debrief needed.
argument-hint: "[path or diff - defaults to the current repo/diff] [--deep]"
---

You are running **/audit**, buidl-kit's direct security entry point. Target: $ARGUMENTS (a repo path, a subdir, a file, or a diff; default: the current project / working diff). `--deep` widens the pass — see step 3. Use this when the builder wants an audit *now*, without the full `/debrief` (which also does walkthrough/latency/tests) or the `/ship` gate.

## Process
1. **Detect the chain(s)** in the target: `Anchor.toml` / `Cargo.toml` with `anchor-lang`/`solana-program` → `solana-security-auditor`; `foundry.toml` / `hardhat.config.*` / `*.sol` → `evm-security-auditor`; both present → both. Can't tell → ask one question.
2. **Launch the matching auditor(s) in parallel** (Task tool), each scoped exactly to the target path/diff. They load the checklists and incident lessons themselves and rank entry points by blast radius — pass the target, not instructions they already have.
3. **`--deep` adds** a parallel `test-gap-finder` pass scoped to fund-moving paths, and asks the auditors to also propose the fuzz/invariant properties worth encoding (per `${CLAUDE_PLUGIN_ROOT}/knowledge/testing/fuzz-and-invariants.md`).
4. **Synthesize** into one severity-ranked list: dedupe overlapping findings, keep every `file:line`, keep each finding's Issue / Exploit / Fix shape.

## Output — write `AUDIT.md` at the project root:
- **CRITICAL BANNER FIRST** — every CRITICAL/HIGH finding loudly at the top with `file:line`. Then state plainly: *advisory only — you decide.* Never blocking.
- **All findings**, severity-ranked, each: `[SEVERITY]` · `file:line` · Issue · Exploit · Fix (naming the exact Anchor constraint or OZ/Solady primitive).
- **With `--deep`:** the missing-test list and the invariant properties worth fuzzing, each with the assertion it should make.
- End with the 3 findings to eyeball personally, most dangerous first.

Fixture self-test: `/audit samples/vulnerable-escrow` (from the plugin repo) should surface the 3 seeded bugs; so should `/audit samples/vulnerable-vault` for the EVM side.
