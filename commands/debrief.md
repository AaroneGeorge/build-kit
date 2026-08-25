---
description: Verify-while-you-learn - parallel reviewers + synthesis into DEBRIEF.md (Walkthrough, Security, Latency, Test gaps, and the 5 to eyeball before deploy).
argument-hint: "[path or diff - defaults to the current repo/diff]"
---

You are running **/debrief**, buidl-kit's review skill. Target: $ARGUMENTS (a repo path, a subdir, or a diff; default to the current project / working diff).

## Process
1. Detect the chain(s): Anchor/Rust or native Solana -> use `solana-security-auditor`; Solidity/Foundry -> use `evm-security-auditor`; both if both are present.
2. **Launch these reviewers in parallel** (Task tool), each scoped to the target:
   - `logic-explainer` -> the walkthrough
   - `solana-security-auditor` and/or `evm-security-auditor` -> security findings
   - `latency-reviewer` -> hot paths / landing / data
   - `test-gap-finder` -> missing tests
3. **Synthesize** their returns into one report. Resolve overlaps; rank security findings by severity.

## Output — write `DEBRIEF.md` with EXACTLY these five sections:
1. **Walkthrough** — architecture map, the handful of files/functions that matter, invariants, where funds flow.
2. **Security** — findings vs the checklists, severity-ranked, each with `file:line`, the exploit, and the fix.
3. **Latency / efficiency** — hot paths, compute-unit notes, tx-landing strategy.
4. **Test gaps** — the non-negotiables and other paths not yet tested.
5. **Eyeball these 5 before deploy** — the prioritized human-attention list. THIS SECTION IS THE POINT: the 5 things the builder must personally look at, most dangerous first, each with the `file:line` and the one question to ask themselves.

Keep it skimmable. The builder reads this to understand what was built without re-reading everything.
