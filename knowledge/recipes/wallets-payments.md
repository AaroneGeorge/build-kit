---
title: Recipe - Wallets & Payments
description: Ship a smart-wallet/payments product (multisig treasury, POS checkout, streaming payroll, gasless onboarding, or custom escrow) in ~6 hours by importing audited primitives instead of hand-rolling custody logic
applies_to: [solana, evm]
sources:
  - "../reuse-index/wallets-payments.md (sibling reuse index - full candidate list, licenses, audit status)"
  - "Squads Protocol v4 - https://github.com/Squads-Protocol/v4 , https://v4-sdk-typedoc.vercel.app/"
  - "Solana Pay - https://github.com/solana-foundation/solana-pay , https://solana.com/docs/tools/solana-pay"
  - "Streamflow js-sdk - https://github.com/streamflow-finance/js-sdk"
  - "Octane - https://github.com/anza-xyz/octane"
  - "solana-foundation/escrow - https://github.com/solana-foundation/escrow"
  - "../testing/per-archetype-tests.md (link - may not exist yet)"
  - "../latency/*.md (link - may not exist yet)"
  - "../solana/tx-landing.md"
last_verified: 2026-08-25
---

## TL;DR - the 6-hour spine

This archetype is a grab-bag of five sub-products (treasury, POS, payroll, gasless onboarding, custom escrow). Pick the ONE that matches the brief before hour 1 — do not try to build all five. The spine below assumes **smart-wallet treasury + Solana Pay checkout** as the default combo (most common ask); swap in the streaming/gasless/escrow steps if the brief calls for those instead.

1. **Pick the primitive, not the pattern.** Custody/multisig → Squads v4 SDK. Point-of-sale/one-off payment → Solana Pay. Payroll/vesting → Streamflow. SOL-less onboarding → Octane (fork). Custom hold-and-release (marketplace, milestone, dispute) → `solana-foundation/escrow` as a skeleton. Do not build a new multisig or a new streaming-payment on-chain program from scratch on a 6h clock.
2. **Stand up the wallet/custody layer first.** If the product needs a smart account: create a Squads v4 vault via `@sqds/multisig` against the deployed mainnet/devnet program (`SQDS4ep65T869zMMBKyuUq6aD6EgTu8psMjkvj52pCf`) — do not deploy your own multisig program. If it's a simple end-user wallet (not a treasury), skip Squads and go straight to a standard wallet-adapter connect flow; only reach for Privy/Turnkey/Web3Auth if the brief explicitly needs email/social-login onboarding for non-crypto users.
3. **Wire the payment surface.** Solana Pay for QR/payment-link checkout: generate the transaction-request URL with `@solana/pay`, render QR client-side, validate amount/mint/recipient **server-side** on the callback (never trust client-confirmation alone).
4. **Add the reference-tracking backend.** Solana Pay gives you the URL spec only — you own the "did this specific order get paid" indexing. Poll or webhook on the reference pubkey via RPC (`getSignaturesForAddress` on the reference key), confirm at `confirmed` minimum before marking paid.
5. **If payroll/vesting is in scope:** call Streamflow's `@streamflow/stream` against the deployed program to create the stream (recipient, rate, cliff, cancel authority) rather than writing release-math yourself.
6. **If gas-sponsorship is in scope:** fork Octane, replace its example validation rules with your own allowlist (specific instruction set, specific mint for fee payment, per-user rate limit) before exposing the relay endpoint publicly. Treat the fee-payer keypair as a hot wallet from minute one (see Dangerous Part #2 below).
7. **If custom escrow is in scope:** fork `solana-foundation/escrow` as the skeleton, but rewrite the release-condition logic (arbiter, timeout, dispute path) — this program is a reference, not a dependency; budget real review time here, not import time.
8. **Build the UI as thin as possible.** wallet-adapter for connect + sign; the payment/escrow/stream state lives on-chain or in the imported SDK, not in your own database as source of truth (a cache/index is fine, source of truth is the chain).
9. **Devnet demo end-to-end before touching mainnet** (see Deploy section) — vault creation, one payment, one stream/escrow release, one relayed gasless tx, whichever subset applies.

## Keep / Change / Cut

| Component | Reuse as-is | Modify | Drop |
|---|---|---|---|
| Multisig/custody program | Squads v4 deployed program (import via `@sqds/multisig`) | — | Do not deploy a custom multisig program |
| Payment-link/QR generation | `@solana/pay` URL builder + QR render | — | — |
| Payment reference indexing/webhook backend | — | Fork the pattern (Solana Pay ships no backend) | — |
| Streaming/vesting/payroll math | Streamflow deployed program via `@streamflow/stream` | Cancel/clawback authority config per your policy | Custom on-chain streaming math |
| Gasless relayer server | Octane skeleton (HTTP API shape) | Fee-payer allowlist, rate limits, tx validation rules (mandatory rewrite) | Octane's example/demo validation rules — never ship these live |
| Escrow hold-and-release | `solana-foundation/escrow` account/PDA skeleton | Release conditions (arbiter, timeout, dispute), rent-recovery on close, decimal/mint checks | Deploying the tutorial code unmodified for real funds |
| Embedded wallet / social login onboarding | Privy or Web3Auth hosted SDK (only if non-crypto-native users are in scope) | Key-export / self-custody messaging to match actual custody model | Building your own MPC key-splitting |
| Checkout UI widget | `@heliofi/react` (MIT) if a prebuilt checkout embed is wanted | — | `heliopay` core (AGPL) unless open-sourcing your fork |
| Wallet connect/sign UX | wallet-adapter | — | Rolling your own signing UI |

## The 3 dangerous parts

1. **Fee-payer / relayer keypair custody (Octane path).** If you fork Octane, the server's fee-payer keypair can be drained by any transaction that passes your validation rules — and Octane's default rules are permissive examples, not production guardrails. Guardrail: allowlist specific instruction types and a specific fee-token mint, cap relayed value per transaction and per user/IP per time window, keep the keypair in a KMS/env-secret (never in a repo or client-reachable path), and alert on relayer balance drops. Load-test the abuse case (spam relay requests) before any public URL goes live.
2. **Escrow release-condition logic (custom escrow path).** `solana-foundation/escrow` is explicitly a teaching skeleton — the dangerous bugs are always in what you add: CPI-ordering issues that let a party front-run a release, missing arbiter/timeout checks that let funds get stuck or double-released, and account-close/rent-recovery bugs that leak or lock rent. Guardrail: write and pass tests for every release path (happy path, dispute, timeout, double-release attempt, close-before-settle attempt) before funding it with anything beyond devnet test tokens; get this specific file reviewed even if the rest of the app skips review.
3. **Payment amount/mint/recipient validation happening only client-side (Solana Pay / checkout path).** A QR code or payment-request URL built client-side, with the "success" state also read client-side, is trivially spoofable — a user can show you a QR that doesn't match what they actually pay, or claim success without paying. Guardrail: the backend that marks an order "paid" must independently fetch the transaction by signature/reference from RPC and re-verify amount, mint, and destination account match the expected order **before** granting access/goods — never trust a client postMessage or redirect param as proof of payment.

## Minimum tests - the 5 non-negotiables

See `../testing/per-archetype-tests.md` (link — file may not exist yet) for the full checklist. For this archetype, at minimum:
1. Multisig/vault creation + a proposal that requires threshold M-of-N to execute (test both under-threshold rejection and threshold-met execution).
2. One full payment round-trip against devnet: generate Solana Pay link → simulate wallet payment → backend independently verifies amount/mint/recipient via RPC lookup, not client callback.
3. Streaming/escrow release path tested for every authority branch (recipient withdraw, sender cancel/clawback, arbiter/dispute if applicable) — not just the happy path.
4. Gasless relay (if in scope): a rejected transaction that violates your allowlist/rate-limit rule, proving the guardrail actually blocks rather than just logs.
5. Idempotency/replay test: re-submitting the same payment reference or the same relay request twice does not double-credit or double-spend.

## Deploy

- **Devnet/demo-first, always.** Stand up the full flow (vault → payment/stream/escrow → confirmation UI) on devnet with devnet SOL/test SPL tokens before any mainnet key touches the project.
- **Key handling:** program-upgrade authority and any fee-payer/relayer keypairs live in env vars or OS keychain (never committed, never in client bundles). For a Squads vault, the vault's own multisig membership *is* your key policy — decide signer set (who holds which of the M-of-N keys) before creating it, since rotating members later requires a proposal.
- **Program verify:** if you deploy any custom program (custom escrow fork, anything beyond calling existing deployed programs), run `anchor verify` / `solana-verify` against the published source so the deployed bytecode is checkable against the repo — do this before mainnet, not after.
- **Upgrade authority:** for any program you deploy yourself (the escrow fork), decide up front whether upgrade authority stays with a single deploy key (fast iteration, higher trust assumption) or moves to the Squads multisig itself (slower, safer) — moving it to the multisig before mainnet launch is the safer default for anything holding real funds.
- **Mainnet is LATER and gated, never automatic.** Explicit human go/no-go checkpoint after devnet demo passes and the 5 minimum tests are green: confirm audit status of every imported program is acceptable for the value at stake (Squads/Streamflow audited; Octane and the escrow skeleton are NOT — extra scrutiny required for those before real funds touch them), confirm license posture (BUSL/AGPL/GPL flags from the reuse index) is acceptable for how you're distributing the product, then deploy with the upgrade-authority/key plan decided above.

## Latency notes

- See `../latency/*.md` (link — may not exist yet) and `../solana/tx-landing.md` for general RPC/landing guidance.
- Payment confirmation UX: poll at `confirmed` commitment for "payment detected, show spinner-done" but treat `finalized` as the bar before releasing goods/access for anything irreversible (physical goods, off-chain settlement) — `confirmed` is fine for low-value/reversible-context checkout.
- Solana Pay reference lookup via `getSignaturesForAddress` is a polling pattern — cache last-seen signature per reference to avoid re-scanning the same address on every poll tick; a webhook-based indexer (or a paid RPC provider's webhook product) beats client-side polling once payment volume grows.
- Squads proposal execution is a normal transaction — landing-rate guardrails from `tx-landing.md` apply (priority fees, retry-with-backoff) especially since proposal execution after threshold approval should not silently fail.
- Octane relay adds a network hop (client → your relay server → RPC) — budget that latency in UX copy ("processing" state) and keep the relay server co-located near your RPC endpoint's region if self-hosting.

## Common pitfalls

- Treating Squads' license ambiguity (AGPL/BUSL signals) as blocking when you're only calling the already-deployed program via SDK — it isn't; re-verify only if you plan to fork/redeploy the program source itself.
- Vendoring Streamflow's GPL-3.0 `js-sdk` or Helio's AGPL `heliopay` core into a closed-source product instead of using them as arm's-length npm/API dependencies — check the reuse index's license flags before bundling.
- Shipping Octane's example validation rules unmodified — this is the single most common way this archetype turns into a "free transactions for anyone" incident.
- Deploying `solana-foundation/escrow` (or any tutorial-grade escrow) unmodified for real funds — it is explicitly not production-hardened.
- Marking a payment "paid" based on a client-side redirect/callback instead of an independent server-side RPC verification of amount/mint/recipient.
- Promising users "self-custody" in marketing copy while using a custodial/MPC embedded-wallet provider (Privy, Web3Auth) without reading that provider's actual key-export flow first.
- Forgetting to decide upgrade-authority ownership (deploy key vs. multisig) before mainnet — this is much more painful to change after funds are flowing.
- Skipping the idempotency/replay test — double-crediting a payment or double-executing a relay request is a direct funds-loss bug, not a UX nit.
