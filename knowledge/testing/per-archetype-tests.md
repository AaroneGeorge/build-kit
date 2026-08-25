---
title: Per-Archetype Non-Negotiable Tests
description: The 5 must-have tests per product archetype (escrow, DeFi/AMM/vault, launch/bonding-curve, bots/infra, wallets/payments) for the test-gap-finder agent
applies_to: [solana, evm]
sources:
  - "Anchor Docs - Testing / LiteSVM - https://www.anchor-lang.com/docs/testing/litesvm (verified 2026-08-25)"
  - "anchor-litesvm crate - https://crates.io/crates/anchor-litesvm (verified 2026-08-25)"
  - "Solana Foundation - LiteSVM testing guide - https://github.com/solana-foundation/anchor/blob/master/docs/content/docs/testing/litesvm.mdx (verified 2026-08-25)"
  - "Foundry Book - Invariant Testing - https://getfoundry.sh/forge/invariant-testing (verified 2026-08-25)"
  - "Neodyme - Token-2022 extensions gotchas - https://neodyme.io/en/blog/token-2022/ (verified 2026-08-25)"
  - "Solana Docs - Token Extensions overview - https://solana.com/docs/tokens/extensions (verified 2026-08-25)"
  - "QuickNode - How to Test Solana Programs with LiteSVM - https://www.quicknode.com/guides/solana-development/tooling/litesvm (verified 2026-08-25)"
last_verified: 2026-08-25
---

# Per-Archetype Non-Negotiable Tests

Reader = `test-gap-finder` subagent. For each archetype below: the 5 tests that
MUST exist before ship, phrased as one-line assertions an engineer implements
directly. Missing any one of these is a hard finding, not a nice-to-have.
Framework/harness choices and setup live in
`knowledge/testing/frameworks-and-matrix.md` — this file is scope (WHAT to
test), that file is HOW (which tool runs it).

Format per test: **name** (grep-friendly slug) — assertion — why it's non-negotiable.

---

## 1. Deposit / escrow consumer site

(e.g. outbid.lol-style auctions, meme deposit sites, simple wager/pool contracts)

1. **only-winner-withdraws** — call `settle`/`withdraw` from every non-winner
   pubkey (other bidders, random signer, program authority itself) and assert
   each `Err`; only the recorded winner's signature succeeds. Why: the #1 fund-
   drain vector in these apps is a missing or wrong equality check on the
   withdrawer vs. the stored winner `Pubkey`.
2. **no-double-settle** — call `settle`/`withdraw` twice in sequence (same
   winner, same accounts) and assert the 2nd call errors (e.g. account already
   closed / status enum flipped to `Settled`) and the vault balance after call
   1 is unchanged by call 2. Why: replay/double-spend is the #2 drain vector;
   requires an explicit state flag or account-closing, not just "first
   withdrawal empties the vault so 2nd nets zero" (that still burns rent/DoS's
   legit flows if attacker races).
3. **exact-deposit-accounting** — for a Token-2022 mint with a transfer-fee
   extension configured, deposit `N` tokens and assert the program's internal
   ledger records the **post-fee received amount** (use
   `getTransferFeeConfig`/`transferCheckedWithFee` accounting or read the
   `TransferFeeAmount` extension on the destination ATA), not the sender's
   pre-fee `N`; assert total vault token balance == sum of all recorded
   per-depositor accounted amounts at all times. Why: silently trusting the
   instruction's `amount` param instead of the actually-received balance is
   the single most common Token-2022 bug and directly causes insolvency (see
   `knowledge/solana/token-2022.md`).
4. **loser-refund-path** — after settlement, every losing depositor can call
   `refund`/`claim` and receive exactly their original deposit (fee-adjusted
   per test 3) back; a 2nd refund call by the same loser errors; a refund call
   by the winner (who should use `withdraw`, not `refund`) errors or is a
   no-op. Why: refund logic is usually written and tested less carefully than
   the "happy path" winner payout and is a common asymmetric-coverage gap.
5. **settle-requires-auth** — call `settle` before the deposit/reveal window
   has closed, and call it from a signer that is neither the designated
   resolver/oracle/authority nor satisfies the on-chain closing condition
   (e.g. `Clock::unix_timestamp < end_time`), and assert both error. Why:
   missing time-bound or authority checks on `settle` lets anyone force an
   early/incorrect outcome — the archetype's highest-severity single check.

---

## 2. DeFi / AMM / vault

1. **accounting-identity-invariant** — fuzz/invariant test (Foundry
   `invariant_*` or Rust proptest/LiteSVM harness driving randomized
   deposit/withdraw/swap sequences) asserting `sum(internal share/ledger
   balances) == actual on-chain token balance held by the pool/vault` holds
   after every call sequence, run at >= 256 runs / depth >= 15. Why: this is
   the single invariant that catches infinite-mint and drain bugs (Cashio,
   Cream) that unit tests miss because they only hit hand-picked paths.
2. **share-price-manipulation-resist** — simulate a first-depositor / donation
   attack: attacker deposits 1 wei/lamport of shares, then donates a large
   raw token amount directly to the vault (bypassing `deposit`), then a
   normal user deposits; assert the normal user's minted shares are within
   epsilon of the fair value (not zero/rounded-to-zero from inflated
   price-per-share). Why: this is the most common real-world ERC-4626/SPL
   vault exploit class; must use virtual shares/offset or a dead-shares
   floor, and the test must prove it.
3. **withdraw-cannot-exceed-liquidity** — attempt to withdraw/borrow more than
   `totalAssets`/available reserves in one call and assert revert, including
   when reserves are fragmented across multiple pools/strategies the vault
   routes through. Why: under-collateralized withdrawal is the direct cause
   of bank-run insolvency (Euler-class bugs combine this with #1).
4. **oracle-price-staleness-and-bounds** — feed a stale price (timestamp older
   than the configured max age) and a price outside a sane min/max bound and
   assert both cause the calling instruction to revert rather than silently
   using the bad price; also assert a single-block/single-tx price
   manipulation (flash-loan-sized swap immediately before the price read)
   cannot move the price used for a critical accounting decision beyond a
   defined tolerance. Why: stale/manipulated oracle reads are the top DeFi
   loss category (Mango, Nirvana) — untested staleness/bounds checks are the
   most common gap.
5. **fee-and-rounding-direction** — for every fee/rounding computation
   (swap fee, mint/burn rounding, interest accrual), assert rounding always
   favors the protocol/vault over the user (round-down on user receives,
   round-up on user pays) across a fuzzed range of amounts including
   extreme small (1 unit) and extreme large values. Why: rounding-in-favor-
   of-attacker is a silent, compounding drain that unit tests with "nice"
   round numbers never expose.

---

## 3. Launch / mint / bonding-curve

1. **curve-monotonic-and-bounded** — fuzz buy/sell across the full supply
   range and assert price is monotonically non-decreasing with supply (for a
   standard bonding curve) and never returns a negative, zero-when-it-
   shouldn't-be, or overflowing price; assert buy-then-immediate-sell of the
   same amount never yields a net profit greater than the fee (no
   round-trip arbitrage from curve math itself). Why: off-by-one curve math
   is the most common launchpad bug and is invisible in a 2-3 point manual
   test.
2. **graduation-migration-atomicity** — trigger the migration point (curve
   hits target market cap / liquidity threshold) and assert liquidity moves
   to the destination AMM pool (or is unlocked) exactly once, the source
   curve becomes permanently non-tradeable/closed after migration, and a
   2nd migration attempt errors. Why: double-migration or a stuck
   in-between state is a common drain/DoS vector at the highest-TVL moment
   of a launch's lifecycle.
3. **mint-authority-revoked-post-launch** — after the configured supply is
   fully minted (or curve completes), assert the mint authority and freeze
   authority are `None`/revoked on-chain (read the mint account directly,
   don't trust an event/log) and that any further "admin mint" instruction
   errors. Why: a live mint authority post-launch is a rug vector and the
   #1 thing scout/audit tooling and users check first.
4. **creator-fee-cannot-exceed-cap** — attempt to set/withdraw creator or
   platform fees above the documented cap (e.g. via a param on curve
   creation or a fee-update instruction) and assert it errors or clamps;
   assert cumulative fees taken across the curve's lifetime never exceed
   `cap * volume`. Why: unbounded or admin-adjustable fee params are a
   common "slow rug" that passes casual review.
5. **anti-snipe-per-wallet-cap** — if the archetype has a max-buy-per-wallet
   or cooldown for the initial window, assert a single wallet (and a wallet
   using multiple ATAs/token accounts for the same mint, if applicable)
   cannot exceed the cap within the restricted window, and that the cap
   correctly lifts after the window per the documented condition. Why: cap
   bypass via multiple accounts is a frequent launch-fairness bug that's
   easy to write incorrectly (checking ATA balance instead of a
   wallet-keyed PDA counter).

---

## 4. Bots / infra (indexers, keepers, off-chain executors, relayers)

1. **idempotent-on-replay** — feed the same on-chain event/webhook/tx twice
   (simulating an RPC re-delivery or restart-replay) and assert the bot's
   side effect (DB write, on-chain tx submission, notification) happens
   exactly once, using a unique key (tx signature + instruction index, or
   slot+logIndex) with a DB unique constraint or dedupe check. Why: bots
   that re-process on reconnect/restart double-execute trades, payouts, or
   alerts — the most common infra-class bug.
2. **reorg-rollback-handled** — simulate a chain reorg / dropped-then-
   different-tx-landed-in-slot scenario (or on Solana: a finalized-vs-
   confirmed commitment mismatch) and assert the bot's recorded state is
   reconciled to the canonical chain state, not left pointing at an orphaned
   tx. Why: bots that index at `confirmed` (or don't handle rollback) act on
   state that later reverts, causing incorrect payouts/alerts.
3. **crash-mid-tx-recovers-cleanly** — kill the process (or inject a failure)
   between "tx submitted" and "tx confirmed recorded" and assert on restart
   the bot queries actual on-chain state before re-submitting, never
   blindly re-sends (which risks double-submission) nor silently drops the
   pending action. Why: this is the standard cause of duplicate on-chain
   actions or permanently stuck state in unattended infra.
4. **rate-limit-and-backoff-respected** — assert RPC calls implement
   exponential backoff + jitter on 429/5xx and that a burst of triggering
   events doesn't fan out into an unbounded number of concurrent RPC/tx
   submissions (assert a concurrency cap/queue exists and is enforced).
   Why: naive bots DoS themselves against rate-limited RPC providers or
   spam duplicate transactions under load, which is the top cause of
   "it worked in testing, died in prod."
5. **secrets-never-logged-or-thrown** — assert that a thrown error / log line
   from any code path touching the signing keypair, private RPC URL, or API
   key never includes the raw secret (grep test output/log capture for the
   known secret value) even under an intentionally-forced error. Why: leaked
   keypairs from verbose error logs/Sentry/console are a recurring real-world
   bot-infra incident class, and it's cheap to test for directly.

---

## 5. Wallets / payments

1. **signing-request-matches-display** — for every transaction the app asks a
   user to sign, assert the simulated/decoded instruction set matches
   exactly what's rendered in the UI confirmation (same program IDs,
   amounts, destination addresses) — build this as a snapshot/diff test
   between the built `Transaction`/`VersionedTransaction` and the UI's
   parsed summary. Why: a mismatch between what's shown and what's signed is
   the core of wallet-drainer attacks; this is the highest-value test in
   the whole archetype.
2. **payment-amount-and-destination-locked** — assert the built transfer
   instruction's amount and destination are read from the app's own
   validated state (not re-derived from mutable client-side/URL/query-param
   input after the user confirmed) — mutate the query param / URL after
   confirmation and assert the signed tx is unaffected. Why: parameter
   injection between "user sees amount X to address Y" and "tx is built" is
   a common payment-flow bug class.
3. **insufficient-balance-rejected-pre-sign** — attempt a payment exceeding
   available balance (including reserved rent-exempt minimum on Solana, or
   gas reserve on EVM) and assert the app blocks/errors before requesting a
   signature, not after a failed on-chain submission. Why: UX aside, letting
   an underfunded tx reach signing risks partial-state confusion (e.g.
   ATA-creation succeeds, transfer fails) that users misread as "it went
   through."
4. **duplicate-payment-guarded** — submit the same payment intent twice in
   quick succession (double-click, network retry) and assert only one
   on-chain transfer results — via idempotency key, disabled-button +
   in-flight lock, or a client-side nonce/blockhash reuse check. Why: double-
   submit on a payment button is the single most common real-world wallet
   bug users hit, and it's rarely covered in "happy path only" test suites.
5. **wrong-network-blocked** — attempt to sign/submit when the connected
   wallet's cluster/chain (devnet/mainnet, or wrong EVM chainId) doesn't
   match the app's expected network, and assert the app blocks the action
   with a clear error rather than submitting (which either fails silently
   or, worse, succeeds against the wrong network's contract with the same
   address). Why: chainId/cluster mismatches cause "funds sent, nothing
   happened" support tickets and, on EVM, can hit a same-address contract
   with different logic on the wrong chain.

---

## Cross-archetype notes for test-gap-finder

- Treat this file as the **minimum bar**: 5 tests here missing = 5 findings,
  full stop, regardless of what other coverage exists.
- Map each test above to a concrete harness per
  `knowledge/testing/frameworks-and-matrix.md` (Solana Rust: LiteSVM /
  `anchor-litesvm` for unit+integration, `solana-test-validator` only when
  real RPC behavior is required; EVM: Foundry `forge test` + `forge
  invariant`).
- When a program touches Token-2022, cross-reference
  `knowledge/solana/token-2022.md` — extension-specific behavior (transfer
  fees, transfer hooks, permanent delegate) changes the exact assertion in
  tests 1.3 and 2.1/2.5.
- A test that only exercises the happy path does not satisfy any item above —
  each one requires the explicit negative/adversarial case described.

## See also

- `knowledge/testing/frameworks-and-matrix.md` — harness/tool choice per
  language and archetype
- `knowledge/solana/token-2022.md` — extension-specific accounting traps
- `knowledge/security/incident-lessons.md` — real exploits behind tests 2.1,
  2.2, 2.4, 3.3
- `knowledge/security/evm-audit-checklist.md` — broader EVM checklist these
  tests feed into
- `knowledge/solana/client-patterns.md` — client-side tx building patterns
  relevant to wallet/payments tests
