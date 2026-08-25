---
title: Indexing, Caching & Serverless DB Latency
description: Solana indexing options, cache TTL/invalidation rules, and Neon serverless Postgres latency gotchas for a Next.js + Node stack
applies_to: [solana]
sources:
  - "Helius DAS/Enhanced/Webhooks docs - https://www.helius.dev/docs (verified 2026-08-25)"
  - "Solana getProgramAccounts guide - https://www.quicknode.com/docs/solana/getProgramAccounts (verified 2026-08-25)"
  - "Yellowstone gRPC guide (Triton) - https://blog.triton.one/complete-guide-to-solana-streaming-and-yellowstone-grpc/ (verified 2026-08-25)"
  - "Neon connection pooling - https://neon.com/docs/connect/connection-pooling (verified 2026-08-25)"
  - "Neon serverless driver - https://neon.com/docs/serverless/serverless-driver (verified 2026-08-25)"
  - "Neon connection latency/cold start - https://neon.com/docs/connect/connection-latency (verified 2026-08-25)"
  - "Neon HTTP vs WebSockets at the edge - https://neon.com/blog/http-vs-websockets-for-postgres-queries-at-the-edge (verified 2026-08-25)"
last_verified: 2026-08-25
---

# Indexing, Caching & Serverless DB Latency

REUSE-FIRST: for a 6-12h build, do not write a custom indexer or Geyser consumer. Use Helius DAS/Enhanced/Webhooks first; fall back to raw RPC with strict filters only for data DAS doesn't cover; reach for Yellowstone gRPC/Substreams only past MVP when you need sub-second custom pipelines.

## 1. Indexing decision table

| Need | Use | Why | Cost/complexity |
|---|---|---|---|
| NFT/token ownership, metadata, compressed NFTs | Helius **DAS API** (`getAsset`, `getAssetsByOwner`, `searchAssets`) | Maintained, handles cNFT merkle proofs you'd otherwise hand-roll | $ (credits), near-zero build time |
| Human-readable tx history / parsing | Helius **Enhanced Transactions API** | Parses swaps, NFT sales, DeFi actions | $ |
| "Notify my backend on event X" | Helius **Webhooks** (or QuickNode equivalent) | Push instead of poll; avoids cron+getSignaturesForAddress loops | $, near-zero build time |
| Real-time sub-100ms account/tx stream, custom filters | **Yellowstone gRPC** (Geyser) — providers: Helius LaserStream, Triton, Chainstack | Streams from validator memory; ~50-100ms vs 200-400ms WS pitfall; you write the consumer | $$, days of build time — skip for 6-12h unless the product IS the indexer |
| Cross-chain/complex historical reprocessing pipelines | **Substreams** | Data-engineering-style reproducible pipelines, consumes Geyser-like streams | $$$, not a 6-12h fit |
| One-off account scan (e.g. "all accounts owned by program X") | Raw `getProgramAccounts` with filters | Only when DAS doesn't cover the account type | Free-ish but see pitfalls below |

Default for this stack: **Helius DAS + Webhooks** for anything token/NFT-shaped; raw filtered RPC calls behind your own Node API route for custom on-chain state; skip Geyser/Substreams entirely unless the task explicitly requires real-time custom streaming.

## 2. `getProgramAccounts` pitfalls (grep target: `getProgramAccounts`)

- **Disabled/throttled on free & shared tiers.** `getProgramAccounts`, `getTokenAccountsByOwner`, `getTokenAccountsByDelegate`, `getTokenLargestAccounts` are the first methods providers restrict because they scan large slices of account state. Verify your RPC plan supports it before building around it.
- **Never call unfiltered.** Always pass `filters` (memcmp/dataSize) to narrow the scan server-side — unfiltered calls get rate-limited harder or rejected outright.
- **Use `dataSlice`** to fetch only the bytes you need (e.g. just a discriminator + one field) instead of full account data, cutting payload size drastically.
- **No native pagination.** `getProgramAccounts` returns everything matching filters in one response; there's no cursor. If the result set can grow unbounded, you MUST design filters (or a separate index) that bound result size — don't rely on the RPC to paginate for you.
- **Timeouts/response caps.** Large unfiltered scans can hit provider response-size limits or timeout entirely; this is the most common "works in dev, breaks on mainnet" bug.
- Do/don't:
  - DO: `connection.getProgramAccounts(programId, { filters: [{ dataSize: N }, { memcmp: { offset, bytes }}], dataSlice: { offset, length } })`
  - DON'T: call `getProgramAccounts(programId)` with no filters against a program with thousands of accounts — this is the #1 way to get IP-banned or rate-limited by an RPC provider.

## 3. What to cache, TTLs, invalidation

| Data | Cache? | TTL default | Invalidate on |
|---|---|---|---|
| Token/NFT metadata (name, image, off-chain JSON) | Yes | 1h-24h (rarely changes) | manual purge on known mint update, or just let TTL expire |
| Account balances / token balances | Yes, short | 400ms-2s (≈ 1 slot) | new confirmed slot for that account, or on webhook/tx affecting it |
| On-chain program state read via `getProgramAccounts`/`getAccountInfo` | Yes, short | 1 slot (~400ms) to a few seconds depending on tolerance | poll delta or subscribe via `accountSubscribe`/webhook, then bust key |
| Price/oracle data | Yes, very short | 1-5s | on new price update event |
| Historical tx / parsed activity feeds | Yes, long | hours+ | append-only; rarely needs invalidation, just append new pages |
| "Finalized" vs "confirmed" reads | Cache confirmed longer only if UI tolerates reorg risk; treat finalized as safe to cache longer | confirmed: seconds; finalized: minutes+ | re-verify at finalized commitment before any irreversible UI action (e.g. showing a payout as settled) |

Rules of thumb for a 6h build:
- Cache **derived/display data** (metadata, USD prices, formatted history) aggressively; never cache **balances used for a write decision** (e.g. "can this wallet afford X") beyond ~1 slot — always re-read fresh or use `confirmed`/`finalized` commitment directly before a mutating action.
- Key cache entries by `(address, commitment)` so a `confirmed` read never silently serves a stale `finalized` value or vice versa.
- Simplest invalidation for a solo build: short TTL (1-5s) via Vercel/Next.js `revalidate` or an in-memory/Edge KV cache, rather than building slot-subscription invalidation — only build push-invalidation (webhook → cache bust) if the product needs sub-second freshness (e.g. live order book).
- For webhook-driven invalidation: Helius Webhooks POST to your Next.js API route on tx/account events — bust the specific cache key in the handler rather than polling.

## 4. Neon serverless Postgres — gotchas & defaults for Next.js + Node

### Cold starts & autosuspend
- Neon computes **scale to zero after 5 min idle by default**; waking from idle is typically ~500ms (vs ~15s for some competing serverless Postgres). Still, a cold API route can feel it.
- For a 6h build: **leave autosuspend on** (cost > latency concern at this stage) unless the app has a real-time trading/latency-sensitive path — then raise the suspend timeout or pin a small always-on compute for that one hot path.

### Driver choice (grep target: `@neondatabase/serverless`)
- **HTTP driver (`neon()` from `@neondatabase/serverless`)**: fewer round trips (~3 vs ~8 for TCP), best for single-shot/non-interactive queries from serverless functions and Edge runtime (Vercel Edge, Cloudflare Workers). **Default choice for most Next.js API routes / Server Actions.**
- **WebSocket driver (`Pool`/`Client` from `@neondatabase/serverless`)**: node-postgres-compatible, supports multi-statement interactive transactions and session state. Use when you need a real transaction (`BEGIN...COMMIT` across multiple queries) or a drop-in `pg` replacement.
- **Plain `pg` over TCP**: fine for long-lived Node servers (not serverless functions) where you already manage a connection pool yourself.
- Do/don't:
  - DO use the HTTP driver for simple reads/writes in API routes/Server Actions.
  - DO use the WebSocket `Pool`/transactions when a request needs multiple statements to commit atomically.
  - DON'T open a new TCP `pg` connection per serverless invocation without pooling — this exhausts Postgres `max_connections` fast under concurrent traffic.

### Connection pooling
- Every Neon database ships a **managed PgBouncer** — you don't run or configure it, just use the **pooled connection string** (hostname contains `-pooler`), e.g. `...@ep-xxxx-pooler.<region>.aws.neon.tech/...`.
- Pooler runs in **transaction mode**: `SET`, `LISTEN/NOTIFY`, multi-query `PREPARE` across separate connections, and session-level features are NOT reliable on the pooled endpoint.
- Pattern for a 6h build:
  - Runtime queries (API routes, Server Actions) → **pooled** connection string.
  - Migrations (Drizzle Kit / Prisma Migrate) and anything needing `CREATE INDEX CONCURRENTLY`/session state → **direct/unpooled** connection string.
- PgBouncer accepts up to 10k client connections and multiplexes onto Postgres `max_connections` (sized ~90% of plan limit) — this is what actually saves you from a serverless fan-out connection storm.

### Region colocation
- Deploy Vercel/Next.js functions and provision the Neon project in the **same region** (e.g. both `us-east-1`/`aws-us-east-2`) — cross-region round trips dominate latency far more than driver choice. Check this first when p95 latency looks bad.

### 6h-build defaults (copy this)
1. Neon project region = same region as your Vercel deployment.
2. Use `-pooler` connection string for the app; keep the direct string only in migration scripts/CI.
3. Use `@neondatabase/serverless` HTTP driver (`neon()`) for simple queries via Drizzle/raw SQL in API routes.
4. Switch to the WebSocket `Pool` only for endpoints doing multi-statement transactions.
5. Leave autosuspend at default (5 min) — don't tune it unless you measure a real cold-start problem in testing.
6. Add a thin cache (Next.js `revalidate`/in-memory) in front of read-heavy endpoints instead of hammering Neon per-request; this also reduces cold-start frequency by keeping compute warm.

## See also
- knowledge/security/solana-audit-checklist.md
