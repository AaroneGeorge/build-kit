---
title: Stack Defaults & Project Conventions
description: The builder's locked default stack, RPC/latency defaults, and posture so no skill ever re-asks.
applies_to: [solana, evm]
sources:
  - "Anchor - https://www.anchor-lang.com/ (verified 2026-08-25)"
  - "@solana/kit - https://github.com/anza-xyz/kit (verified 2026-08-25)"
  - "create-solana-dapp - https://github.com/solana-developers/create-solana-dapp (verified 2026-08-25)"
  - "Helius docs - https://docs.helius.dev/ (verified 2026-08-25)"
  - "Triton One - https://triton.one/ (verified 2026-08-25)"
  - "Jito - https://docs.jito.wtf/ (verified 2026-08-25)"
  - "Neon serverless Postgres - https://neon.tech/docs (verified 2026-08-25)"
  - "Foundry - https://book.getfoundry.sh/ (verified 2026-08-25)"
last_verified: 2026-08-25
---

# Stack Defaults

These are locked. Skills load this file instead of asking. Edit the defaults below (RPC provider, env var names, DB choice, stack picks) to match your own stack.

## Chains & priority
- **Solana = primary.** EVM = secondary (solid but lighter coverage).
- Deploy posture: **devnet/demo first**, always. Mainnet is a later, manual, explicitly-confirmed step.
- Gates are **advisory, never blocking** — surface criticals loudly, never silently pass, never stop the builder.

## Solana stack
- Programs: **Anchor** (latest stable). Prefer built-in account constraints over manual checks.
- Client: **@solana/kit** (formerly web3.js 2.0) for new code; `@solana/wallet-adapter` for the frontend. Legacy `@solana/web3.js` 1.x only when a dependency forces it. See `knowledge/solana/client-patterns.md`.
- Frontend: **Next.js (App Router) + @solana/wallet-adapter**. Scaffold fresh from **create-solana-dapp**.
- Services: **Node/TS**.
- DB: **Postgres on Neon** (serverless). See `knowledge/latency/indexing-caching-db.md` for pooling/cold-start gotchas.

## EVM stack
- **Foundry** + **OpenZeppelin / Solady**. See `knowledge/evm/foundry-and-patterns.md`.

## RPC / landing / data defaults  (edit keys via env, never commit)
- RPC: **Helius** (primary) or **Triton** — env: `HELIUS_API_KEY`, `RPC_URL`.
- Tx landing: **Jito** bundles/tips for contested/MEV-sensitive sends; priority fees otherwise. See `knowledge/solana/tx-landing.md`.
- Realtime: Helius webhooks / LaserStream or Yellowstone Geyser over polling. See `knowledge/latency/rpc-and-realtime.md`.
- Prices/oracle: **Pyth** on-chain; **Jupiter** price API off-chain.
- Indexing: **Helius DAS** first; custom Geyser only if needed.

## Secrets
- Keys/secrets **never** in the repo or client bundle. Use env vars or the OS keychain. Runbooks reference `ENV_VAR` names only.
- Standard env: `RPC_URL`, `HELIUS_API_KEY`, `DATABASE_URL` (Neon, pooled), signer via keychain or `KEYPAIR_PATH`.

## Reuse-first posture (the #1 rule)
- ~90% of what gets built already exists. Default path = **find → evaluate → adapt** proven code (`knowledge/reuse-index/`). Writing from scratch is the exception that needs justification.
- Anything public is fair game. Always **record license + audit status** in reports so the builder decides; don't block on it.

## Archetypes (most frequent first)
1. **Consumer sites with light contracts** (deposit/escrow/payout, auction) — flagship. `recipes/consumer-sites.md`
2. DeFi trading (DEX/AMM, aggregators, vaults, staking). `recipes/defi-trading.md`
3. Launch & mint (launchpads, presales, bonding curves, mints, vesting). `recipes/launch-mint.md`
4. Bots & infra (sniper/copy-trade, Jito/MEV, indexers, price APIs, TG bots). `recipes/bots-infra.md`
5. Wallets & payments (smart wallets, AA, escrow, payments). `recipes/wallets-payments.md`

## Time budget
- Target: idea → production-quality in **6–12 hours**. The bottleneck is **verification**, not generation — every skill should optimize for telling the builder *what to eyeball*.

## See also
- `knowledge/reuse-index/README.md`
- `knowledge/solana/client-patterns.md`
- `knowledge/solana/tx-landing.md`
- `knowledge/latency/rpc-and-realtime.md`
- `knowledge/security/ship-gate-checklist.md`
