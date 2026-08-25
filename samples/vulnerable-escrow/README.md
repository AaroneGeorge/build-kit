# vulnerable-escrow (buidl-kit test fixture)

An intentionally vulnerable Anchor program used to test `/debrief` and `/ship`.

**DO NOT DEPLOY.** See `ANSWERS.md` for the seeded issues — do **not** feed `ANSWERS.md` to the reviewer, or you defeat the test.

## Try it
- `/debrief samples/vulnerable-escrow` — expect all five DEBRIEF sections and the 3 seeded bugs reported with `file:line`.
- `/ship samples/vulnerable-escrow` — expect the criticals surfaced loudly at the top, non-blocking.

The source under review is `programs/vulnerable-escrow/src/lib.rs`.
