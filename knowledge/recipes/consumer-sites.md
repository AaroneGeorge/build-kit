---
title: Recipe - Consumer Sites with Light Contracts (Deposit / Escrow / Payout, Auction-Style)
description: 6-hour ship plan for outbid.lol-style deposit/auction/payout apps — fork the vault mechanics, don't design them
applies_to: [solana]
sources:
  - "../reuse-index/consumer-sites.md (sibling reuse index — full candidate detail, licenses, audit status)"
  - "solana-foundation/program-examples - https://github.com/solana-foundation/program-examples (verified 2026-08-25)"
  - "metaplex-foundation/metaplex-program-library (auction-house) - https://github.com/metaplex-foundation/metaplex-program-library (verified 2026-08-25)"
  - "udbhav1/solana-auctionhouse - https://github.com/udbhav1/solana-auctionhouse (verified 2026-08-25, re-verify commit recency + license)"
  - "solana-foundation/create-solana-dapp - https://github.com/solana-foundation/create-solana-dapp (verified 2026-08-25)"
  - "../security/solana-audit-checklist.md"
  - "../testing/per-archetype-tests.md"
  - "../solana/tx-landing.md"
last_verified: 2026-08-25
---

Flagship archetype. This is the outbid.lol pattern: a Next.js frontend + a thin Anchor program holding native SOL (or SPL) in a PDA vault while a deposit, bid, or escrow trade resolves — highest bid wins, losers get refunded, or a counterparty pays out on a condition. Nothing here should be designed from scratch. Full candidate detail, licenses, and audit status live in the sibling reuse index — this recipe just sequences the fork.

## TL;DR - the 6-hour spine

1. **(0:00-0:30) Scaffold the frontend.** Run `create-solana-dapp` with the Anchor-integrated template (not the plain wallet-only one) — this pre-wires `@solana/wallet-adapter` and a program skeleton. Don't hand-build wallet connect.
2. **(0:30-1:30) Fork the vault program.** Start from `solana-foundation/program-examples` — copy `basics/escrow` (Anchor variant) if you need bilateral trade logic, or `basics/transfer-sol` + `basics/pda-rent-payer` if you just need a PDA-owned SOL vault for deposits/bids. Rename accounts/instructions to your domain (e.g. `AuctionSlot`, `Bid`).
3. **(1:30-2:30) Layer in real bid/escrow logic.** Read Metaplex Auction House's trade-state PDA pattern and `coral-xyz/anchor tests/escrow`'s init/cancel/exchange idioms for correct CPI/close-account structure. For the actual "cumulative outbid, refund the loser" mechanic, read `udbhav1/solana-auctionhouse` — it's the closest existing shape to outbid.lol. Treat it as a reference to port logic from, not code to paste in wholesale (unaudited, license unclear — re-verify before any direct reuse).
4. **(2:30-3:30) Add payout/treasury if proceeds need multi-approver control or vesting.** Skip this step entirely if a single-owner payout PDA is enough (it usually is for a v1). Only reach for Squads `smart-account-program` (multisig treasury) or Streamflow SDK (timed/milestone payout) if the brief explicitly needs that.
5. **(3:30-4:30) Wire frontend to program.** Anchor TS client + `wallet-adapter-react` hooks from the scaffold; bid form, current-high-bid display, countdown, refund-claim button.
6. **(4:30-5:15) Devnet deploy + smoke test.** Deploy program to devnet, run the 5 non-negotiable tests below against it, fix findings.
7. **(5:15-6:00) Demo polish.** Loading/error states for tx confirmation, optimistic UI for bid submission, empty states. Ship the demo link; mainnet is a separate later step (see Deploy section).

## Keep / Change / Cut

| Component | Reuse as-is | Modify | Drop |
|---|---|---|---|
| Wallet connect UI | `@solana/wallet-adapter-react-ui` components | — | hand-rolled connect modal |
| Frontend scaffold | `create-solana-dapp` Next.js structure | routing/pages for your bid/deposit flow | dapp-scaffold (archived, don't start here) |
| PDA vault mechanics | — | `program-examples/basics/transfer-sol` + `pda-rent-payer` renamed to your accounts | writing PDA seed/rent logic from scratch |
| Escrow init/cancel/exchange idiom | — | port `coral-xyz/anchor tests/escrow` account-constraint pattern into your instructions | — |
| Auction trade-state / bid-escrow pattern | — | port the shape from Metaplex Auction House (pattern only — don't vendor the AGPLv3 Rust program) | building bid-escrow PDA layout from a blank page |
| Cumulative-outbid + refund logic | — | port and re-verify from `udbhav1/solana-auctionhouse` — security pass required before mainnet | trusting it unaudited/as-is |
| Multi-approver treasury | Squads `smart-account-program` (import-as-dep) if genuinely needed | — | hand-rolled multisig, unless brief has no multi-approver requirement |
| Streaming/vesting payout | Streamflow SDK (import-as-dep) if genuinely needed | — | hand-rolled vesting math |
| Payment-link checkout (if deposit = fiat-adjacent purchase, not on-chain bid) | Helio `heliopay` embed | — | building a custody-model payment processor yourself |
| Fee handling, duplicate-bid guards, reentrancy/close-account edge cases | — | add yourself — every example above explicitly skips this | shipping the teaching-example version unmodified |

## The 3 dangerous parts

1. **Refund-on-outbid / cancel path (fund loss via reentrancy or missed refund).** The single most common bug class in hand-rolled auction programs (per the `solana-auctionhouse` known-pitfalls): a new bid comes in, the previous bidder's escrowed SOL must be returned atomically in the same instruction before/while accepting the new bid. Guardrail: refund via a checked lamport transfer *before* updating the current-high-bidder state, use `#[account(mut, close = ...)]` correctly on any closed bid-escrow PDA (never let a closed PDA's rent leak or double-close), and write a test that submits two bids back-to-back and asserts the first bidder's balance is restored exactly. Cross-check against `../security/solana-audit-checklist.md`.
2. **PDA vault authority / signer checks (fund theft via missing owner check).** Any instruction that moves lamports or tokens out of the vault PDA must verify the caller is the legitimate party (auction winner, original depositor, or a program-derived authority) — not just that the account exists. This is where `program-examples`' "minimal validation of counterparty accounts" pitfall bites hardest. Guardrail: every withdrawal/settlement instruction needs an explicit `has_one` or seeds-based constraint tying the destination account to the state account, and a test that attempts a withdrawal from a non-winner wallet and asserts it fails.
3. **Auction-close timing / off-by-one on end slot or timestamp.** Bids accepted after the auction should have closed (or a settle-before-close race) let an attacker snipe or grief the auction. Guardrail: compare against `Clock::get()?.unix_timestamp` (or slot) with an explicit `require!` on both the bid instruction and the settle instruction, add a grace-period/anti-snipe extension if the demo needs it, and write a test that attempts a bid one second after the configured end time and asserts rejection.

## Minimum tests - the 5 non-negotiables

See `../testing/per-archetype-tests.md` for the full per-archetype matrix; for this archetype the floor is:
1. Deposit/bid succeeds and vault PDA balance increases by exactly the bid amount (no fee-skim surprises).
2. Outbid refunds the previous bidder exactly, atomically, in the same or immediately-following instruction (dangerous part #1).
3. Non-winner cannot withdraw/settle vault funds (dangerous part #2).
4. Bid after auction end is rejected; settle before auction end is rejected (dangerous part #3).
5. Double-settle / double-close on the same auction/escrow PDA fails cleanly (no double-spend, no panics that brick the account).

## Deploy

**Devnet/demo first, always.** Deploy the program to devnet, point the frontend's cluster config at devnet, and run the full 5-test suite plus a manual demo pass before anything touches mainnet.

- **Key handling:** never commit a keypair. Program upgrade authority and any deployer key live in an env var (`ANCHOR_WALLET` / `SOLANA_KEYPAIR_PATH`) pointing at a local file outside the repo, or in the OS keychain for local dev; for CI/deploy automation use a secrets manager, not a checked-in `.json` keypair.
- **Program verify:** after deploying, run `anchor verify` (or `solana-verify`) so the on-chain program hash is checkably tied to the published source — do this even for the devnet deploy as a dry run, and treat it as required before mainnet.
- **Upgrade authority:** keep upgrade authority on a dedicated deploy key (not your personal wallet) during development; before mainnet launch decide explicitly whether to transfer authority to a multisig (Squads, see reuse index) or burn it (immutable program) — burning is safer for user trust but forecloses bug fixes, so this is a product decision to surface to the human, not to default silently.
- **Mainnet is LATER and gated, never automatic.** Do not deploy to mainnet-beta as part of a standard build flow. Mainnet deploy requires: the 5 non-negotiable tests passing on devnet, the dangerous-parts checklist above explicitly reviewed, and explicit human sign-off (funds are at stake). If any candidate program logic was ported from an unaudited source (`solana-auctionhouse`, or your own new escrow logic), flag that a security pass — see `../security/solana-audit-checklist.md` — happens before mainnet, not after.

## Latency notes

- Bid submission and outbid updates are the UX-critical path — see `../solana/tx-landing.md` for landing/confirmation strategy (priority fees, retry-on-drop, confirming on `confirmed` not `finalized` for UI responsiveness while still verifying `finalized` before showing a bid as truly settled).
- Live "current high bid" display should not poll raw RPC per-client; use an account-subscribe/websocket pattern or a light indexing/caching layer per `../latency/rpc-and-realtime.md` and `../latency/indexing-caching-db.md` — a naive `getAccountInfo` poll loop across many concurrent bidders is the most common latency/cost mistake in this archetype.
- For auction countdowns, derive time-remaining from on-chain `Clock`/end-timestamp fetched once plus a local `setInterval`, not repeated RPC calls — RPC is only the source of truth for the *state transition* (settled, refunded), not for ticking a clock client-side.

## Common pitfalls

- Mixing native-Rust and Anchor account layouts when copying from `program-examples` — the two variants live in different subfolders and are not interchangeable.
- Vendoring Metaplex Auction House's Rust program (AGPLv3) or Squads' `smart-account-program` (AGPL-3.0) into a closed-source product without accepting copyleft obligations — import their JS SDKs / call their deployed instances instead if you need to stay closed-source.
- Treating Auction House's "escrowless" NFT-stays-in-wallet model as the pattern for a pure deposit auction — it's the wrong shape for outbid.lol-style flows, which need funds actually locked in a vault; use it for trade-state/PDA idioms only.
- Shipping `udbhav1/solana-auctionhouse` logic without re-verifying its license and without a security pass on bid-cancellation and settlement — it is explicitly unaudited, hackathon-grade reference code.
- Reaching for Squads multisig or Streamflow vesting when a single-owner payout PDA would do — both add real integration and UX overhead (member key management, SDK version pinning) that isn't worth it unless the brief actually calls for multi-approver control or timed vesting.
- Forgetting fee-payer/rent economics: `pda-rent-payer` example handles rent-exempt PDA creation, but who pays rent on bid-escrow PDAs that get created/closed repeatedly (one per bid) needs an explicit decision — usually the bidder pays their own PDA's rent and gets it back on refund/close.
- Pinning SDK versions for Streamflow/Squads if used — both ecosystems have had breaking changes across major versions.
