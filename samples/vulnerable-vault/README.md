# vulnerable-vault (buidl-kit EVM test fixture)

An intentionally vulnerable Solidity vault used to exercise `/audit`, `/debrief`, and `/ship` on the EVM path — the counterpart to `../vulnerable-escrow` (Anchor).

**DO NOT DEPLOY.** See `ANSWERS.md` for the seeded issues — do **not** feed `ANSWERS.md` to the reviewer, or you defeat the test.

## Try it
- `/audit samples/vulnerable-vault` — expect the 3 seeded bugs, criticals first, with `file:line`.
- `/debrief samples/vulnerable-vault` — expect all five DEBRIEF sections and the 3 bugs.
- `/ship samples/vulnerable-vault` — expect the criticals surfaced loudly at the top, non-blocking.

The source under review is `src/VulnerableVault.sol`. It has no imports, so no `forge install` is needed to read it. `foundry.toml`'s test script is a no-op stub — the fixture is not meant to be built or deployed; writing the exploit tests (reentrancy drain, fee hijack, rounding-to-zero) is the exercise.
