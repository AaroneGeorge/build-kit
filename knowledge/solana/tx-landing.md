---
title: Solana Transaction Landing & Compute Playbook
description: Priority fees, Jito bundles, ALTs, RPC send strategy, retries, nonces, and confirmation levels for reliably landing Solana transactions
applies_to: [solana]
sources:
  - "Solana docs - Compute Budget - https://solana.com/docs/core/fees/compute-budget (verified 2026-08-25)"
  - "Helius - How to Land Transactions on Solana - https://www.helius.dev/blog/how-to-land-transactions-on-solana (verified 2026-08-25)"
  - "Helius - getRecentPrioritizationFees guide - https://www.helius.dev/docs/rpc/guides/getrecentprioritizationfees (verified 2026-08-25)"
  - "Jito Labs - Low Latency Transaction Send docs - https://docs.jito.wtf/lowlatencytxnsend/ (verified 2026-08-25)"
  - "Jito Foundation - Tip Payment Program - https://jito-foundation.gitbook.io/mev/mev-payment-and-distribution/tip-payment-program (verified 2026-08-25)"
  - "Solana docs - Durable Nonces - https://solana.com/docs/core/transactions/durable-nonces (verified 2026-08-25)"
  - "Solana docs - Address Lookup Tables - https://solana.com/developers/guides/advanced/lookup-tables (verified 2026-08-25)"
  - "Helius - Dedicated Staked Connections - https://docs.helius.dev/solana-rpc-nodes/dedicated-staked-connections (verified 2026-08-25)"
last_verified: 2026-08-25
---

# Transaction Landing & Compute Playbook

REUSE-FIRST: don't hand-roll retry/land logic. Use `jito-ts` (npm, Apache-2.0, maintained by Jito Labs) or `jito-js-rpc` for bundles, and Helius's **Sender** (paid, zero-slot-optimized) or Priority Fee API instead of building your own fee heuristics. Triton/Helius staked connections replace hand-built rebroadcast-to-many-RPCs logic.

## 1. Compute Budget: always set both instructions

Every tx that isn't trivial should set `ComputeBudgetProgram.setComputeUnitLimit` and `setComputeUnitPrice` as the **first two instructions**. Only one of each per tx (extras get dropped/error).

```ts
import { ComputeBudgetProgram } from "@solana/web3.js"; // or @solana/kit equivalent

const cuLimitIx = ComputeBudgetProgram.setComputeUnitLimit({ units: 300_000 });
const cuPriceIx = ComputeBudgetProgram.setComputeUnitPrice({ microLamports: 50_000 });
tx.add(cuLimitIx, cuPriceIx, ...yourIxs);
```

- Total tx priority fee (lamports) = `ceil(microLamports * CU_limit / 1_000_000)`. Fee is charged on the **requested** limit, not actual usage — don't over-request.
- Default per-instruction CU allocation is 200,000; tx max is 1,400,000 (`MAX_COMPUTE_UNIT_LIMIT`). Block-level cap ≈ 48M CU.
- **Estimate CU via simulation**: `simulateTransaction` with `sigVerify: false`, read `unitsConsumed`, then set limit to that + ~10-20% headroom. Never ship with the 200k default on a multi-CPI ix — you'll either overpay or run out of budget.
- Smaller CU requests schedule better under leader congestion — right-size, don't pad to 1.4M "to be safe."

### Setting the price: don't guess

```ts
// getRecentPrioritizationFees — cheap, built into every RPC
const fees = await connection.getRecentPrioritizationFees({ lockedWritableAccounts: [yourHotAccount] });
```
- Pass `lockedWritableAccounts` scoped to the accounts your tx actually writes to (e.g. the AMM pool, not just your wallet) — global fee stats undersell what's needed for hot accounts.
- Data is cached ~150 recent blocks; take a percentile (p50 for normal, p75-p90 under congestion) rather than the max.
- Reuse-first: Helius Priority Fee API and Triton's priority-fee endpoint do the percentile math for you — prefer these over hand-rolled logic in production.
- Helius staked-connection minimum: **10,000 lamports total priority fee** to qualify — below that you're not really using the staked path even if the URL supports it.
- "Pay more = always lands" is false above the market rate — once you clear the block's inclusion threshold, extra doesn't help; it only helps you win the *auction* on congested slots.

## 2. RPC / send strategy

| Setting | Normal | Congested / MEV-sensitive |
|---|---|---|
| Endpoint | standard RPC `sendTransaction` | staked connection (Helius/Triton paid tier) |
| `skipPreflight` | `false` (catches broken txs before paying fee) | `true` only if you fully validate client-side (sig, blockhash, simulate) — advanced users only |
| `maxRetries` | `0`, do your own loop | `0`, do your own loop |
| `preflightCommitment` | match your `sendTransaction` commitment | same |

- Staked connections route to current/upcoming leaders via SWQoS (stake-weighted QoS), bypassing the public gossip queue — this is the single highest-leverage upgrade for landing rate under load. Helius/Triton paid plans give you this on the normal endpoint automatically.
- Server location matters for staked sends: co-locate near Helius's send infra (US-East / EU-West, e.g. PIT/FRA) if you're chasing lowest latency.
- Don't `sendTransaction` and forget — the RPC does NOT retry indefinitely by default in a way you can rely on; always rebroadcast yourself (see §4).

## 3. Jito bundles: when to use vs. plain send

**Decision: use a bundle only when you need atomicity across txs, MEV protection, or a guaranteed-ordering/no-frontrun property. Plain priority-fee sends are correct for the vast majority of app traffic.**

| Situation | Strategy |
|---|---|
| Normal user tx (transfer, mint, single swap) | Plain `sendTransaction` + priority fee. No bundle. |
| Congested mainnet, tx keeps missing blocks | Raise priority fee to p75-p90 of `getRecentPrioritizationFees`; use staked connection. Still no bundle needed unless ordering matters. |
| MEV-sensitive (large swap, liquidation, sniping, arb) | Jito bundle — hides the tx from public mempool until landed, atomic multi-tx execution, no sandwich risk between your txs. |
| High-value / must-not-fail (large settlement, multisig payout) | Jito bundle **and** a fallback plain-send race, OR durable nonce + staked connection with aggressive rebroadcast. Consider splitting: submit via both a bundle and a parallel regular tx with a cancel-if-either-lands pattern (careful with double-spend — usually just accept idempotent design). |
| Need multiple txs to land together atomically (e.g. create ALT + extend + use in same logical op) | Bundle (up to 5 txs per bundle). |

Bundle mechanics:
- A bundle = up to 5 transactions submitted atomically to Jito's block engine; all land in the same slot or none do.
- **Every bundle needs a tip**: a `SystemProgram.transfer` to one of Jito's **8 static tip accounts** (randomize which one you pick, for parallelism). Get the current list via `SearcherClient.getTipAccounts()` (jito-ts) rather than hardcoding — Jito documents them but treat as "verify via API."
- Tip sizing is **not a fixed constant** — the effective floor moves with network demand. Don't hardcode a lamport value in prod:
  - Absolute technical minimum: 1,000 lamports (usually insufficient).
  - Practical approach: pull recent tip percentile telemetry (Jito exposes a tip-floor stream / stats endpoint) and bid at your urgency's percentile — p50 for routine bundles, p75+ for MEV-competitive ones.
  - For MEV/arb use cases specifically, tip is commonly sized as a fraction (~50-70%) of expected profit on that opportunity, not a flat fee.
- Library: `jito-ts` (npm, Apache-2.0) — `Bundle.addTransactions()`, `Bundle.addTipTx(keypair, lamports, tipAccount, blockhash)`, `SearcherClient.sendBundle()`, `JitoRpcConnection.simulateBundle()`. Also `jito-js-rpc` for a thinner JSON-RPC wrapper.
- Bundles do NOT bypass compute budget rules — still set CU limit/price per tx inside the bundle.

## 4. Retry / rebroadcast strategy

Do not rely on RPC-side `maxRetries`. Implement your own loop:

```ts
const { blockhash, lastValidBlockHeight } = await connection.getLatestBlockhash("confirmed");
tx.recentBlockhash = blockhash;
const rawTx = tx.serialize();

const sendPromise = (async () => {
  while (true) {
    const height = await connection.getBlockHeight("confirmed");
    if (height > lastValidBlockHeight) break; // expired, stop
    await connection.sendRawTransaction(rawTx, { skipPreflight: true, maxRetries: 0 });
    await sleep(2000); // rebroadcast every ~2s
  }
})();

const confirmPromise = connection.confirmTransaction(
  { signature, blockhash, lastValidBlockHeight },
  "confirmed"
);
await Promise.race([sendPromise, confirmPromise]);
```

- Blockhash lifetime ≈ 150 slots ≈ **80 seconds**. Fetch fresh blockhashes on a background timer (e.g. every 30-60s) and sign with the freshest one right before send — don't fetch-then-sit.
- Rebroadcast the **identical signed bytes** every ~2s until `lastValidBlockHeight` is exceeded or you get confirmation — this is what beats transient leader packet loss, not longer waits.
- Race the send loop against `confirmTransaction`; stop rebroadcasting the moment you see a confirmation (double-landing is harmless but wasteful/costly).
- On expiry, don't just retry blind — re-simulate (accounts/state may have changed) and get a fresh blockhash + possibly a higher priority fee before resubmitting.

## 5. Durable nonces (skip blockhash expiry)

Use when the signer can't guarantee broadcast within ~80s: offline/cold signing, multisig approval flows, scheduled/deferred execution, custodial withdrawal queues.

- Create a nonce account once (`SystemProgram.nonceInitialize`), store `nonceAccount.pubkey`.
- Every tx using it MUST have `nonceAdvance` as the **first instruction**, and use the nonce account's current stored value **in place of** `recentBlockhash`.
- No time expiry — but the nonce value changes every time it's advanced (including by other txs), so a durable-nonce tx that lands invalidates all other unlanded txs built against that same nonce value. Don't reuse one nonce account across concurrent in-flight txs.
- (re-verify) Some sources flag possible future deprecation/changes to the nonce mechanism — don't build a critical system assuming permanence without checking `solana.com/docs/core/transactions/durable-nonces` at implementation time.

## 6. Address Lookup Tables (ALTs) — when they pay off

- ALT = on-chain table of up to 256 pubkeys; a v0 tx references entries by 1-byte index instead of inline 32-byte pubkeys → up to 31 bytes saved per account.
- **Use when**: your tx touches many accounts and is near/over the 1,232-byte packet limit — multi-hop DEX routes (Jupiter-style), multi-account CPI stacks, batched instructions referencing >20-25 accounts.
- **Skip when**: simple transfers/single-CPI txs comfortably under the size limit — legacy (non-versioned) txs are simpler, have broader wallet/tooling support, and avoid the extra "create + extend + wait 1 slot for activation" setup cost of a new ALT.
- ALT-resolved accounts can be writable or read-only but **cannot be signers** — plan accordingly.
- ALT creation + extension is itself 1-2 txs plus an activation-slot wait before the table is usable in another tx — don't create-and-use in the same tx/bundle unless you've confirmed activation semantics for your case.

## 7. Confirmation strategy

| Commitment | Latency | Risk | Use for |
|---|---|---|---|
| `processed` | fastest | ~5% of processed blocks are later skipped/forked out | UI optimistic updates only, never as "done" |
| `confirmed` | +\~1 slot after processed | low fork risk, supermajority voted | **default for RPC calls and app-level "success"** |
| `finalized` | +~13s (≈31 confirmed blocks) | effectively irreversible | high-value settlement, on/off-ramp triggers, anything that unlocks real-world funds |

- Use the **same** commitment for `sendTransaction`'s preflight, `getLatestBlockhash`, and `confirmTransaction` — mismatched commitments cause spurious "blockhash not found" / stale-state errors.
- For a payment UI: show `processed` optimistically, mark "confirmed" in UI at `confirmed`, only release externally-facing funds/webhooks at `finalized`.

## 8. Decision tree — which landing strategy

```
Is this tx MEV-sensitive (large swap, liquidation, arb, sniping)
  OR must multiple txs land atomically together?
    YES -> Jito bundle, tip at percentile for urgency, staked send as fallback path
    NO  -> continue

Is it high-value / must-not-fail (settlement, large payout)?
    YES -> staked connection + durable nonce (if signer latency is a risk)
           + aggressive 2s rebroadcast + finalized confirmation before
             treating as done
    NO  -> continue

Is mainnet currently congested (elevated getRecentPrioritizationFees, misses)?
    YES -> staked connection, priority fee at p75-p90, skipPreflight only if
           client-validated, 2s rebroadcast loop
    NO  -> standard RPC sendTransaction, priority fee at p50, skipPreflight
           false, confirmed commitment
```

## Gotchas

- Setting a huge CU limit "just in case" doesn't fail your tx, but it inflates the priority fee you pay for a given price, and it schedules worse under load — right-size via simulation.
- `skipPreflight: true` without client-side simulation/validation silently ships broken txs that burn your priority fee for nothing — only flip it once you trust your own construction pipeline.
- Jito bundle tip is a separate cost from the tx's own priority fee — you generally still want `setComputeUnitPrice` set inside bundle txs too (some situations let you drop it, but don't assume).
- Don't hardcode Jito tip account addresses or tip lamport amounts in code you'll forget about — both are documented as fetch-live/telemetry-driven, not constants (re-verify against `docs.jito.wtf` before hardcoding for a production job).
- `@solana/web3.js` 1.x is in maintenance mode; new code should evaluate `@solana/kit` (formerly web3.js 2.0) or `gill` for tx-building — API for ComputeBudget/ALT/versioned-tx composition differs from the snippets above (re-verify current recommended package before scaffolding a new project).

## See also
- knowledge/latency/rpc-and-realtime.md
- knowledge/solana/anchor-idioms.md
- knowledge/security/solana-audit-checklist.md
