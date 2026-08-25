---
title: Solana RPC Providers & Realtime Data
description: Choosing an RPC provider and realtime mechanism (websocket/gRPC/webhook/polling) for Solana apps, with cost/latency tradeoffs
applies_to: [solana]
sources:
  - "Helius Pricing - https://www.helius.dev/pricing (verified 2026-08-25)"
  - "Helius Webhooks docs - https://www.helius.dev/docs/webhooks (verified 2026-08-25)"
  - "Helius LaserStream WebSocket - https://www.helius.dev/docs/rpc/websocket (verified 2026-08-25)"
  - "Triton One / Yellowstone gRPC (Dragon's Mouth) - https://docs.triton.one/project-yellowstone/introduction (verified 2026-08-25)"
  - "rpcpool/yellowstone-grpc - https://github.com/rpcpool/yellowstone-grpc (verified 2026-08-25)"
  - "QuickNode Flat Rate RPS - https://www.quicknode.com/docs/platform/billing/flat-rate-rps (verified 2026-08-25)"
  - "Alchemy Solana Subscription API - https://www.alchemy.com/docs/reference/subscription-api (verified 2026-08-25)"
  - "Solana Production Readiness - https://solana.com/docs/payments/production-readiness (verified 2026-08-25)"
  - "Solana Clusters & Public RPC - https://solana.com/docs/references/clusters (verified 2026-08-25)"
last_verified: 2026-08-25
---

# Solana RPC Providers & Realtime Data

## TL;DR decision

- **Never ship to prod on `api.mainnet-beta.solana.com`.** Public endpoints have no SLA, aggressive/undocumented rate limits, and can 403 your app without notice. Dev/testing only. (re-verify limits periodically — they change without notice)
- Default pick for a solo builder shipping in 6-12h: **Helius** (best docs, DAS API, webhooks, staked sends bundled, generous free tier). Reach for **Triton/Yellowstone gRPC** directly (or via QuickNode/Alchemy's Yellowstone-compatible gRPC) only when you've *measured* that websockets aren't fast/reliable enough.
- Don't build a custom Geyser plugin or run your own validator+Geyser stack unless you're at a scale where $/ms actually matters — that's a rewrite-from-scratch move that violates reuse-first for a 6-12h build.

## Provider comparison

| Provider | Free tier | Paid entry | Staked/priority sends | Realtime | Regions | Notes |
|---|---|---|---|---|---|---|
| **Helius** | Yes (generous) | ~$49-99/mo dev tiers, $499/mo Business | Yes, bundled on paid plans via `mainnet.helius-rpc.com` (Sender for tx landing) | WebSocket (LaserStream-backed), LaserStream gRPC (Yellowstone-compatible), Webhooks, DAS API | Global edge | Best all-in-one for NFT/DeFi indexing + webhooks. LaserStream gRPC needs Business ($499/mo) tier for meaningful concurrency (10 conns) |
| **Triton One (Yellowstone)** | Trial | Custom/enterprise pricing | Yes (dedicated stake pool option) | Dragon's Mouth gRPC (Geyser), Whirligig WS, Fumarole (replay-safe streaming) | Multi-region | The reference implementation of Geyser-over-gRPC; other providers' gRPC is "Yellowstone-compatible" i.e. built on this protocol/schema |
| **QuickNode** | Yes | Flat-rate RPS plans (Solana = 1.5x credit multiplier vs EVM) | SWQoS via QuickNode stake pool, Jito bundles via "Lil' JIT" add-on | WS, Yellowstone-compatible gRPC, managed Streams | 12 regional deployments, active-active | Best if you're already multi-chain on QuickNode; 400 RPS cap on standard tiers is the usual latency-sensitive bottleneck |
| **Alchemy** | Yes (30M CU/mo) | $0.45/1M CU tiered down to $0.40/1M CU | Via their infra, less Solana-native than Helius | WS Subscription API (billed by bandwidth), Yellowstone gRPC ($75/TB, no min) | Global | Newer to Solana than the others; strong if you're already EVM+Solana on one billing account |
| **Public mainnet-beta** | Free, unauthenticated | N/A | No | WS supported but rate-limited hard | Solana Foundation infra | Dev/test/CI only. Never for txns, payments, or anything with an SLA expectation |

**License/audit note**: these are hosted SaaS, not code you audit — the relevant "audit" surface is their status page/uptime history and whether they publish SLAs, not a smart-contract audit. Check status pages before committing to one for a launch day.

## Realtime mechanism decision table

| Use case | Mechanism | Latency | Cost | When to use |
|---|---|---|---|---|
| Watch 1-50 accounts (user balances, single PDA, order status) | `accountSubscribe` WS | ~400ms-1s (slot-gated) | Low, included in most plans | Default choice for a dashboard/wallet UI |
| Watch a program's logs for specific events | `logsSubscribe` w/ `mentions` filter | ~400ms-1s | Low-med (log volume can be large on hot programs) | Indexing your own program's emitted events |
| Building an indexer over many accounts/programs at scale | Geyser via Yellowstone gRPC (direct or provider-hosted) | 10s-100s of ms, no slot-boundary batching wait | Med-high ($75-150/TB range across providers) | You've outgrown websockets: high account count, need sub-slot ordering, or WS drops are costing you correctness |
| Need to react to *your own* users' onchain activity (deposits, NFT sale, token transfer) without running infra | Helius Webhooks (Enhanced or Raw) | Seconds (push-based, no poll delay) | Per-webhook-call pricing, cheaper than polling at scale | Backend that reacts to events but doesn't need every intermediate account state |
| Simple "did my tx confirm" check | Polling `getSignatureStatuses` / `confirmTransaction` | 1 poll interval (400ms-2s typical) | Trivial | Post-submit confirmation loop — don't use a subscription for this, just poll a few times |
| Trading bot / MEV-sensitive path where every ms of ordering matters | Direct Yellowstone gRPC from Triton or a colocated provider node, staked connection for sends | Lowest available (gRPC streams, no WS framing overhead) | Highest (enterprise gRPC pricing + staked send fees) | Only when latency is directly monetized — this is the "pay for speed" tier |
| Bulk backfill / historical data | Plain HTTP RPC (`getSignaturesForAddress`, `getTransaction` in batches) or an indexer (Helius DAS, Old Faithful archive) | N/A (batch) | Cheapest per-record via batch/archive endpoints | Never use a websocket or gRPC stream for historical replay |

## When to pay for speed

Pay for staked connections / dedicated gRPC / SWQoS routing when:
- You're submitting transactions that compete for landing (arbitrage, sniping, liquidations) — unstaked public RPC sends get deprioritized by validators.
- You're indexing a high-TPS program and WS `logsSubscribe` is measurably dropping or lagging (check for gaps in slot sequence, not just "it feels slow").
- You have a monetizable reason ms matter (trading, auctions, MEV) — not "the dashboard felt sluggish."

Don't pay for it when:
- You're building a CRUD dApp / wallet UI — free-tier or entry paid RPC + WS is plenty; the bottleneck will be your frontend, not RPC latency.
- You haven't measured anything yet. Instrument first (slot lag, subscription drop rate, tx land rate) before upgrading tiers.

## WebSocket pitfalls checklist (`accountSubscribe`/`logsSubscribe`)

These bite every builder who assumes a WS connection behaves like a reliable pub/sub system. It doesn't.

- [ ] **Silent disconnects**: TCP/WS connections die without a close event (NAT timeout, LB idle-kill). Don't rely on `onclose`/`onerror` alone — add a heartbeat/ping and a max-silence timeout that forces a reconnect if no message (including slot notifications) arrives within N seconds.
- [ ] **Subscribe failures are silently swallowed** in some client libs (known issue in `@solana/web3.js` 1.x — see solana-labs/solana#19072). Always await the subscription confirmation and treat a missing/errored response as fatal, not a warning.
- [ ] **Subscriptions do NOT survive reconnect.** The server has no memory of what you cared about after a reconnect. Keep your subscription list (pubkeys, commitment, filters) in memory/state and re-issue every `accountSubscribe`/`logsSubscribe` call in your reconnect handler.
- [ ] **Gap in coverage between disconnect and reconnect.** You will miss events during the outage window. On reconnect, snapshot the last-seen slot/signature and backfill via a one-shot `getSignaturesForAddress` or `getAccountInfo` before trusting the new stream.
- [ ] **Reconnect storms.** Unbounded immediate reconnect attempts turn a blip into a self-inflicted rate-limit/outage. Use exponential backoff with jitter, cap retry rate.
- [ ] **Duplicate delivery.** Assume at-least-once delivery across reconnects/backfills. Make downstream processing idempotent, keyed by `(signature, slot)` or `(pubkey, slot)`.
- [ ] **Commitment level mismatch.** `processed` commitment on a subscription gives you data that can be rolled back on a fork. Use `confirmed` (or `finalized` for anything money-moving) unless you specifically need speculative/optimistic UI updates and can tolerate rollback.
- [ ] **One socket, many subscriptions is fine — but has a practical ceiling.** High-volume `logsSubscribe` without an address/mentions filter on a hot program (e.g. a popular AMM) can flood a single connection; scope filters tightly or move to gRPC.

## Minimal reconnect pattern (concept, provider-agnostic)

```ts
let subs: { method: "accountSubscribe" | "logsSubscribe"; params: unknown[] }[] = [];
let lastSeenSlot = 0;

function connect() {
  const ws = new WebSocket(RPC_WS_URL);
  let alive = true;
  const heartbeat = setInterval(() => {
    if (!alive) { ws.close(); return; } // force reconnect on silence
    alive = false;
    ws.send(JSON.stringify({ jsonrpc: "2.0", id: 1, method: "getHealth" }));
  }, 15_000);

  ws.onmessage = (e) => { alive = true; /* handle msg, track lastSeenSlot */ };
  ws.onclose = () => { clearInterval(heartbeat); scheduleReconnect(); };
  ws.onopen = () => { for (const s of subs) send(ws, s); backfillSince(lastSeenSlot); };
}

function scheduleReconnect(attempt = 1) {
  const delay = Math.min(30_000, 500 * 2 ** attempt) * (0.5 + Math.random());
  setTimeout(connect, delay);
}
```

Reuse-first: don't hand-roll this if your client SDK already does it. `@solana/kit` (successor to `@solana/web3.js` 1.x, which is in maintenance mode — re-verify current status) and Helius's SDKs handle reconnect/resubscribe internally in newer versions; check before writing your own. gill (community Solana SDK) also wraps this. Verify current behavior in the SDK version you're pinned to — this has changed across major versions.

## Geyser / Yellowstone gRPC

- **What it is**: Geyser is the Solana validator plugin interface for streaming account/tx/block/slot updates directly off a validator, bypassing RPC's JSON-RPC/WS layer entirely. Yellowstone (Dragon's Mouth) is Triton One's gRPC service built on Geyser — now the de facto standard; "Yellowstone-compatible gRPC" from QuickNode/Alchemy/Helius(LaserStream) means they speak the same protobuf schema.
- **Why it's faster**: no JSON serialization, no WS framing, streams over HTTP/2, and (per Triton) can deliver on the order of 100s-of-ms advantage over WS for latency-sensitive flows.
- **Fumarole** (Triton): adds replay/resume so a dropped gRPC stream doesn't lose data — closes the same "gap on reconnect" problem WS has, at the protocol level. Prefer this over hand-rolled backfill logic if your provider offers it.
- **Self-hosting a Geyser plugin**: only justified at serious scale (running your own validator + custom plugin, e.g. `yellowstone-grpc` geyser plugin from rpcpool). For a 6-12h build, use a provider's hosted gRPC (Helius LaserStream, Triton Dragon's Mouth, QuickNode/Alchemy Yellowstone-compatible) instead of standing up validator infra.
- **Cost reality check**: gRPC streaming is billed by data volume (TB), not request count — a chatty, unfiltered subscription can get expensive fast. Filter tightly (specific accounts/programs, not "everything") before going to gRPC, same discipline as `logsSubscribe`.

## Webhooks vs WS vs polling

| | Push/pull | Infra you run | Best for |
|---|---|---|---|
| **Webhooks** (Helius Enhanced/Raw) | Push, HTTP POST to your endpoint | None — just an HTTP handler | Backend reacting to specific event types (NFT sale, transfer) without maintaining a live connection; avoids polling entirely, and Enhanced webhooks include parsed data so you skip follow-up RPC calls |
| **WebSocket subscribe** | Push, long-lived connection | A process holding the socket open, with reconnect logic | Frontend/live-dashboard use cases, low-to-medium account counts |
| **Polling** | Pull, on your schedule | A cron/interval loop | Low-frequency checks (tx confirmation, "has this order settled"); simplest to reason about, worst for anything needing sub-second reaction |

Don't poll when a webhook or subscription exists for the event you care about — polling at the interval needed to feel "realtime" (sub-second) will burn far more RPC credits than a push mechanism.

## Do / Don't

- **Do** put your RPC endpoint + API key behind an env var / server-side proxy — never ship a paid provider's API key in client-side bundle code.
- **Do** use `confirmed` commitment as the default for subscriptions feeding UI; `finalized` for anything triggering an irreversible off-chain action (payout, mint reveal).
- **Do** measure before upgrading tiers: track subscription drop count, slot lag (`current slot - last notified slot`), and tx land rate. These numbers justify a paid gRPC/staked-connection upgrade to a stakeholder; "it feels slow" doesn't.
- **Don't** run multiple redundant subscriptions to the same account across different providers "for redundancy" without a plan to dedupe — you'll double-process events.
- **Don't** assume a provider's free tier rate limit is stable — check current docs (rpcfast.com/Chainstack comparison posts and each provider's own pricing page) before launch day, these change often.
- **Don't** use `getProgramAccounts` over a subscription-style polling loop as a substitute for `logsSubscribe`/webhooks — it's an expensive full-scan call, not a realtime primitive.

## See also

- [../solana/tx-landing.md](../solana/tx-landing.md) — staked connections, priority fees, and landing transactions (the send-side counterpart to this file's receive-side focus)
- [../solana/client-patterns.md](../solana/client-patterns.md) — client SDK patterns this file's snippets assume
- [../security/incident-lessons.md](../security/incident-lessons.md) — postmortems, some RPC/realtime-related
