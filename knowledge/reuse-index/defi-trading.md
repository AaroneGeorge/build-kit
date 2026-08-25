---
title: Reuse Index - DeFi Trading (DEX/AMM, Aggregators, Vaults, Staking)
description: Vetted Solana DeFi building blocks (swap/aggregation, AMMs, orderbooks, perps, lending, liquid staking) with license and audit status for fast reuse.
applies_to: [solana]
sources:
  - "Jupiter (jup-ag) - https://github.com/jup-ag (verified 2026-08-25)"
  - "Raydium SDK v2 - https://github.com/raydium-io/raydium-sdk-V2 (verified 2026-08-25)"
  - "Orca Whirlpools - https://github.com/orca-so/whirlpools (verified 2026-08-25)"
  - "Meteora DLMM SDK - https://github.com/MeteoraAg/dlmm-sdk (verified 2026-08-25)"
  - "OpenBook v2 - https://github.com/openbook-dex/openbook-v2 (verified 2026-08-25)"
  - "Phoenix (Ellipsis Labs) - https://github.com/Ellipsis-Labs/phoenix-sdk (verified 2026-08-25)"
  - "Drift Protocol v2 - https://github.com/drift-labs/protocol-v2 (verified 2026-08-25)"
  - "Kamino Finance klend-sdk - https://github.com/Kamino-Finance/klend-sdk (verified 2026-08-25)"
  - "marginfi v2 / mrgn-ts - https://github.com/mrgnlabs/marginfi-v2 (verified 2026-08-25)"
  - "SPL Stake Pool - https://github.com/solana-program/stake-pool (verified 2026-08-25)"
  - "Marinade liquid-staking-program - https://github.com/marinade-finance/liquid-staking-program (verified 2026-08-25)"
  - "Jito StakeNet - https://github.com/jito-foundation/stakenet (verified 2026-08-25)"
last_verified: 2026-08-25
---

DeFi trading on Solana rarely needs a new AMM or orderbook written from scratch — swap routing, concentrated-liquidity pools, perps, lending, and liquid staking all have mature, in-production programs with public SDKs. Default to routing through Jupiter for swaps and integrating an existing pool/program as a dependency; only fork a program when the archetype genuinely needs custom pool logic. Reuse posture: anything public is fair game — record license + audit status below so the builder decides, do not block on it.

### Jupiter (jup-ag) - swap aggregator API/SDK, the default "just get me a swap" path
- Repo/Docs: https://github.com/jup-ag , https://dev.jup.ag/
- What you get: hosted REST API (quote/swap/price) at api.jup.ag + lite-api.jup.ag, TS/Rust client SDKs, CLI, Next.js example app. Also covers Perps, Lend, Trigger (limit orders), Recurring (DCA) under one API key.
- Chain/stack: solana, ts-sdk, rust
- Audit status: underlying routed venues carry their own audits; Jupiter's own aggregation/routing program has had external reviews (not centrally published per-repo) - re-verify
- License: individual SDK repos are mostly MIT/Apache-2.0 (check per-repo); the hosted API itself is a service, not code you fork
- Maintenance: very active, official org with frequent releases and example repos (re-verify exact recency)
- Fork vs import: import-as-dep - this is the correct default for "swap tokens" instead of integrating any single DEX directly
- Known pitfalls: rate limits on the free lite-api tier (need paid key for production volume); quote staleness under volatility requires slippage/priority-fee tuning; routing can span multiple hops through venues with their own downtime.

### Raydium SDK v2 - official TS SDK for Raydium AMM/CLMM pools
- Repo/Docs: https://github.com/raydium-io/raydium-sdk-V2 , https://docs.raydium.io
- What you get: TypeScript SDK for pool creation, swaps, LP, and CLMM position management against Raydium's on-chain programs; demo repo included.
- Chain/stack: solana, ts-sdk
- Audit status: Raydium AMM/CLMM programs have prior third-party audits referenced in docs; re-verify current report links before shipping
- License: GPL-3.0 - FLAG: strong copyleft, review before bundling into a closed-source product
- Maintenance: active, official raydium-io org, regular releases and open issues (re-verify)
- Fork vs import: import-as-dep for standard integration; read-for-reference if avoiding GPL-3.0 obligations and reimplementing calls against the IDL directly
- Known pitfalls: GPL-3.0 licensing can force copyleft on statically-linked consumers - legal review needed for proprietary apps; v1 and v2 SDKs are not interchangeable, mixing them breaks pool math.

### Orca Whirlpools - concentrated-liquidity AMM contract + SDK
- Repo/Docs: https://github.com/orca-so/whirlpools , https://orca-so.github.io/whirlpools/
- What you get: on-chain CLMM program (Rust/Anchor) plus TS SDK (@orca-so/whirlpools-sdk) for pool interaction, position management, and quoting.
- Chain/stack: solana+anchor, ts-sdk
- Audit status: audited historically (Kudelski and others per Orca docs) - re-verify current audit report links
- License: dual MIT / Apache-2.0 (permissive, pick either) - cleanest license in this list
- Maintenance: active official org, has releases and SDK reference docs updated regularly (re-verify)
- Fork vs import: import-as-dep via TS SDK for integration; fork-and-adapt the on-chain program only if building a genuinely new CLMM variant
- Known pitfalls: concentrated liquidity math (tick spacing, sqrt-price) is easy to get subtly wrong when hand-rolling quotes - prefer SDK's built-in quote functions over reimplementing; position NFTs add extra account-management complexity vs simple LP tokens.

### Meteora DLMM SDK - dynamic liquidity market maker (bin-based AMM)
- Repo/Docs: https://github.com/MeteoraAg/dlmm-sdk , https://docs.meteora.ag/resources/audits/dlmm
- What you get: TS/Rust SDK for Meteora's DLMM bin-based concentrated liquidity program - swaps, bin arrays, LP position management.
- Chain/stack: solana+anchor, ts-sdk, rust
- Audit status: audited - multiple reports on file (Zenith Aug 2025, Offside Labs Oct 2025/Mar 2025/Nov 2024/Jan 2024, OtterSec Feb 2025/Feb 2024, Sec3 Feb 2024) - one of the best-documented audit trails in this list
- License: Apache-2.0 on the published Rust crate; verify the dlmm-sdk repo's own LICENSE file matches before relying on it (re-verify)
- Maintenance: active, official MeteoraAg org, has changelog with frequent version bumps
- Fork vs import: import-as-dep - DLMM's bin math is intricate, not worth reimplementing
- Known pitfalls: bin-based liquidity has a steeper learning curve than tick-based CLMM (active bin, bin arrays, bin step); DLMM pools can have thin liquidity outside the active bin range, causing worse-than-expected slippage on larger trades.

### OpenBook v2 - central limit order book (CLOB) program, community successor to Serum
- Repo/Docs: https://github.com/openbook-dex/openbook-v2
- What you get: on-chain CLOB program (Rust/Anchor) + TS client for order placement, matching, and market data - the reference orderbook DEX on Solana.
- Chain/stack: solana+anchor, ts-sdk
- Audit status: unaudited/partial - re-verify; one third-party scan flagged the broader `openbook-dex/program` (v1) codebase as stale, but v2 monorepo shows continued releases
- License: split - majority MIT, with GPL-gated pieces needed to compile the Solana program itself (behind an `enable-gpl` feature flag) - FLAG the GPL-gated portion if shipping closed-source
- Maintenance: has tagged releases; check recency of last commit before depending on it in production (re-verify)
- Fork vs import: import-as-dep for the TS client; read-for-reference for the on-chain matching-engine logic if building a custom orderbook
- Known pitfalls: CLOB integration requires crank/consume-events infrastructure (someone must call crank instructions to settle trades) - budget for that off-chain component; GPL feature-gating means default builds may silently exclude functionality you need.

### Phoenix (Ellipsis Labs) - fully on-chain orderbook DEX, no crank required
- Repo/Docs: https://github.com/Ellipsis-Labs/phoenix-sdk , https://github.com/Ellipsis-Labs/phoenix-v1
- What you get: on-chain limit orderbook program with Rust/TS/Python SDKs; settlement happens atomically in the same transaction (no separate crank step, unlike OpenBook).
- Chain/stack: solana, ts-sdk, rust, python
- Audit status: audited by OtterSec (report in-repo)
- License: BUSL-1.1 (Business Source License) - FLAG: not open-source by OSI definition; converts to GPL-2.0-or-later on 2027-02-13 change date - confirm current production-use terms before relying on it commercially before that date
- Maintenance: active org (Ellipsis Labs), SDK has ongoing activity (re-verify exact last-commit date)
- Fork vs import: import-as-dep for the SDK to trade against existing Phoenix markets; read-for-reference for the crank-free settlement design pattern even when building something else
- Known pitfalls: BUSL restricts certain production/commercial uses until the change date - check license text for your specific use case; no-crank design means client must handle in-transaction settlement correctly or trades fail silently.

### Drift Protocol v2 - on-chain perpetuals DEX with multiple liquidity mechanisms
- Repo/Docs: https://github.com/drift-labs/protocol-v2 , https://drift-labs.github.io/protocol-v2/sdk/
- What you get: perps/spot trading program plus a full-featured TS SDK (@drift-labs/sdk) covering order placement, JIT auctions, vAMM/DLOB liquidity, and account management.
- Chain/stack: solana+anchor, ts-sdk
- Audit status: has published audits historically; re-verify current report links in-repo before shipping
- License: Apache-2.0 (permissive)
- Maintenance: very active - PRs and SDK updates as recent as April 2026, frequent releases
- Fork vs import: import-as-dep - the TS SDK is the standard way to build a perps front-end or bot against Drift; fork the on-chain program only for a genuinely custom perps design
- Known pitfalls: perps SDK has a large surface area (oracle accounts, market accounts, user accounts) - expect a real ramp-up before first successful trade; JIT/DLOB liquidity behavior differs meaningfully from simple AMM swaps, test against devnet market data before mainnet.

### Kamino Finance klend-sdk - lending/borrowing SDK (also covers leveraged vaults)
- Repo/Docs: https://github.com/Kamino-Finance/klend-sdk , https://github.com/Kamino-Finance/audits
- What you get: TS SDK for Kamino Lending (klend) - deposit/borrow/repay, obligation management, and (via sibling kliquidity-sdk) automated CLMM vault strategies built on top of Orca/Raydium liquidity.
- Chain/stack: solana+anchor, ts-sdk
- Audit status: audited - dedicated audits repo with Sec3, Offside Labs, Certora, and OSEC formal-verification reports on file (strong audit trail)
- License: not confirmed for klend-sdk specifically in this pass - sibling farms-sdk is Apache-2.0, program is inspired by Solana Labs' Apache-2.0 Token Lending - re-verify klend-sdk's own LICENSE file before relying on it
- Maintenance: very active, npm package updated within days at time of check (v7.3.20)
- Fork vs import: import-as-dep - lending math (interest accrual, liquidation thresholds, obligation health) is high-risk to reimplement
- Known pitfalls: obligation/health-factor calculations are easy to get wrong in a UI - always source health/liquidation data from the SDK, never recompute independently; kliquidity vault strategies add an extra abstraction layer over the underlying AMM, adds latency to state reads.

### marginfi v2 / mrgn-ts - lending protocol SDK (note: client v2 package is being deprecated)
- Repo/Docs: https://github.com/mrgnlabs/marginfi-v2 , https://github.com/mrgnlabs/mrgn-ts , https://docs.marginfi.com/ts-sdk
- What you get: on-chain lending program plus TS SDK for deposits, borrows, and account health; mrgn-ts monorepo also has reference frontend apps.
- Chain/stack: solana+anchor, ts-sdk
- Audit status: audited internally and by OtterSec (reports in-repo `audits/` folder)
- License: Apache-2.0 (mrgn-ts monorepo)
- Maintenance: CAUTION - @mrgnlabs/marginfi-client-v2 is flagged deprecated by the maintainers in favor of a newer `p0-ts-sdk`; verify current recommended package before starting new work (re-verify)
- Fork vs import: import-as-dep, but confirm which SDK package is currently maintained before committing - read-for-reference on mrgn-ts frontend apps for UI patterns
- Known pitfalls: deprecated-but-still-published SDK package is a trap for new integrations - check docs.marginfi.com for the current recommended package name before wiring it up; account health math has the same "don't recompute independently" caveat as other lending protocols.

### SPL Stake Pool - Solana Labs' standard liquid-staking pool program
- Repo/Docs: https://github.com/solana-program/stake-pool , https://spl.solana.com/stake-pool
- What you get: the canonical on-chain stake-pool program (JS + Python bindings) that most liquid-staking tokens (including Jito's JitoSOL and many others) are built on top of - deposit SOL/stake accounts, mint pool tokens, manage validator stake distribution.
- Chain/stack: solana, ts-sdk, python
- Audit status: audited - multiple firms on file (Quantstamp 2021, Neodyme 2021-2023 multiple rounds, Kudelski 2021, OtterSec 2023, Halborn 2023) via the security-audits repo, one of the most audited programs in this list
- License: not confirmed in this pass, standard Solana program library repos are typically Apache-2.0 - re-verify LICENSE file
- Maintenance: actively maintained under the solana-program org (successor to solana-labs/solana-program-library placement)
- Fork vs import: fork-and-adapt for building a new liquid-staking token (this is the standard base every LST forks); import-as-dep if just integrating with an existing pool
- Known pitfalls: stake-pool epoch-boundary update instructions (update validator list / update pool balance) must be called every epoch or deposits/withdrawals stall - budget an off-chain cranker/cron job; validator selection and commission changes are governed by a manager authority - understand the trust model before pointing users at a third-party pool.

### Marinade liquid-staking-program - production LST reference implementation (mSOL)
- Repo/Docs: https://github.com/marinade-finance/liquid-staking-program
- What you get: Anchor-based liquid staking program (first on Solana mainnet) plus mSOL<->SOL swap pool - a battle-tested reference distinct from the generic SPL stake pool.
- Chain/stack: solana+anchor
- Audit status: audited by Kudelski Security, Ackee Blockchain, and Neodyme (reports linked from marinade.finance docs)
- License: repo includes a LICENSE.md - specific license type not confirmed in this pass, re-verify before reuse
- Maintenance: established, long-running production protocol; verify recent commit activity before assuming active development (re-verify)
- Fork vs import: read-for-reference primarily - this is best studied as the reference LST design (delayed unstake ticket accounts, validator scoring) rather than forked wholesale, since Marinade's specific tokenomics/governance are baked in
- Known pitfalls: mSOL's exchange rate accrues via an internal price oracle updated on a schedule - do not assume 1:1 with SOL anywhere in UI or accounting; instant-unstake liquidity pool has separate risk/fee parameters from the delayed-unstake path.

### Jito StakeNet - decentralized stake-pool manager built on SPL Stake Pool (JitoSOL infra)
- Repo/Docs: https://github.com/jito-foundation/stakenet , https://www.jito.wtf/stakers/
- What you get: Validator History and Steward on-chain programs that automate validator selection/scoring for a stake pool - the automation layer JitoSOL runs on top of the standard SPL Stake Pool program (not a separate pool program itself).
- Chain/stack: solana+anchor
- Audit status: not confirmed in this pass - re-verify via jito-foundation security policy / audits before relying on it
- License: not confirmed in this pass - re-verify LICENSE file (Jito's other repos are typically Apache-2.0)
- Maintenance: active, official jito-foundation org
- Fork vs import: read-for-reference for the validator-scoring/steward automation pattern if building a managed stake pool; pair with SPL Stake Pool (above) as the actual token/pool program
- Known pitfalls: StakeNet is automation on top of SPL Stake Pool, not a standalone staking program - don't confuse it with a full LST implementation; validator scoring criteria (MEV commission, uptime, etc.) encode Jito-specific opinions that may not match your product's validator-selection needs.
