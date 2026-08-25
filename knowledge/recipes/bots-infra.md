---
title: Recipe - Bots & Infra
description: Ship a sniper/copy-trade bot, MEV/Jito execution path, indexer, price API, or Telegram trading bot in ~6 hours by wiring together hosted feeds and execution primitives instead of hand-rolling streaming/decoding/submission
applies_to: [solana]
sources:
  - "../reuse-index/bots-infra.md (sibling reuse index - full candidate list, licenses, audit status)"
  - "Jupiter Swap API - https://github.com/jup-ag/jupiter-swap-api-client , https://dev.jup.ag"
  - "Yellowstone gRPC - https://github.com/rpcpool/yellowstone-grpc (AGPL-3.0 - see pitfalls)"
  - "Helius LaserStream/DAS/Webhooks - https://github.com/helius-labs/laserstream-sdk , https://www.helius.dev/docs"
  - "Jito Labs - https://github.com/jito-labs/jito-ts , https://github.com/jito-labs/searcher-examples , https://github.com/jito-labs/shredstream-proxy"
  - "Carbon (sevenlabs-hq) - https://github.com/sevenlabs-hq/carbon"
  - "Pyth Network SDK - https://github.com/pyth-network/pyth-sdk-rs"
  - "Jupiter Price API + Birdeye - https://dev.jup.ag/docs/price , https://docs.birdeye.so"
  - "grammY - https://github.com/grammyjs/grammY"
  - "sol-trade-sdk (0xfnzero, read-for-reference only) - https://github.com/0xfnzero/sol-trade-sdk"
  - "../testing/per-archetype-tests.md (link - may not exist yet)"
  - "../latency/rpc-and-realtime.md (link - may not exist yet)"
  - "../latency/indexing-caching-db.md (link - may not exist yet)"
  - "../solana/tx-landing.md"
last_verified: 2026-08-25
---

## TL;DR - the 6-hour spine

This archetype is almost entirely plumbing: feed in → decide → execute → serve. Pick the ONE bot shape before hour 1 (sniper/copy-trade, indexer/price-API, or Telegram front-end over an existing engine) — do not try to build a general-purpose trading platform. The spine below assumes **Telegram sniper/copy-trade bot** as the default (most common ask); drop steps 3-4 for a pure indexer/price-API build.

1. **Pick the feed, not the polling loop.** Never poll `getAccountInfo`/`getSignaturesForAddress` in a tight loop for anything latency-sensitive. Default to **Helius LaserStream** (managed, MIT SDK, no self-hosted Geyser) for a solo builder on a 6h clock; reach for raw **Yellowstone gRPC** only if you already have a hosted-gRPC provider (Triton/Chainstack) and need lower-level control — never self-host the AGPL Geyser plugin yourself unless the brief explicitly needs it.
2. **Decode with Carbon, not hand-rolled parsing.** Wire Carbon's datasource (RPC or Geyser/Yellowstone) to its prebuilt decoder crates for the target program (SPL Token, major DEXs) and write only your processor logic. If the target is a brand-new pump.fun-style fork with no prebuilt decoder, budget real time to write one from the IDL — this is the step most likely to blow the 6h budget, so check decoder coverage before committing to a target program.
3. **Route execution through Jupiter Swap API by default.** Do not hand-integrate Raydium/Orca/Meteora routing — call the hosted quote/swap endpoint. Read `sol-trade-sdk` (0xfnzero) as a reference for how feed → decode → build-tx → submit composes end-to-end, but do not import it wholesale — re-audit any code path in it that signs or sends before trusting it with real funds.
4. **Submit via Jito bundles when speed/landing matters** (sniping, copy-trade racing MEV). Use `jito-ts` for bundle construction against the Block Engine; size the tip competitively (see Dangerous Part #1). Skip Jito and use a plain priority-fee transaction for anything not latency-critical (e.g. a rebalance the indexer triggers hourly).
5. **Price reads:** on-chain program needs a trusted price → Pyth SDK (import-as-dep, do not hand-parse the account layout). Off-chain "what's this worth right now" for a UI/alert → Jupiter Price API first (free-tier friendly), Birdeye for richer OHLCV/wallet analytics once a paid key is budgeted.
6. **Build the Telegram front-end last, on top of grammY.** Wallet/key handling is entirely your responsibility — never hold user private keys in bot session state in plaintext (see Dangerous Part #2). Long-polling is fine for a first ship; webhook mode only once you need to scale past one instance.
7. **If it's a pure indexer/price-API (no execution):** stop after step 2, add a thin HTTP layer (or Substreams-Solana if you need consistent historical backfill + real-time from one pipeline), and skip Jupiter/Jito/grammY entirely.
8. **Devnet/demo-first before touching mainnet** (see Deploy section) — one full feed→decode→decide→execute round-trip, watched end-to-end, before any bot runs unattended against real funds.

## Keep / Change / Cut

| Component | Reuse as-is | Modify | Drop |
|---|---|---|---|
| Streaming feed | Helius LaserStream SDK (import) | Yellowstone gRPC client against a hosted provider, if lower-level control is needed | Self-hosting the Yellowstone Geyser plugin yourself; polling RPC in a tight loop |
| Decoding/indexing pipeline | Carbon prebuilt datasource + decoder crates | Custom decoder from IDL, only for programs with no prebuilt decoder | Hand-parsing raw account/tx bytes |
| Swap execution | Jupiter Swap API (hosted quote/swap) | Slippage + priority-fee tuning per your risk tolerance | Hand-integrated per-DEX routing |
| MEV-protected/fast submission | `jito-ts` bundle construction | Tip-account sizing logic, tuned per target latency/competition | Assuming a plain RPC send lands fast enough for a sniper |
| Full trading-engine pattern | — | Study `sol-trade-sdk`'s submission-lane abstraction | Importing `sol-trade-sdk` wholesale and trusting it with real funds unaudited |
| On-chain price reads | Pyth SDK (import) | Freshness/confidence-interval check (SDK returns it, doesn't enforce it) | Hand-rolled Pyth account parsing |
| Off-chain price reads | Jupiter Price API (free tier) | Birdeye for OHLCV/wallet analytics once paid-tier is budgeted | Building your own price aggregator |
| Telegram front-end | grammY | Session store + auth, once scaling past one long-polling instance | Hand-rolled Telegram long-polling/webhook handling |
| Historical + real-time backfill (indexer-only path) | Substreams-Solana module system, if both are needed from one pipeline | — | Self-hosting a Firehose node (use a hosted provider e.g. Pinax) |

## The 3 dangerous parts

1. **Jito tip sizing and bundle-submission logic.** Underpriced tips mean the bundle never lands and the bot silently misses the trade it thought it made; a bot that assumes "sent" means "executed" without checking bundle/transaction status will act on a phantom fill. Guardrail: always confirm the bundle actually landed (poll bundle status / confirm the transaction signature on-chain) before updating any internal "position" state, and make tip amount a tunable competitive against recent landed-bundle tips rather than a hardcoded constant.
2. **Wallet/private-key custody in the bot process (Telegram + execution path).** A Telegram trading bot that lets users deposit or trades on their behalf necessarily holds signing authority somewhere — grammY and every SDK here has zero opinion on custody, so the default failure mode is a hot key sitting in plaintext session state or an env var reachable from the same process handling untrusted Telegram input. Guardrail: keep signing keys out of chat/session state entirely (KMS/OS keychain, or a signer service the bot process calls rather than holds), cap per-user/per-bot exposure (hot-wallet balance ceilings), and treat any user-supplied input (token address, amount, callback data) as untrusted before it reaches a signing path.
3. **Trusting unaudited copy-paste execution code with real funds.** This category is thick with marketing-driven "sniper bot" repos and forks of unclear provenance (the reuse index flags this explicitly) — a bot that blindly forks one and points it at a funded wallet inherits whatever bugs or backdoors are in it, with no defensive checks (slippage bounds, balance/authority validation) unless you add them yourself. Guardrail: treat every single-purpose trading-bot repo as read-for-reference only, diff any fork against its upstream before trusting it, and add your own slippage/balance/authority checks in the execution path rather than assuming the reference code has them.

## Minimum tests - the 5 non-negotiables

See `../testing/per-archetype-tests.md` (link — file may not exist yet) for the full checklist. For this archetype, at minimum:
1. Feed reconnect/back-pressure test: kill the LaserStream/gRPC connection mid-run and confirm the bot reconnects and resumes without silently dropping updates or double-processing a replayed event.
2. Decode-then-decide accuracy test: feed a known historical transaction through the Carbon pipeline and assert the decoded output (amounts, mints, accounts) matches ground truth before wiring it to a live decision.
3. Execution dry-run: a full quote → build → simulate (not send) path against Jupiter/Jito on devnet or a mainnet simulation, confirming slippage/priority-fee parameters are actually applied, not defaulted silently.
4. Bundle/transaction landing confirmation test: submit a real (small, devnet or test-value) transaction and confirm the bot correctly distinguishes "landed" from "sent but dropped" — do not let this be assumed.
5. Untrusted-input handling test (Telegram/API front-end): a malformed or adversarial user input (bad token address, negative amount, huge amount) is rejected before it reaches a signing or submission path.

## Deploy

- **Devnet/demo-first, always.** Run the full feed → decode → decide → execute loop against devnet (or a mainnet dry-run with simulate-only transactions) with a human watching, before letting any bot run unattended or touch a funded mainnet wallet.
- **Key handling:** signing keys, Helius/Jito/Birdeye API keys, and any Telegram bot token live in env vars or an OS keychain / secrets manager — never in chat/session state, never committed, never in a client-reachable path. For a hot wallet the bot signs from directly, set an explicit balance ceiling and treat anything above it as requiring manual top-up, not auto-refill.
- **Program verify:** this archetype rarely deploys a custom on-chain program (it composes existing deployed programs/APIs) — if you do ship one (a custom on-chain component), run `anchor verify` / `solana-verify` against published source before mainnet.
- **Upgrade authority:** n/a for most builds here (no custom program); if a custom program is part of the stack, decide upgrade-authority ownership before mainnet per the general Solana guidance in `../solana/tx-landing.md` and the wallets-payments recipe's Deploy section.
- **Mainnet is LATER and gated, never automatic.** Explicit human go/no-go checkpoint after the devnet/dry-run demo passes and the 5 minimum tests are green: confirm hot-wallet balance ceilings are set, confirm every imported execution path (especially anything derived from `sol-trade-sdk` or similar reference repos) has had defensive checks added and reviewed, confirm license posture (Yellowstone's AGPL-3.0 in particular — see pitfalls) is acceptable for how you're distributing the bot, then flip from simulate/dry-run to live signing.

## Latency notes

- See `../latency/rpc-and-realtime.md`, `../latency/indexing-caching-db.md` (links — may not exist yet), and `../solana/tx-landing.md` for general RPC/landing guidance.
- Streaming feed choice is the dominant latency lever: LaserStream/Yellowstone gRPC beats RPC polling by an order of magnitude for "react to new block/account state" — do not build a sniper on `getAccountInfo` polling.
- DAS API (Helius) freshness lags raw account state by seconds in some conditions — fine for a dashboard, not for a latency-critical sniping decision; use the raw streaming feed for the decision path and DAS only for enrichment (metadata) that isn't time-critical.
- Jito ShredStream gives the lowest-latency view of new blocks but requires real infra investment (a proxy near a Jito-connected validator, or a paid provider) — budget for this explicitly rather than assuming a plain RPC URL swap gets you the same gains.
- Carbon pipeline backpressure/ordering guarantees need to be understood before relying on them for anything order-sensitive (e.g. copy-trade sequencing) — an out-of-order or dropped update silently corrupts a decision that depends on strict sequencing.
- Price reads: cache aggressively. Jupiter/Birdeye free tiers rate-limit under bot-scale polling — cache last-known price with a short TTL rather than re-fetching on every decision tick.

## Common pitfalls

- Self-hosting the Yellowstone Geyser plugin (AGPL-3.0) as a network-accessible service inside a closed product without legal review — the AGPL network-use clause can require offering source to your users; the hosted-provider path (Helius/Triton/QuickNode) sidesteps this since you're a client, not a redistributor.
- Assuming a decoder exists for a brand-new program (pump.fun forks, new DEXs) — Carbon's ~40 prebuilt decoders lag new launches; check coverage before committing to a target program, not after.
- Treating "transaction sent" as "transaction landed" — especially with Jito bundles, where an underpriced tip means silent non-inclusion, not an error.
- Importing `sol-trade-sdk` or any similar reference trading engine wholesale and pointing it at a funded wallet without re-auditing the signing/submission path — it is explicitly unaudited reference code, and this category is full of unclear-provenance forks.
- Letting a Telegram bot hold user private keys in plaintext session state — grammY has no custody opinion, so this is entirely on the builder to get right.
- Relying on Pyth price data without checking staleness/confidence-interval yourself — the SDK returns these fields but does not enforce freshness for you, and using the wrong oracle version (legacy push vs. pull) silently reads the wrong account layout.
- Under-budgeting for paid tiers — Helius/Jito/Jupiter/Birdeye free tiers are fine for prototyping and will rate-limit or throttle at real bot-scale volume; get a paid key before the mainnet go/no-go, not after launch breaks.
