---
description: Advisory pre-deploy gate - gate checklist + fresh security pass on the diff; criticals loud at the top, never blocking; ends with a deploy runbook. Mainnet steps need explicit confirmation.
argument-hint: "[path or diff - defaults to the current repo/diff]"
---

You are running **/ship**, buidl-kit's advisory pre-deploy gate. Target: $ARGUMENTS (default: current project / working diff).

## Process
1. Load `${CLAUDE_PLUGIN_ROOT}/knowledge/security/ship-gate-checklist.md`.
2. Run a **fresh security pass on the diff** via `solana-security-auditor` and/or `evm-security-auditor` (pick by chain).
3. Walk the gate checklist: secrets/keys, upgrade authority, program verification, security criticals, tests/build, monitoring.

## Output
- **CRITICAL BANNER FIRST:** list all CRITICAL/HIGH findings loudly at the very top with `file:line`. Never silently pass them. **This gate is advisory — it does NOT block.** After the banner, state plainly: "advisory only — you decide."
- **Gate results:** each checklist section marked pass / warn / fail with specifics.
- **Deploy runbook:** the devnet-first steps (do now), then the mainnet steps (LATER).
  - Mainnet requires the builder's explicit "yes, mainnet" — state this and STOP for confirmation before running any mainnet command. Cover key handling (env/keychain), upgrade authority (Squads multisig or immutable), verifiable build (`solana-verify`), and monitoring.
