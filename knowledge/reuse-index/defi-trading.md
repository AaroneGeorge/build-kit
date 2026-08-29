---
title: Reuse Index - DeFi Trading (DEX/AMM, Aggregators, Vaults, Staking)
description: Vetted Solana DeFi building blocks (swap/aggregation, AMMs, orderbooks, perps, lending, liquid staking) with license and audit status for fast reuse.
applies_to: [solana]
sources:
  - "Jupiter (jup-ag) - https://github.com/jup-ag (verified 2026-08-29)"
  - "Raydium SDK v2 - https://github.com/raydium-io/raydium-sdk-V2 (verified 2026-08-29)"
  - "Orca Whirlpools - https://github.com/orca-so/whirlpools (verified 2026-08-29)"
  - "Meteora DLMM SDK - https://github.com/MeteoraAg/dlmm-sdk (verified 2026-08-29)"
  - "OpenBook v2 - https://github.com/openbook-dex/openbook-v2 (verified 2026-08-29)"
  - "Phoenix (Ellipsis Labs) - https://github.com/Ellipsis-Labs/phoenix-sdk (verified 2026-08-29)"
  - "Drift Protocol v2 - https://github.com/velocity-exchange/protocol-v2 (moved from drift-labs/protocol-v2, old URL redirects; verified 2026-08-29)"
  - "Kamino Finance klend-sdk - https://github.com/Kamino-Finance/klend-sdk (verified 2026-08-29)"
  - "marginfi v2 / p0-ts-sdk - https://github.com/0dotxyz/marginfi-v2 (moved from mrgnlabs/marginfi-v2, old URL redirects; verified 2026-08-29)"
  - "SPL Stake Pool - https://github.com/solana-program/stake-pool (verified 2026-08-29)"
  - "Marinade liquid-staking-program - https://github.com/marinade-finance/liquid-staking-program (verified 2026-08-29)"
  - "Jito StakeNet - https://github.com/jito-foundation/stakenet (verified 2026-08-29)"
last_verified: 2026-08-29
---

DeFi trading on Solana rarely needs a new AMM or orderbook written from scratch — swap routing, concentrated-liquidity pools, perps, lending, and liquid staking all have mature, in-production programs with public SDKs. Default to routing through Jupiter for swaps and integrating an existing pool/program as a dependency; only fork a program when the archetype genuinely needs custom pool logic. Reuse posture: anything public is fair game — record license + audit status below so the builder decides, do not block on it.

### Jupiter (jup-ag) - swap aggregator API/SDK, the default "just get me a swap" path
- Repo/Docs: https://github.com/jup-ag , https://dev.jup.ag/
- What you get: hosted REST API (quote/swap/price) at api.jup.ag + lite-api.jup.ag, TS/Rust client SDKs, CLI, Next.js example app. Also covers Perps, Lend, Trigger (limit orders), Recurring (DCA) under one API key.
- Chain/stack: solana, ts-sdk, rust
- Audit status: audited - Jupiter now publishes a central audits page at https://developers.jup.ag/docs/resources/audits covering Swap (Offside Labs Oct 2025/Apr 2024, Sec3), Perps (Offside Labs, OtterSec, Sec3), Lend (Certora, Code4rena, OtterSec, Offside Labs, MixBytes, Zenith), Limit Order, Lock, and DAO (verified 2026-08-29)
- License: individual SDK repos are mostly MIT/Apache-2.0 (check per-repo); the hosted API itself is a service, not code you fork
- Maintenance: very active - jup-ag org repos pushed within days of check (jupiter-amm-interface and docs pushed 2026-08-28, rfq-webhook-toolkit 2026-08-27) (verified 2026-08-29)
- Fork vs import: import-as-dep - this is the correct default for "swap tokens" instead of integrating any single DEX directly
- Known pitfalls: rate limits on the free lite-api tier (need paid key for production volume); quote staleness under volatility requires slippage/priority-fee tuning; routing can span multiple hops through venues with their own downtime.

### Raydium SDK v2 - official TS SDK for Raydium AMM/CLMM pools
- Repo/Docs: https://github.com/raydium-io/raydium-sdk-V2 , https://docs.raydium.io
- What you get: TypeScript SDK for pool creation, swaps, LP, and CLMM position management against Raydium's on-chain programs; demo repo included.
- Chain/stack: solana, ts-sdk
- Audit status: audited - reports live at https://docs.raydium.io/security/audits and in-repo at raydium-io/raydium-docs/audit: Kudelski Q2 2021, OtterSec Q3 2022, MadShield Q2 2023 + Q1 2024, Halborn Q4 2024 + Q2 2025, Sec3 Q3 2025 + Q2 2026 (verified 2026-08-29)
- License: GPL-3.0 (confirmed via repo LICENSE, verified 2026-08-29) - FLAG: strong copyleft, review before bundling into a closed-source product
- Maintenance: active - official raydium-io org, 349 stars, last push 2026-08-24 (verified 2026-08-29)
- Fork vs import: import-as-dep for standard integration; read-for-reference if avoiding GPL-3.0 obligations and reimplementing calls against the IDL directly
- Known pitfalls: GPL-3.0 licensing can force copyleft on statically-linked consumers - legal review needed for proprietary apps; v1 and v2 SDKs are not interchangeable, mixing them breaks pool math.

### Orca Whirlpools - concentrated-liquidity AMM contract + SDK
- Repo/Docs: https://github.com/orca-so/whirlpools , https://orca-so.github.io/whirlpools/
- What you get: on-chain CLMM program (Rust/Anchor) plus TS SDK (@orca-so/whirlpools-sdk) for pool interaction, position management, and quoting.
- Chain/stack: solana+anchor, ts-sdk
- Audit status: audited - six reports in-repo (.audits/, linked from README): Kudelski Jan 2022, Neodyme May 2022, OtterSec Aug 2024, Sec3 Feb/Jun/Aug 2025; OSec verified-build status also linked (verified 2026-08-29)
- License: CHANGED - FLAG: custom "Orca License" since 2025-02-27 (per repo LICENSE): non-commercial use only, revocable, non-sublicensable, non-transferable; the former MIT/Apache-2.0 dual license no longer applies to current code, so commercial use or forks need Orca's permission (verified 2026-08-29)
- Maintenance: active - official org, 539 stars, last push 2026-08-28 (verified 2026-08-29)
- Fork vs import: import-as-dep via TS SDK for integration; fork-and-adapt the on-chain program only if building a genuinely new CLMM variant
- Known pitfalls: concentrated liquidity math (tick spacing, sqrt-price) is easy to get subtly wrong when hand-rolling quotes - prefer SDK's built-in quote functions over reimplementing; position NFTs add extra account-management complexity vs simple LP tokens.

### Meteora DLMM SDK - dynamic liquidity market maker (bin-based AMM)
- Repo/Docs: https://github.com/MeteoraAg/dlmm-sdk , https://docs.meteora.ag/resources/audits/dlmm
- What you get: TS/Rust SDK for Meteora's DLMM bin-based concentrated liquidity program - swaps, bin arrays, LP position management.
- Chain/stack: solana+anchor, ts-sdk, rust
- Audit status: audited - multiple reports on file (Zenith Aug 2025, Offside Labs Oct 2025/Mar 2025/Nov 2024/Jan 2024, OtterSec Feb 2025/Feb 2024, Sec3 Feb 2024) - one of the best-documented audit trails in this list
- License: unclear - FLAG: the dlmm-sdk repo has NO LICENSE file, and npm @meteora-ag/dlmm v1.9.14 declares ISC in package.json; the earlier "Apache-2.0 on the Rust crate" claim could not be confirmed from the repo - treat as unlicensed at repo level and confirm terms with Meteora before commercial reuse (verified 2026-08-29)
- Maintenance: active, official MeteoraAg org - last push 2026-08-20, npm publish 2026-08-12, 307 stars (verified 2026-08-29)
- Fork vs import: import-as-dep - DLMM's bin math is intricate, not worth reimplementing
- Known pitfalls: bin-based liquidity has a steeper learning curve than tick-based CLMM (active bin, bin arrays, bin step); DLMM pools can have thin liquidity outside the active bin range, causing worse-than-expected slippage on larger trades.

### OpenBook v2 - central limit order book (CLOB) program, community successor to Serum
- Repo/Docs: https://github.com/openbook-dex/openbook-v2
- What you get: on-chain CLOB program (Rust/Anchor) + TS client for order placement, matching, and market data - the reference orderbook DEX on Solana.
- Chain/stack: solana+anchor, ts-sdk
- Audit status: no audit report or link found in the repo or README - treat as unaudited (unconfirmed as of 2026-08-29)
- License: split - majority MIT, with `programs/openbook-v2/src/instructions` and below under GPL-3.0 (confirmed via repo LICENSE; GPL pieces sit behind an `enable-gpl` feature flag) - FLAG the GPL portion if shipping closed-source (verified 2026-08-29)
- Maintenance: STALE - last commit 2024-06-23 and last release v0.2.10 2024-06-24, no commits in over two years; do not depend on it expecting upstream fixes (verified 2026-08-29)
- Fork vs import: import-as-dep for the TS client; read-for-reference for the on-chain matching-engine logic if building a custom orderbook
- Known pitfalls: CLOB integration requires crank/consume-events infrastructure (someone must call crank instructions to settle trades) - budget for that off-chain component; GPL feature-gating means default builds may silently exclude functionality you need.

### Phoenix (Ellipsis Labs) - fully on-chain orderbook DEX, no crank required
- Repo/Docs: https://github.com/Ellipsis-Labs/phoenix-sdk , https://github.com/Ellipsis-Labs/phoenix-v1
- What you get: on-chain limit orderbook program with Rust/TS/Python SDKs; settlement happens atomically in the same transaction (no separate crank step, unlike OpenBook).
- Chain/stack: solana, ts-sdk, rust, python
- Audit status: audited - OtterSec and MadShield reports in-repo (phoenix-v1/audits/) (verified 2026-08-29)
- License: CHANGED - phoenix-v1 is now MIT (repo LICENSE, "Copyright 2026 Ellipsis Labs"); the earlier BUSL-1.1 flag no longer applies to current code; note the phoenix-sdk repo itself carries no LICENSE file (verified 2026-08-29)
- Maintenance: slow but alive - phoenix-sdk last push 2026-02-04 (97 stars), phoenix-v1 last push 2026-06-13 (278 stars) (verified 2026-08-29)
- Fork vs import: import-as-dep for the SDK to trade against existing Phoenix markets; read-for-reference for the crank-free settlement design pattern even when building something else
- Known pitfalls: no-crank design means client must handle in-transaction settlement correctly or trades fail silently; the SDK repo lacks its own LICENSE file - confirm terms for the SDK code specifically before vendoring it.

### Drift Protocol v2 - on-chain perpetuals DEX with multiple liquidity mechanisms
- Repo/Docs: https://github.com/velocity-exchange/protocol-v2 (moved from drift-labs/protocol-v2, old URL redirects) , https://drift-labs.github.io/protocol-v2/sdk/
- What you get: perps/spot trading program plus a full-featured TS SDK (@drift-labs/sdk) covering order placement, JIT auctions, vAMM/DLOB liquidity, and account management.
- Chain/stack: solana+anchor, ts-sdk
- Audit status: audited - AUDIT.md in-repo links Neodyme and Trail of Bits protocol-v2 reports (hosted in the drift-labs/audits repo) (verified 2026-08-29)
- License: Apache-2.0 (permissive) (verified 2026-08-29)
- Maintenance: active - repo now lives under the velocity-exchange org (GitHub redirect from drift-labs/protocol-v2), 408 stars, last push 2026-07-08 (verified 2026-08-29)
- Fork vs import: import-as-dep - the TS SDK is the standard way to build a perps front-end or bot against Drift; fork the on-chain program only for a genuinely custom perps design
- Known pitfalls: perps SDK has a large surface area (oracle accounts, market accounts, user accounts) - expect a real ramp-up before first successful trade; JIT/DLOB liquidity behavior differs meaningfully from simple AMM swaps, test against devnet market data before mainnet.

### Kamino Finance klend-sdk - lending/borrowing SDK (also covers leveraged vaults)
- Repo/Docs: https://github.com/Kamino-Finance/klend-sdk , https://github.com/Kamino-Finance/audits
- What you get: TS SDK for Kamino Lending (klend) - deposit/borrow/repay, obligation management, and (via sibling kliquidity-sdk) automated CLMM vault strategies built on top of Orca/Raydium liquidity.
- Chain/stack: solana+anchor, ts-sdk
- Audit status: audited - dedicated audits repo with Sec3, Offside Labs, Certora, and OSEC formal-verification reports on file (strong audit trail)
- License: MIT declared in package.json (npm @kamino-finance/klend-sdk); note the repo carries no standalone LICENSE file (verified 2026-08-29)
- Maintenance: very active - npm v11.0.2 published 2026-08-27, repo last push 2026-08-24 (verified 2026-08-29)
- Fork vs import: import-as-dep - lending math (interest accrual, liquidation thresholds, obligation health) is high-risk to reimplement
- Known pitfalls: obligation/health-factor calculations are easy to get wrong in a UI - always source health/liquidation data from the SDK, never recompute independently; kliquidity vault strategies add an extra abstraction layer over the underlying AMM, adds latency to state reads.

### marginfi v2 / mrgn-ts - lending protocol SDK (client v2 package deprecated - use @0dotxyz/p0-ts-sdk)
- Repo/Docs: https://github.com/0dotxyz/marginfi-v2 (moved from mrgnlabs/marginfi-v2, old URL redirects) , https://github.com/0dotxyz/p0-ts-sdk , https://docs.0.xyz/docs/typescript-sdk/getting-started
- What you get: on-chain lending program plus TS SDK for deposits, borrows, and account health; mrgn-ts monorepo also has reference frontend apps.
- Chain/stack: solana+anchor, ts-sdk
- Audit status: audited - 13 reports in-repo `audits/`: OtterSec 2023, Sec3 (many rounds 2023-2026), Accretion 2025, Ackee full audit Jun 2026, Hashlock Jul 2026 (verified 2026-08-29)
- License: Apache-2.0 (marginfi-v2 program repo and mrgn-ts monorepo); successor SDK @0dotxyz/p0-ts-sdk is MIT (verified 2026-08-29)
- Maintenance: confirmed - @mrgnlabs/marginfi-client-v2 (latest 6.4.2) is deprecated on npm ("migrate to https://github.com/0dotxyz/p0-ts-sdk for continued support of the marginfi program"); marginfi is now Project 0 (0.xyz) and the current SDK is @0dotxyz/p0-ts-sdk v2.7.4, published 2026-08-28; program repo 0dotxyz/marginfi-v2 pushed 2026-08-28, mrgn-ts stale since 2026-06-03 (verified 2026-08-29)
- Fork vs import: import-as-dep via @0dotxyz/p0-ts-sdk (the currently maintained SDK) - read-for-reference on mrgn-ts frontend apps for UI patterns
- Known pitfalls: deprecated-but-still-published SDK package is a trap for new integrations - @mrgnlabs/marginfi-client-v2 still installs from npm but is unmaintained, use @0dotxyz/p0-ts-sdk (docs at docs.0.xyz); account health math has the same "don't recompute independently" caveat as other lending protocols.

### SPL Stake Pool - Solana Labs' standard liquid-staking pool program
- Repo/Docs: https://github.com/solana-program/stake-pool , https://spl.solana.com/stake-pool
- What you get: the canonical on-chain stake-pool program (JS + Python bindings) that most liquid-staking tokens (including Jito's JitoSOL and many others) are built on top of - deposit SOL/stake accounts, mint pool tokens, manage validator stake distribution.
- Chain/stack: solana, ts-sdk, python
- Audit status: audited - multiple firms on file (Quantstamp 2021, Neodyme 2021-2023 multiple rounds, Kudelski 2021, OtterSec 2023, Halborn 2023) via the security-audits repo, one of the most audited programs in this list
- License: Apache-2.0 (confirmed via repo, verified 2026-08-29)
- Maintenance: actively maintained under the solana-program org (successor to solana-labs/solana-program-library placement) - last push 2026-08-28 (verified 2026-08-29)
- Fork vs import: fork-and-adapt for building a new liquid-staking token (this is the standard base every LST forks); import-as-dep if just integrating with an existing pool
- Known pitfalls: stake-pool epoch-boundary update instructions (update validator list / update pool balance) must be called every epoch or deposits/withdrawals stall - budget an off-chain cranker/cron job; validator selection and commission changes are governed by a manager authority - understand the trust model before pointing users at a third-party pool.

### Marinade liquid-staking-program - production LST reference implementation (mSOL)
- Repo/Docs: https://github.com/marinade-finance/liquid-staking-program
- What you get: Anchor-based liquid staking program (first on Solana mainnet) plus mSOL<->SOL swap pool - a battle-tested reference distinct from the generic SPL stake pool.
- Chain/stack: solana+anchor
- Audit status: audited by Kudelski Security, Ackee Blockchain, and Neodyme (reports linked from marinade.finance docs)
- License: FLAG - proprietary non-commercial: LICENSE.md reads "Copyright Medium Rare Foundation. 2021. All rights reserved." with a limited license grant restricted to Non-Commercial Use, prominent-notice requirements that propagate to derivatives, and a clause requiring the developers' token fee distribution mechanism stay intact - not usable for commercial forks without separate permission (verified 2026-08-29)
- Maintenance: active - last push 2026-08-27, 131 stars, long-running production protocol (verified 2026-08-29)
- Fork vs import: read-for-reference primarily - this is best studied as the reference LST design (delayed unstake ticket accounts, validator scoring) rather than forked wholesale, since Marinade's specific tokenomics/governance are baked in
- Known pitfalls: mSOL's exchange rate accrues via an internal price oracle updated on a schedule - do not assume 1:1 with SOL anywhere in UI or accounting; instant-unstake liquidity pool has separate risk/fee parameters from the delayed-unstake path.

### Jito StakeNet - decentralized stake-pool manager built on SPL Stake Pool (JitoSOL infra)
- Repo/Docs: https://github.com/jito-foundation/stakenet , https://www.jito.wtf/stakers/
- What you get: Validator History and Steward on-chain programs that automate validator selection/scoring for a stake pool - the automation layer JitoSOL runs on top of the standard SPL Stake Pool program (not a separate pool program itself).
- Chain/stack: solana+anchor
- Audit status: audited - two reports in-repo `security-audits/`: jito_steward_audit.pdf and jito_validator_history_audit.pdf (audit firm not named in filenames; open the PDFs if the firm matters) (verified 2026-08-29)
- License: Apache-2.0 (confirmed via repo LICENSE, verified 2026-08-29)
- Maintenance: active, official jito-foundation org - last push 2026-08-17, 94 stars (verified 2026-08-29)
- Fork vs import: read-for-reference for the validator-scoring/steward automation pattern if building a managed stake pool; pair with SPL Stake Pool (above) as the actual token/pool program
- Known pitfalls: StakeNet is automation on top of SPL Stake Pool, not a standalone staking program - don't confuse it with a full LST implementation; validator scoring criteria (MEV commission, uptime, etc.) encode Jito-specific opinions that may not match your product's validator-selection needs.
