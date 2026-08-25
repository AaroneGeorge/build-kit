---
title: Recipe - DeFi Trading (DEX/AMM, Aggregators, Vaults, Staking)
description: Ship a Solana DeFi trading app in ~6 hours by routing through Jupiter and importing audited protocol SDKs instead of writing pool/lending/staking math from scratch.
applies_to: [solana]
sources:
  - "./../reuse-index/defi-trading.md (sibling reuse index - full candidate list, licenses, audit trails)"
  - "Jupiter docs - https://dev.jup.ag/"
  - "Orca Whirlpools SDK docs - https://orca-so.github.io/whirlpools/"
  - "Drift Protocol v2 SDK docs - https://drift-labs.github.io/protocol-v2/sdk/"
  - "Kamino klend-sdk / audits - https://github.com/Kamino-Finance/klend-sdk , https://github.com/Kamino-Finance/audits"
  - "SPL Stake Pool docs - https://spl.solana.com/stake-pool"
last_verified: 2026-08-25
---

Reuse-first posture: almost nothing in this archetype needs new pool, matching-engine, or interest-rate math. Default to routing swaps through **Jupiter** and importing the target protocol's official TS SDK for anything else (LP, perps, lending, staking). Only fork on-chain program code when the product genuinely needs custom pool logic (e.g. a new LST). See the sibling reuse index for full license/audit detail per candidate.

## TL;DR - the 6-hour spine

1. **Pick the sub-archetype and its base reuse candidate** (do not skip - this decides everything downstream): swap/trading UI -> **Jupiter API/SDK** (jup-ag); custom LP/AMM position management -> **Orca Whirlpools TS SDK**; perps -> **Drift Protocol v2 TS SDK**; lending/leveraged vault -> **Kamino klend-sdk**; liquid staking token -> fork **SPL Stake Pool**. Default assumption below is the swap/trading path since it's the most common request; branch notes call out the others.
2. **Scaffold the app from Jupiter's official Next.js example / Terminal widget** (dev.jup.ag examples repo) rather than a blank Next.js app - it already wires wallet-adapter, RPC config, and a quote/swap flow.
3. **Wire quotes + swaps against the Jupiter Swap API** (`/quote` then `/swap`) as the default trading path - import-as-dep, do not reimplement routing. For a single-venue AMM instead, import Orca's SDK quote functions (`swapQuoteByInputToken` etc.) - never hand-roll tick/sqrt-price math.
4. **For lending/vault/staking branches, pull position and health data only from the protocol's own SDK** (Kamino klend-sdk obligation/health calls, Drift `User` account health, SPL Stake Pool `getStakePoolAccount`) - this is a funds-safety rule, not a style preference (see Dangerous Part #2 below).
5. **Add wallet-adapter for signing** (`@solana/wallet-adapter-react` + a couple of wallet connectors) and use **versioned transactions + address lookup tables** - Jupiter routes and Drift/Kamino instructions routinely exceed legacy tx size.
6. **Add the guardrails from "3 dangerous parts" before any real-money test**: slippage/price-impact cap, mint/Token-2022-extension check, and a simulate-before-send step.
7. **Run the devnet/demo runbook** (see Deploy) end-to-end with a burner wallet and tiny notional before touching mainnet.
8. **Gate mainnet behind an explicit manual flag** - never auto-promote from demo mode.

## Keep / Change / Cut

| Reuse as-is | Modify | Drop (don't build) |
|---|---|---|
| Jupiter `/quote` + `/swap` API/SDK for routing and building swap transactions | Jupiter Terminal / example Next.js UI - reskin branding, trim to your flow | Your own multi-venue swap router - Jupiter already aggregates every major Solana DEX |
| Orca Whirlpools SDK quote/position functions for CLMM math | Position/LP UI copy and risk warnings for your product's users | Hand-rolled tick-spacing / sqrt-price math (Orca or Meteora SDK owns this) |
| Kamino klend-sdk obligation, health-factor, and liquidation-threshold reads | Which markets/reserves you expose in the UI | Independent recomputation of health factor / interest accrual |
| Drift v2 TS SDK for order placement and account/health management | Order-entry UX (market vs. limit, leverage slider bounds) | Custom perps matching engine or funding-rate logic |
| SPL Stake Pool program as the base for a new LST | Validator list, commission, and manager-authority config | A brand-new on-chain stake-accounting program from scratch |
| Audit reports already published for the chosen protocol (Meteora, Kamino, Orca, SPL Stake Pool all have strong trails) | N/A - re-verify the specific report is still current before shipping | Commissioning your own audit before an MVP is even live |

## The 3 dangerous parts

1. **Slippage, price impact, and swap execution risk (MEV/sandwich, stale quotes).** A quote a few seconds old can execute at a materially worse price, and unbounded slippage tolerance is a direct funds leak. Guardrail: enforce a max `slippageBps` (or use Jupiter's dynamic slippage) and hard-reject any quote whose `priceImpactPct` exceeds a product-defined ceiling before it ever reaches a sign prompt; re-quote immediately before signing, not on page load; simulate the built transaction (`simulateTransaction`) and check for failure/insufficient-output before sending; for larger trades consider Jito bundles to reduce sandwich exposure.
2. **Oracle-derived health/liquidation math in lending, perps, and leveraged vaults (Kamino, Drift, marginfi).** Recomputing health factor, liquidation price, or interest accrual client-side - even "just for display" - drifts from the on-chain source of truth and can show a user a safe-looking position that is actually liquidatable. Guardrail: always read health/liquidation/obligation data directly from the SDK's account-derived calls, never reimplement the formula; refresh oracle/account state immediately before allowing a borrow, withdraw, or leverage-increasing action; treat a stale or unrefreshed oracle read as a blocking error, not a warning.
3. **Token and authority safety (malicious mints, Token-2022 extensions, blind-signed instructions, upgrade authority).** A malicious or unexpected mint (transfer-fee, transfer-hook, or freeze-authority extensions under Token-2022) can silently tax or block a "successful" swap, and a swap route that includes unexpected instructions can drain more than intended. Guardrail: resolve and display the actual `tokenProgram` and any Token-2022 extensions for both legs of a trade before signing; decode and diff the instructions in a built swap transaction against the expected route before prompting the wallet to sign (don't blind-sign arbitrary route output); if you forked/deployed your own on-chain program, keep its upgrade authority off your personal keypair (see Deploy) so a compromised dev key can't rug the program itself.

## Minimum tests - the 5 non-negotiables

Full checklist: [`knowledge/testing/per-archetype-tests.md`](../testing/per-archetype-tests.md) (link - file may not exist yet).

1. **Devnet/local round-trip swap**: quote -> build tx -> simulate -> send -> confirm, against real or cloned market state (see Deploy note on devnet liquidity gaps).
2. **Slippage/price-impact guard**: a quote above the configured `priceImpactPct` or slippage ceiling is rejected before reaching the sign step.
3. **Health-factor / liquidation test sourced from the SDK**: assert your UI's displayed health value matches the SDK's own obligation/account read, not an independently reimplemented formula.
4. **Malicious/unexpected mint rejection**: a Token-2022 mint with an unexpected transfer-fee, transfer-hook, or freeze authority is flagged or blocked, not silently swapped.
5. **Blockhash-expiry / duplicate-send retry**: a transaction that times out before confirmation is retried or re-quoted safely, without double-spending or double-submitting on the user's behalf.

## Deploy

Devnet/demo-first; mainnet is LATER and explicitly gated - never auto-promoted.

1. **Devnet or local dry run first.** Many of these protocols (Jupiter's aggregated liquidity, Orca/Meteora pools, Drift markets) have thin or no devnet liquidity. Prefer `solana-test-validator` with `--clone` of the real mainnet program + a few live market/pool accounts for realistic testing, or use a protocol's official devnet deployment where one exists (Drift publishes devnet markets; check current docs per protocol).
2. **Demo mode on mainnet-beta before "real" mainnet.** Use a funded burner wallet, hard-cap notional per trade/deposit in app config, and keep a feature flag that must be explicitly flipped to allow real user funds - default off.
3. **Key handling.** Never commit any keypair. Local/dev signer keys live in env vars or the OS keychain, not in source. Client-side user signing goes through wallet-adapter (the user's own wallet extension) - your app/server should never hold user private keys. Any backend automation key (a cranker, a keeper bot) belongs in a secrets manager or OS keychain, scoped to the minimum funds needed to operate.
4. **Program verify.** If you forked or deployed your own on-chain program (e.g. a stake-pool fork), run `anchor verify` / `solana-verify` to confirm the deployed program's on-chain hash matches your source before pointing any traffic - demo or mainnet - at it.
5. **Upgrade authority.** Before mainnet, move the program's upgrade authority off your personal keypair to a multisig (e.g. Squads); document who can sign an upgrade and under what process. For programs you only integrate with (Jupiter, Orca, Kamino, Drift, SPL Stake Pool), you don't own upgrade authority, but confirm you're pointing at the canonical deployed program ID, not an impostor.
6. **Mainnet promotion is a manual, gated step.** Require an explicit human approval (not a CI auto-deploy) to lift the demo-mode notional cap, with monitoring/alerting on trade volume and failure rate in place first.

## Latency notes

Full guidance: `knowledge/latency/*.md` (link - files may not exist yet) and [`knowledge/solana/tx-landing.md`](../solana/tx-landing.md).

- **RPC**: public RPC endpoints rate-limit hard under trading load; use a paid low-latency provider (Helius, Triton, QuickNode) plus your own Jupiter API key once past the free lite-api tier.
- **Priority fees**: use dynamic priority fees (Jupiter's `prioritizationFeeLamports: "auto"` or a priority-fee API from your RPC provider) rather than a fixed value - underpriced fees are the most common cause of "my swap didn't land."
- **Quote freshness vs. caching**: cache static metadata (mint decimals, market/pool addresses, symbol/logo) aggressively - it rarely changes. Never cache a price quote beyond a second or two; re-quote immediately before the user signs, especially in volatile markets.
- **Tx landing**: use versioned transactions + address lookup tables (Jupiter/Drift/Kamino instructions routinely exceed legacy tx size); implement blockhash-expiry-aware retry/re-quote rather than blindly resubmitting the same signed tx. See `knowledge/solana/tx-landing.md` for general landing patterns.
- **Live account/oracle reads**: for perps (Drift JIT/DLOB) and lending health (Kamino), prefer WebSocket account subscriptions over polling - health and price data go stale fast and polling adds latency exactly when it matters most (near liquidation, near JIT auction windows).

## Common pitfalls

- **Raydium SDK v2 is GPL-3.0** - copyleft can force obligations on a closed-source app; get legal review before bundling, or integrate against the IDL directly instead.
- **Phoenix is BUSL-1.1 until 2027-02-13** - not OSI open-source yet; confirm current commercial-use terms before relying on it in production before the change date.
- **OpenBook v2 has GPL-gated pieces behind an `enable-gpl` feature flag** and needs off-chain crank/consume-events infrastructure to settle trades - budget for that separate service if you integrate it.
- **`@mrgnlabs/marginfi-client-v2` is deprecated** - check docs.marginfi.com for the current recommended SDK package before starting new marginfi integration work.
- **SPL Stake Pool needs an epoch-boundary cranker** (update validator list / update pool balance) every epoch, or deposits and withdrawals stall - this is an off-chain cron job you must run, not optional maintenance.
- **mSOL (Marinade) does not track 1:1 with SOL** - its exchange rate accrues via an internal oracle; never assume 1:1 in UI or accounting for any LST.
- **Meteora DLMM bin liquidity can be thin outside the active bin** - larger trades can see much worse slippage than a naive quote suggests; always use the SDK's real quote function, not a static price.
- **Concentrated-liquidity math (Orca/Meteora) is easy to get subtly wrong by hand** - always use the SDK's quote/position helpers, never reimplement tick or bin math.
- **Jito StakeNet is automation on top of SPL Stake Pool, not a standalone staking program** - don't confuse "integrate StakeNet" with "you have a working LST"; you still need the base stake-pool program.
- **License/audit status changes over time** - re-verify current license text and latest audit report links for whichever SDK you pick immediately before shipping, per the sibling reuse index.
