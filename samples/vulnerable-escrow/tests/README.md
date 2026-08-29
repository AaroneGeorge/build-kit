# tests/ — intentionally empty

This fixture ships without tests on purpose: writing the exploit tests for the three seeded bugs **is the exercise**.

Try it:

1. Run `/debrief samples/vulnerable-escrow` and let the reviewer find the bugs.
2. Write a failing test per finding (LiteSVM is the default — see `knowledge/testing/frameworks-and-matrix.md`): the unsigned-`settle` drain, the substituted `vault`/`recipient` accounts, the overflow/underflow on `total_deposited`.
3. Check yourself against `../ANSWERS.md` (don't feed it to the reviewer first).

`Anchor.toml`'s test script is a no-op stub — the fixture is not meant to be built or deployed.
