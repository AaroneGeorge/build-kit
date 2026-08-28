---
title: Scale-Later Seams
description: Rules for hackathon shortcuts - build the simplest thing, but only along seams that let the app scale horizontally later without a rewrite.
applies_to: [solana, evm, services, frontend]
sources:
  - "The Twelve-Factor App (processes/statelessness) - https://12factor.net/processes (verified 2026-08-29)"
  - "Neon serverless driver & pooling - https://neon.tech/docs/connect/connection-pooling (verified 2026-08-29)"
  - "Vercel functions are stateless - https://vercel.com/docs/functions (verified 2026-08-29)"
last_verified: 2026-08-29
---

# Scale-Later Seams

Hackathon rule: **write the simplest version, but put every shortcut on a seam** — a boundary where the scaled implementation can replace the simple one without touching callers. "Scalable later" means: run N copies of every service behind a load balancer and nothing breaks or corrupts. You get that from discipline that costs ~zero extra time now.

## The five seam rules

1. **Stateless processes.** All state lives in Postgres (Neon) or on-chain — never in process memory, module-level variables, or local files. No in-memory sessions, counters, caches, or queues. Any instance can serve any request; killing one loses nothing. This single rule is 80% of horizontal scalability.
2. **Idempotent handlers.** Key every state-changing operation on a natural ID (tx signature, order ID, `user+round`) with a DB unique constraint, so retries, double-clicks, webhook redeliveries, and two workers racing are all safe. `INSERT ... ON CONFLICT DO NOTHING` is the hackathon version of exactly-once.
3. **Correctness from the DB, not from being single.** Never rely on "only one instance runs" for correctness. Use DB transactions, unique constraints, and `UPDATE ... WHERE status='open'`-style guards (optimistic locking) now; that same code is already safe with 20 workers later.
4. **Side effects and mocks behind module boundaries.** Every mock (fake oracle, hardcoded second user, stubbed notifier) and every side effect (send tx, send email, index event) is one module exporting one function. In-process and fake today; a queue consumer or the real service later — callers never change.
5. **Config via env.** `RPC_URL`, `DATABASE_URL`, program IDs, feature flags — env vars only (per stack-defaults; never committed). Scaling then means pointing at bigger infra, not editing code.

## Stack-specific notes

- **Next.js on Vercel** (the default): serverless functions are stateless and horizontally scaled for you — don't fight it. No `fs` writes, no module-level mutable state, no long-lived in-process websocket fan-out (use polling now; Helius webhooks/LaserStream later — keep the data-fetch in one module so the swap is local).
- **Neon Postgres:** always the **pooled** connection string from serverless functions; the driver is designed for many short-lived connections, so scaling instances doesn't exhaust the DB.
- **Node/TS services:** one process today is fine — but because of rules 1–3 it must already be safe to run twice. Test it mentally: "two copies of this loop run — what corrupts?" Fix that now (usually one unique constraint).
- **On-chain (Solana):** per-user/per-round PDAs rather than funneling everything through one global account where write-lock contention serializes throughput. If the simple design does have a hot account (a single vault/counter), that's acceptable for the demo — **name it in SPEC.md as the known scale-later item** rather than redesigning at 2am.

## What NOT to build at a hackathon

Queues (Redis/SQS), caches, microservices, Kubernetes, custom indexers, websocket infrastructure, multi-region anything. These are the *later* side of the seams above. If a slice plan contains any of them, the plan is wrong — cut it and rely on the seam.

## The 30-second review

Before submission, grep the services for: module-level `let`/`Map`/arrays holding state, `fs.write`, in-memory `setInterval` state machines, unpooled DB URLs, and any handler that isn't idempotent-keyed. Each hit is either fixed (usually minutes) or written into SPEC.md as a disclosed scale-later item.
