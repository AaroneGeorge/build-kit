---
title: Reuse Index - Bots & Infra (Sniper/Copy-Trade, Jito/MEV, Indexers, Price APIs, Telegram Bots)
description: Vetted Solana bot-and-infra building blocks - streaming/Geyser feeds, Jito bundles, indexer frameworks, price APIs, and Telegram bot scaffolding - with license and audit status for fast reuse.
applies_to: [solana]
sources:
  - "Jupiter Swap API - https://github.com/jup-ag/jupiter-swap-api-client , https://dev.jup.ag (verified 2026-08-29)"
  - "Yellowstone gRPC - https://github.com/rpcpool/yellowstone-grpc (verified 2026-08-29)"
  - "Helius LaserStream/DAS/Webhooks - https://github.com/helius-labs/laserstream-sdk , https://www.helius.dev/docs (verified 2026-08-29)"
  - "Jito Labs Block Engine + ShredStream - https://github.com/jito-labs/jito-ts , https://github.com/jito-labs/searcher-examples , https://github.com/jito-labs/shredstream-proxy (verified 2026-08-29)"
  - "Carbon (sevenlabs-hq) - https://github.com/sevenlabs-hq/carbon (verified 2026-08-29)"
  - "Substreams for Solana (StreamingFast) - https://github.com/streamingfast/substreams-solana (verified 2026-08-29)"
  - "Pyth Network SDK - https://github.com/pyth-network/pyth-sdk-rs (verified 2026-08-29)"
  - "Jupiter Price API + Birdeye Data API - https://dev.jup.ag/docs/price , https://docs.birdeye.so (verified 2026-08-29)"
  - "grammY - https://github.com/grammyjs/grammY (verified 2026-08-29)"
  - "sol-trade-sdk (0xfnzero) - https://github.com/0xfnzero/sol-trade-sdk (verified 2026-08-29)"
last_verified: 2026-08-29
---

Bots and infra on Solana are almost entirely a plumbing problem: get a fast, reliable feed of on-chain state (Geyser/gRPC, shreds, webhooks), route orders through a proven execution path (Jupiter, Jito bundles), and index/serve the result (Carbon, Substreams, price APIs) behind a bot front-end (Telegram). Very little of this needs custom on-chain programs. Reuse posture: anything public is fair game - record license + audit status below so the builder decides, do not block on it. Note: this space is thick with unaudited, marketing-driven "paid sniper bot" repos published to sell access to a private/paid version - treat any single-purpose trading-bot repo as read-for-reference and unaudited unless proven otherwise, and prefer composing the primitives below over trusting a full bot end-to-end.

### Jupiter Swap API - hosted swap aggregator, the default execution path for any bot that needs to buy/sell
- Repo/Docs: https://github.com/jup-ag/jupiter-swap-api-client , https://dev.jup.ag/docs/price , https://portal.jup.ag
- What you get: hosted REST quote/swap API (api.jup.ag, free-tier lite-api.jup.ag) plus a Rust client crate and TS SDKs; handles routing across every major Solana DEX so a bot never has to integrate venues one-by-one.
- Chain/stack: solana, ts-sdk, rust
- Audit status: routed venues carry their own audits; Jupiter Swap v6 audited by Offside Labs (Apr 2024 and Oct 2025), v3 by Sec3 - reports now centrally listed at https://developers.jup.ag/docs/resources/audits (verified 2026-08-29)
- License: FLAG - jupiter-swap-api-client repo still has no LICENSE file (GitHub reports none, verified 2026-08-29), so it defaults to all-rights-reserved; get clarity before redistributing the client itself. The API is a hosted service gated by ToS + API key, not code you fork
- Maintenance: active jup-ag org - 200 stars / 36 commits on the Rust client, last commit to main 2025-12-29 with branch activity through 2026-08; hosted API/docs iterating continuously (verified 2026-08-29)
- Fork vs import: import-as-dep - this is the correct default for "execute a swap" instead of hand-rolling routing against Raydium/Orca/Meteora
- Known pitfalls: free tiers are tight for bots - keyless access is 0.5 req/s (30/min) and a free API key gets 1 req/s (60/min), with paid Developer/Launch/Pro plans at 10/50/150 req/s per org (verified 2026-08-29); budget a paid portal.jup.ag key for production volume; quote staleness under volatility requires slippage + priority-fee tuning on the bot side.

### Yellowstone gRPC (Dragon's Mouth Geyser) - the standard low-latency account/tx streaming layer
- Repo/Docs: https://github.com/rpcpool/yellowstone-grpc , https://docs.triton.one/project-yellowstone/dragons-mouth-grpc-subscriptions
- What you get: a Geyser plugin (self-hosted validator side) plus Rust/TS/Go/Python client libraries for subscribing to account, transaction, slot, and block updates over gRPC - this is what most sniper/copy-trade/indexer bots subscribe to instead of polling RPC.
- Chain/stack: solana, rust, ts-sdk
- Audit status: unaudited - infrastructure plugin, not a program handling funds; correctness risk is data-loss/reconnect handling, not fund-loss
- License: AGPL-3.0 (verified 2026-08-29) - FLAG: strong copyleft on the plugin/repo; if you self-host the plugin as a network-accessible service, AGPL's network-use clause can require you to offer source to your users - legal review needed before bundling into a closed product. The hosted-provider path (Helius/Triton/QuickNode reselling gRPC access) sidesteps this since you're a client, not a redistributor.
- Maintenance: active rpcpool/Triton org - 993 stars, 448 commits, last commit 2026-08-28, regular CHANGELOG entries (verified 2026-08-29)
- Fork vs import: import-as-dep (use the client crate/package against a hosted gRPC endpoint) for almost everyone; fork-and-adapt the plugin only if self-hosting validator infra
- Known pitfalls: reconnect/back-pressure handling is easy to get wrong and silently drops updates under load - use the client's built-in reconnect logic rather than hand-rolling; self-hosting requires running a full validator or paying a provider (Helius, Triton, Chainstack) for gRPC access - budget for this before designing around it.

### Helius LaserStream / DAS API / Webhooks - managed streaming + indexing, lower ops burden than self-hosted Geyser
- Repo/Docs: https://github.com/helius-labs/laserstream-sdk , https://www.helius.dev/docs
- What you get: LaserStream (managed gRPC streaming with replay/backfill, wraps Yellowstone-style feeds without self-hosting a plugin), DAS API (indexed NFT/token/compressed-NFT metadata without scanning raw accounts), and Webhooks (push alerts on account/program/tx events) - plus Node.js and Rust SDKs.
- Chain/stack: solana, ts-sdk, rust
- Audit status: unaudited - managed infra product, not a fund-custody program
- License: laserstream-sdk repo is MIT (permissive, verified 2026-08-29); the DAS/Webhooks API itself is a paid hosted service gated by API key, not forkable code
- Maintenance: active helius-labs org - 58 stars / 332 commits on laserstream-sdk, last commit 2026-08-26 (verified 2026-08-29)
- Fork vs import: import-as-dep - this is the fastest path to production streaming for a solo builder who doesn't want to operate Geyser infra themselves
- Known pitfalls: paid tiers gate throughput/replay depth - free tier is fine for prototyping, not for production bot volume; DAS API freshness lags raw account state by seconds in some conditions, don't use it for latency-critical sniping decisions.

### Jito Labs - Block Engine bundles + ShredStream - the standard MEV-protection and low-latency execution path
- Repo/Docs: https://github.com/jito-labs/jito-ts (TS SDK), https://github.com/jito-labs/searcher-examples (Rust reference client), https://github.com/jito-labs/shredstream-proxy (raw shred feed), https://docs.jito.wtf
- What you get: bundle construction/submission (atomic multi-tx groups via the Block Engine, avoids sandwiching and gets priority inclusion), tip-account/leader-schedule helpers, and ShredStream - a proxy that forwards shreds from Jito-connected leaders for the lowest-latency view of new blocks (used heavily by sniper/copy-trade bots to react before a block is fully confirmed).
- Chain/stack: solana, ts-sdk, rust
- Audit status: unaudited - infra client/proxy, not a program holding user funds
- License: Apache-2.0 across all three repos (jito-ts, searcher-examples, shredstream-proxy) - permissive, no copyleft concerns (verified 2026-08-29)
- Maintenance: jito-labs org - shredstream-proxy actively maintained (245 stars/80 commits, last commit 2026-07-13); jito-ts slower (198 stars/52 commits, last commit 2025-09-10) and searcher-examples static (431 stars/35 commits, last commit 2025-04-25) - treat the SDK/examples as stable-not-fast-moving (verified 2026-08-29)
- Fork vs import: import-as-dep for jito-ts/shredstream-proxy in production; read-for-reference on searcher-examples (official Rust CLI/lib pattern) before writing custom bundle logic
- Known pitfalls: bundles require a tip payment to a Jito tip account sized competitively or they don't land; ShredStream requires either running the proxy near a Jito-connected validator or paying a provider for access - raw latency gains are meaningful but require real infra investment, not just swapping an RPC URL.

### Carbon (sevenlabs-hq) - Rust framework for building custom Solana indexers/data pipelines
- Repo/Docs: https://github.com/sevenlabs-hq/carbon
- What you get: a pipeline abstraction (datasource -> decoder -> processor) with ~7 prebuilt datasource crates (RPC, Geyser/Yellowstone, etc.) and ~40 prebuilt decoder crates for common programs (SPL Token, major DEXs) - lets a bot build a program-specific indexer in well under 150 lines instead of hand-parsing account/tx data.
- Chain/stack: solana, rust
- Audit status: unaudited - dev tooling, not a fund-custody program
- License: MIT (verified 2026-08-29)
- Maintenance: active sevenlabs-hq org - 614 stars, 1,425 commits, last commit 2026-07-21; v1.0.0 released mid-2025 and presented at Solana Accelerate/Breakpoint 2025 (verified 2026-08-29)
- Fork vs import: import-as-dep - use the prebuilt decoders/datasources and write only the processor logic specific to your bot
- Known pitfalls: prebuilt decoders lag newly-launched programs (pump.fun forks, brand-new DEXs) - budget time to write a custom decoder from the program's IDL when targeting a very new protocol; pipeline backpressure/ordering guarantees need to be understood before relying on it for anything order-sensitive (e.g. copy-trade sequencing).

### Substreams for Solana (StreamingFast) - alternative streaming/ETL engine, strong for historical + real-time backfill
- Repo/Docs: https://github.com/streamingfast/substreams-solana , https://github.com/streamingfast/substreams
- What you get: Firehose-based block streaming with a Rust module system for transforms, sinkable to Postgres/files/etc.; strongest when you need both real-time streaming and consistent historical backfill from one pipeline (e.g. building a price-history API or leaderboard, not just a live bot).
- Chain/stack: solana, rust
- Audit status: unaudited - dev tooling
- License: Apache-2.0 (verified 2026-08-29)
- Maintenance: StreamingFast org, still maintained (last commit 2026-07-16) but the Solana-specific repo stays comparatively small (19 stars, 65 commits) next to the core substreams project - FLAG: maintained-but-niche, weigh ecosystem depth before betting critical infra on it (verified 2026-08-29)
- Fork vs import: import-as-dep for the module system; read-for-reference for understanding Firehose block models if you're also touching EVM chains (Substreams is multi-chain, worth knowing if the bot expands beyond Solana)
- Known pitfalls: steeper learning curve than Yellowstone/Carbon (protobuf module authoring, Firehose infra concepts); running your own Firehose node is heavy - most builders will want a hosted Substreams provider (e.g. Pinax) rather than self-hosting.

### Pyth Network SDK - canonical on-chain price oracle, the reference for on-chain price reads
- Repo/Docs: https://github.com/pyth-network/pyth-sdk-rs , https://github.com/pyth-network/pyth-crosschain , https://docs.pyth.network
- What you get: Rust SDK for reading Pyth price feed accounts on-chain (for programs that need a trusted price on-chain, e.g. a liquidation bot or a program-side price check), plus pyth-crosschain for pull-oracle style off-chain-fetch-then-post-on-chain patterns used in newer integrations.
- Chain/stack: solana+anchor, rust
- Audit status: audited repeatedly - Pyth publishes reports at https://github.com/pyth-network/audit-reports (23 dated reports spanning 2022-2026, latest 2026-08-10); still confirm the report covering your exact integration path (legacy push vs pull oracle) before high-value liquidation logic (verified 2026-08-29)
- License: Apache-2.0 (verified 2026-08-29)
- Maintenance: active pyth-network org - pyth-sdk-rs at 113 stars/226 commits but last commit 2025-08-14 (maintenance mode); pyth-crosschain is the actively-developed successor (247 stars, commits through 2026-08-29) (verified 2026-08-29)
- Fork vs import: import-as-dep - do not hand-roll price account parsing, Pyth's account layout has changed across versions (v1 legacy vs pull-oracle) and getting it wrong silently reads stale/wrong prices
- Known pitfalls: legacy pyth-client-js reads the old on-chain layout - confirm which oracle version (legacy push vs newer pull) your target program actually consumes before wiring up a client; price staleness/confidence-interval checks are the caller's responsibility, the SDK returns them but doesn't enforce freshness for you.

### Jupiter Price API + Birdeye Data API - off-chain aggregated price/analytics for bots and UIs
- Repo/Docs: https://dev.jup.ag/docs/price (Jupiter Price API v3, base https://lite-api.jup.ag/price/v3), https://docs.birdeye.so , community wrapper https://github.com/nickatnight/birdeye-py
- What you get: simple REST price lookups (Jupiter, free-tier friendly, good for "what's this token worth right now") and richer analytics (Birdeye: OHLCV, trades, wallet analytics, websocket push) for dashboards/alerts - neither requires running any infra.
- Chain/stack: solana, ts-sdk (REST, language-agnostic)
- Audit status: n/a - hosted read-only data APIs, no funds custody
- License: n/a - both are ToS-gated hosted services, not forkable code; the community birdeye-py wrapper is a separate MIT-licensed convenience client, not official (MIT confirmed, though inactive since 2024-12 - verified 2026-08-29)
- Maintenance: both actively sold/iterated. Jupiter tiers: keyless 30 req/min, free API key 60 req/min, paid Developer/Launch/Pro at 10/50/150 req/s per org. Birdeye tiers: Standard 1 req/s, Lite/Starter 15 req/s, Premium 50 req/s, Business 100 req/s, Enterprise custom; wallet-API endpoints separately capped at 30 req/min (verified 2026-08-29)
- Fork vs import: import-as-dep (plain HTTP calls) for both - there is nothing to fork, just wire up API keys
- Known pitfalls: Jupiter's free lite-api tier is fine for prototyping but rate-limits under bot polling frequency; Birdeye is paid-tier-gated for anything beyond light use and has no official first-party SDK (community wrappers may lag the API) - budget for a paid key before relying on either for production alerting.

### grammY - TypeScript-first Telegram bot framework, the default front-end for a trading/alert bot
- Repo/Docs: https://github.com/grammyjs/grammY , https://grammy.dev
- What you get: a modern, plugin-extensible Telegram Bot API framework for Node.js/Deno - the standard scaffold for the "Telegram bot UI on top of a Solana trading engine" pattern seen across almost every sniper/copy-trade product.
- Chain/stack: ts-sdk, node.js
- Audit status: n/a - not a funds-custody component, standard bot-framework trust model applies
- License: MIT (verified 2026-08-29)
- Maintenance: very active - 3,728 stars, 945 commits, last commit 2026-08-26, strong docs and plugin ecosystem - one of the best-maintained repos in this list (verified 2026-08-29)
- Fork vs import: import-as-dep - do not hand-roll Telegram long-polling/webhook handling
- Known pitfalls: wallet/private-key handling for a Telegram trading bot is entirely on you (grammY has no opinion on custody) - never let bot session state hold raw private keys in plaintext; webhook mode requires a public HTTPS endpoint, long-polling is simpler for a first ship but doesn't scale past one instance without a session store.

### sol-trade-sdk (0xfnzero) - read-for-reference Rust execution engine for low-latency DEX trading bots
- Repo/Docs: https://github.com/0xfnzero/sol-trade-sdk
- What you get: a Rust SDK covering low-latency transaction construction and submission across PumpFun, PumpSwap, Bonk, Raydium, Meteora, with pluggable submission lanes (default RPC, Jito, and several third-party SWQoS providers) - useful as a worked example of how the pieces above (Yellowstone/Geyser feed -> decode -> build tx -> submit via Jito) compose into an actual sniper/copy-trade engine.
- Chain/stack: solana, rust
- Audit status: unaudited - no security audit disclosed; author disclaimer says "test thoroughly before mainnet" and nothing more. Treat as reference code, not production-ready as-is.
- License: MIT (verified 2026-08-29)
- Maintenance: 336 stars, 642 commits, last commit 2026-08-13 - reasonably active for this niche, though single-maintainer risk applies (verified 2026-08-29)
- Fork vs import: read-for-reference - study the submission-lane abstraction and multi-DEX transaction-building patterns, but re-audit any code path that signs/sends transactions before trusting it with real funds; this category is full of copy-paste forks of unclear provenance, so diff against the upstream repo rather than trusting a random fork.
- Known pitfalls: third-party SWQoS/priority-submission providers it integrates (Nextblock, ZeroSlot, Temporal, Bloxroute, FlashBlock) are paid services with their own trust assumptions - understand what each one actually guarantees before wiring in an API key; like most bots in this space it optimizes for speed over defensive checks (slippage bounds, balance/authority validation) - add those yourself rather than assuming they're handled.
