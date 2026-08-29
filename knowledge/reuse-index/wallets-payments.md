---
title: Reuse Index - Wallets & Payments
description: Smart wallets, account abstraction, embedded wallets, escrow, and payment/streaming rails for Solana (+ EVM embedded-wallet SDKs)
applies_to: [solana, evm]
sources:
  - "Squads Protocol v4 - https://github.com/Squads-Protocol/v4 (verified 2026-08-29)"
  - "Solana Pay - https://github.com/solana-foundation/solana-pay (verified 2026-08-29)"
  - "Streamflow js-sdk - https://github.com/streamflow-finance/js-sdk (verified 2026-08-29)"
  - "Octane - https://github.com/anza-xyz/octane (verified 2026-08-29)"
  - "Privy react-auth - https://www.npmjs.com/package/@privy-io/react-auth (verified 2026-08-29)"
  - "Turnkey sdk - https://github.com/tkhq/sdk (verified 2026-08-29)"
  - "Web3Auth web3auth-web - https://github.com/Web3Auth/web3auth-web (verified 2026-08-29)"
  - "Helio heliopay - https://github.com/heliofi/heliopay (verified 2026-08-29)"
  - "solana-foundation/escrow - https://github.com/solana-foundation/escrow (verified 2026-08-29)"
last_verified: 2026-08-29
---

Archetype: on-chain smart accounts (multisig/AA), payment rails (point-of-sale + streaming/vesting), gasless relaying, and embedded-wallet infra for onboarding non-crypto-native users. Most of the hard, security-critical primitives here (multisig custody, gasless relay signing, key management) are ones you should import or fork from an audited party rather than hand-roll on a ship-fast timeline.
Reuse posture: anything public is fair game — always record license + audit status so the builder decides, do not block on it. Several entries below carry copyleft (GPL/AGPL) or source-available (BUSL) licenses on the on-chain program; that's fine to fork-and-read but check before bundling into a closed product.

### Squads Protocol v4 - the de facto Solana smart account / multisig standard
- Repo/Docs: https://github.com/Squads-Protocol/v4 , https://v4-sdk-typedoc.vercel.app/ (TS SDK docs)
- What you get: on-chain multisig/smart-account program (`squads_multisig_program`, deployed mainnet `SQDS4ep65T869zMMBKyuUq6aD6EgTu8psMjkvj52pCf`) + `@sqds/multisig` TS SDK + `squads-multisig` Rust crate. Supports time locks, spending limits, roles, sub-accounts, batched multi-party payments, ALT support.
- Chain/stack: solana+anchor, ts-sdk
- Audit status: audited by OtterSec, Neodyme, Certora, and Trail of Bits (2023 & 2024)
- License: AGPL-3.0 on current main (sole LICENSE file in repo; relicensed from BUSL-1.1 on 2024-10-11) — COPYLEFT, FLAG for closed-source bundling; commits before Oct 2024 carry BUSL-1.1, so check the LICENSE at the exact commit you pin (verified 2026-08-29)
- Maintenance: active — 195 stars, 102 forks, last commit 2026-08-20; deployed and actively used on mainnet (verified 2026-08-29)
- Fork vs import: import-as-dep (use the deployed program + `@sqds/multisig` SDK to create/manage a vault) rather than fork — this is exactly the kind of security-critical custody logic you don't want to re-audit yourself
- Known pitfalls: AGPL-3.0 copyleft (BUSL-1.1 on pre-Oct-2024 commits) can block commercial closed-source use of the *program source* itself (using the already-deployed mainnet program via SDK sidesteps this); vault PDA derivation and proposal/threshold flows have a learning curve — budget time to read the TS SDK docs before wiring up a UI.

### Solana Pay - the standard point-of-sale / payment-link protocol
- Repo/Docs: https://github.com/solana-foundation/solana-pay , https://solana.com/docs/tools/solana-pay
- What you get: transaction-request URL spec + `@solana/pay` JS/TS SDK for generating payment URLs/QR codes and parsing/validating incoming payments (native SOL + SPL tokens)
- Chain/stack: solana, ts-sdk
- Audit status: unaudited (it's a thin client library around standard SPL transfers, not a custody program — low audit surface)
- License: MIT (LICENSE file in repo — earlier note of Apache-2.0 was wrong; verified 2026-08-29)
- Maintenance: active — 1,765 stars, last commit 2026-08-28, under the solana-foundation org (successor to the original solana-labs repo); Solana's official commerce payment standard (verified 2026-08-29)
- Fork vs import: import-as-dep — this is the fastest path to "scan QR, get paid" and is what wallets (Phantom, Solflare) already recognize
- Known pitfalls: reference-based payment tracking (for POS use cases needing a unique per-order reference) requires you to index/poll for the reference account yourself — Solana Pay gives you the URL spec, not a backend; make sure amount/mint/recipient validation happens server-side, not just client-side QR generation.

### Streamflow - token streaming, vesting, and payroll automation
- Repo/Docs: https://github.com/streamflow-finance (org), https://github.com/streamflow-finance/js-sdk , https://docs.streamflow.finance
- What you get: on-chain stream/vesting program + JS/Rust SDKs (`@streamflow/stream`, `@streamflow/distributor`) to create, top-up, withdraw, cancel, and transfer continuous-release SPL token streams — covers payroll, vesting cliffs, and airdrop distribution in one primitive
- Chain/stack: solana+anchor, ts-sdk
- Audit status: audited by FYEO and OPCODES for Solana (per https://docs.streamflow.finance/en/articles/9338573-has-streamflow-been-audited); FLAG: report PDFs are not linked from that page — request them before relying on it for large-value custody (verified 2026-08-29)
- License: GPL-3.0 on the js-sdk — COPYLEFT, FLAG before bundling into a closed-source product; check the on-chain program repo separately as license can differ per-repo
- Maintenance: active — js-sdk last commit 2026-07-29 (`@streamflow/stream` v13.3.1 published same day), rust-sdk last commit 2026-08-27 (verified 2026-08-29)
- Fork vs import: import-as-dep (call the deployed program via SDK) for a payroll/vesting feature; read-for-reference if you specifically need a from-scratch, permissively-licensed streaming-payment program
- Known pitfalls: GPL-3.0 on the SDK can be viral if you statically link/vendor it into a closed-source frontend — using it as an unmodified npm dependency at arm's length is the safer pattern; streaming math (rate, cliff, cancelable-by-whom) has edge cases around clawback — read the withdraw/cancel authority model before trusting it with real payroll.

### Octane - gasless relayer (users pay fees in SPL tokens, not SOL)
- Repo/Docs: https://github.com/anza-xyz/octane (moved from solana-labs/octane), docs at `docs/library.md` and `SETUP.md` in-repo
- What you get: an HTTP API server (deployable free on Vercel as serverless Node functions) that accepts signed transactions, validates them against configurable rules, co-signs/pays the fee, and broadcasts — lets you build SOL-less onboarding where new users pay gas in USDC/SPL instead of SOL
- Chain/stack: solana, ts (node/serverless)
- Audit status: unaudited — this is a reference relayer, not a hardened production service; treat it as a starting point
- License: Apache-2.0 (verified 2026-08-29)
- Maintenance: FLAG — repo is ARCHIVED (read-only) under anza-xyz: final commit 2026-04-20 added an archival notice to the README, last substantive commits Dec 2023; 265 stars, 173 forks; treat as unmaintained reference code to fork, not a dependency (verified 2026-08-29)
- Fork vs import: fork-and-adapt — you will almost certainly need to customize the fee-payer allowlist/rate-limiting rules for your own abuse model, this isn't a drop-in hosted service
- Known pitfalls: the default validation rules are permissive examples, not production-ready anti-abuse — you must add your own transaction allowlisting/rate-limits or the relayer becomes a free-transaction drain; running it means your fee-payer keypair custody becomes your problem (treat like a hot wallet).

### Privy - embedded wallets + auth (email/social login → wallet)
- Repo/Docs: https://docs.privy.io/ , npm `@privy-io/react-auth` / `@privy-io/js-sdk-core` (client SDKs: React, React Native, Swift, Android, Unity, Node, Go, Python + REST API)
- What you get: hosted embedded-wallet infra (progressive auth: email/social → auto-created wallet, later upgradeable to self-custody/export) + server wallets; supports Solana and EVM
- Chain/stack: solana, evm, ts-sdk, next.js
- Audit status: N/A (hosted service, not an on-chain program) — Privy was acquired by Stripe (June 2025), which raises the bar on custodial trust but is also a lock-in/pricing consideration
- License: `@privy-io/react-auth` SDK is Apache-2.0 (npm license field; verified 2026-08-29); the backend service itself is closed-source/hosted (not something you fork)
- Maintenance: actively released — `@privy-io/react-auth` latest is v3.38.0, published 2026-08-25; large integration-example footprint on GitHub (verified 2026-08-29)
- Fork vs import: import-as-dep — this is a hosted product, not a fork target; fastest path to "no seed phrase" onboarding for non-crypto users
- Known pitfalls: vendor lock-in and per-MAU pricing kick in past free tier; embedded-wallet key-share custody model means you're trusting Privy's MPC infra — read their key-export flow before promising users "self-custody" in your own marketing.

### Turnkey - raw key-management / signing infra (build-your-own wallet UX)
- Repo/Docs: https://github.com/tkhq/sdk (TypeScript SDK), packages `@turnkey/sdk-browser`, `@turnkey/sdk-server`, `@turnkey/react-wallet-kit`; 40+ example repos across auth patterns, chain-specific signing, and account-abstraction setups
- What you get: lower-level than Privy/Dynamic — policy-gated signing API + secure enclave key management, with a higher-level `react-wallet-kit` for faster integration when you don't need full custom control
- Chain/stack: solana, evm, ts-sdk, go, swift, kotlin, python, ruby
- Audit status: N/A on-chain; hosted signer — turnkey.com states "SOC 2 Type II audited" and lists security audits by Distrust, Cure53, Trail of Bits, and Zellic; TEE/secure-enclave (QuorumOS) model documented at whitepaper.turnkey.com (verified 2026-08-29)
- License: Apache-2.0 across the SDK packages (tkhq/sdk repo license; verified 2026-08-29)
- Maintenance: active — tkhq/sdk last commit 2026-08-27; dedicated `tkhq` org with SDK, Go SDK, Kotlin SDK, and a growing examples repo (verified 2026-08-29)
- Fork vs import: import-as-dep for the SDK/API; use `@turnkey/react-wallet-kit` if you want Privy/Dynamic-like speed, or the raw `@turnkey/core` client if you need custom policy/session control
- Known pitfalls: more assembly required than Privy/Dynamic if you go the low-level route — budget extra integration time; policy engine (who can sign what, under what conditions) is powerful but has a learning curve worth reading before wiring up sensitive flows.

### Web3Auth - open-source-friendly embedded wallet / social-login SDK
- Repo/Docs: https://github.com/Web3Auth/web3auth-web (+ web3auth-android-sdk, web3auth-swift-sdk, web3auth-unity-sdk)
- What you get: non-custodial key infra using MPC/threshold key-splitting behind familiar social/email logins; multi-chain including Solana
- Chain/stack: solana, evm, ts-sdk
- Audit status: N/A (client-side key-management SDK; check current security whitepaper for MPC threshold model claims)
- License: FLAG — NOT MIT: web3auth-web's LICENSE is a proprietary Torus Labs grant permitting Non-Commercial Use only (personal/charity/edu, or under 1,000 MAU across all versions); commercial use above that requires a Web3Auth agreement; `@web3auth/modal` on npm declares no license field (verified 2026-08-29)
- Maintenance: active — web3auth-web last commit 2026-08-25 (`@web3auth/modal` latest v11.4.0, npm activity 2026-08-17); Android SDK latest release v10.0.1 (2026-04-10); multi-platform cadence suggests a real maintenance team (verified 2026-08-29)
- Fork vs import: import-as-dep — most mature of the "non-custodial-by-design" embedded wallet options if you want to avoid a fully custodial provider
- Known pitfalls: free tier has MAU limits and the self-hosted/OSS path (running your own key-management nodes) is materially more setup work than the hosted SaaS tier — decide up front which tier you're building against.

### Helio - Solana-native payment links/checkout embed (Shopify-adjacent)
- Repo/Docs: https://github.com/heliofi , https://github.com/heliofi/heliopay , npm `@heliofi/react`
- What you get: paylinks, checkout embeds (React widget), and payment streams for accepting crypto payments as a merchant; positioned as Solana's payment solution for commerce platforms (Shopify integration)
- Chain/stack: solana, react
- Audit status: unaudited / N/A (payment-processing service, not a custody program)
- License: no root LICENSE file in `heliopay`; package.json declares AGPL-3.0-or-later on the solana/evm/nft adapter packages (COPYLEFT, FLAG) and ISC on the `sdk` package; `@heliofi/react` on npm is MIT (verified 2026-08-29)
- Maintenance: moderate — `heliopay` last commit 2026-07-10; other 2026 org activity: x402-client-sdk (Mar), docs (Feb); FLAG: `@heliofi/react` latest npm publish is a 4.0.13-alpha.0 pre-release, so cadence is slower than the hosted product suggests (verified 2026-08-29)
- Fork vs import: import-as-dep for the MIT-licensed `@heliofi/react` checkout widget; read-for-reference (not import) on `heliopay` core given the AGPL license if you're building closed-source
- Known pitfalls: AGPL on the core repo means self-hosting/modifying it likely triggers copyleft obligations — stick to the hosted API + MIT React embed unless you intend to open-source your fork.

### solana-foundation/escrow - minimal reference escrow program (read-for-reference)
- Repo/Docs: https://github.com/solana-foundation/escrow ; sibling: `tokens/escrow/anchor` inside https://github.com/solana-developers/program-examples
- What you get: a configurable, receipt-based escrow pattern (admin creates escrow, allowlists mints, users deposit/withdraw against receipts) — the canonical "how do I hold funds in a PDA safely" reference for building custom payment-escrow logic (marketplace holds, milestone payments, deal escrow) that Squads/Streamflow don't cover
- Chain/stack: solana+anchor
- Audit status: unaudited — explicitly an educational/reference implementation, not production-hardened
- License: MIT (LICENSE file in repo — earlier note of Apache-2.0 was wrong; repo active, last commit 2026-08-17; verified 2026-08-29)
- Fork vs import: read-for-reference / fork-and-adapt — this is exactly the kind of small, well-understood primitive you're expected to fork and harden yourself rather than depend on as an external program, since your specific escrow-release conditions (arbiter, timeout, dispute) are always custom
- Known pitfalls: reference implementations skip production concerns (reentrancy-style ordering with CPI, close-account rent-recovery edge cases, decimal/mint-authority checks) — do not deploy the tutorial code unmodified for real funds; treat it as a correct skeleton to extend and get reviewed.
