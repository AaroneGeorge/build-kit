---
title: Reuse Index - Consumer Sites with Light Contracts (Deposit / Escrow / Payout, Auction-Style)
description: Fork-first candidates for deposit/escrow/payout and auction/bidding Solana apps (outbid.lol-style) — programs, SDKs, and forkable frontends
applies_to: [solana]
sources:
  - "solana-foundation/program-examples - https://github.com/solana-foundation/program-examples (verified 2026-08-25)"
  - "coral-xyz/anchor (tests/escrow) - https://github.com/coral-xyz/anchor/tree/master/tests/escrow (verified 2026-08-25)"
  - "metaplex-foundation/metaplex-program-library - https://github.com/metaplex-foundation/metaplex-program-library (verified 2026-08-25)"
  - "streamflow-finance - https://github.com/streamflow-finance (verified 2026-08-25)"
  - "Squads-Protocol/smart-account-program - https://github.com/Squads-Protocol/smart-account-program (verified 2026-08-25)"
  - "solana-foundation/create-solana-dapp - https://github.com/solana-foundation/create-solana-dapp (verified 2026-08-25)"
  - "anza-xyz/wallet-adapter - https://github.com/anza-xyz/wallet-adapter (verified 2026-08-25)"
  - "heliofi/heliopay - https://github.com/heliofi/heliopay (verified 2026-08-25)"
  - "udbhav1/solana-auctionhouse - https://github.com/udbhav1/solana-auctionhouse (verified 2026-08-25, re-verify commit recency)"
last_verified: 2026-08-25
---

This is the flagship archetype: a Next.js frontend + a thin Solana program that holds native SOL or SPL tokens in a PDA vault while a deposit, escrow trade, auction bid, or payout resolves (the outbid.lol pattern — pay to hold/rank a slot, highest bid wins, refund the loser). Reuse posture: anything public is fair game — fork the program, import the SDK, or read the reference impl — but every entry below records license + audit status so you decide what to ship with, not this index. Prefer starting from `program-examples` + `create-solana-dapp` for the vault/PDA mechanics and wallet wiring, then layer in Auction House or a community auction program for real bid logic, and Streamflow/Squads for payout/vesting/treasury needs.

### solana-foundation/program-examples - canonical Anchor + native + Pinocchio program cookbook (escrow, transfer-sol, PDA rent)
- Repo/Docs: https://github.com/solana-foundation/program-examples
- What you get: minimal, single-purpose programs — `basics/transfer-sol`, `basics/pda-rent-payer`, `basics/escrow` (both Anchor and native variants) — that are the actual building blocks of a deposit/vault program: PDA-owned SOL vaults, rent-exempt PDA creation, checked lamport transfers, token-for-token escrow with cancel/exchange instructions.
- Chain/stack: solana+anchor (also native Rust and Pinocchio variants for several examples)
- Audit status: unaudited (teaching examples, not production-hardened)
- License: MIT
- Maintenance: ~1.4k stars, 600+ commits, actively updated by Solana Foundation devrel (formerly solana-developers org, renamed) (re-verify exact last-commit date)
- Fork vs import: fork-and-adapt — copy the closest example (escrow or transfer-sol) into your program and rename accounts/instructions rather than importing as a dependency
- Known pitfalls: examples intentionally skip production concerns (no fee handling, minimal validation of counterparty accounts, no reentrancy/close-account edge cases) — add checked-close-account and duplicate-bid guards yourself; native-Rust and Anchor variants live in different subfolders, don't mix account layouts between them

### Metaplex Auction House - decentralized, escrowless sale/bid protocol (the closest real "auction program" to fork)
- Repo/Docs: https://github.com/metaplex-foundation/metaplex-program-library (auction-house dir); docs at https://developers.metaplex.com/legacy-documentation/auction-house
- What you get: an on-chain Anchor program implementing bid/ask escrow accounts, trade-state PDAs, and a fee-payer/receipt model, plus a JS SDK (`@metaplex-foundation/mpl-auction-house`) — the closest production-grade reference for "hold a bid in escrow, release on match/settle, refund on outbid."
- Chain/stack: solana+anchor, ts-sdk
- Audit status: audited (Metaplex-commissioned audits published historically; re-verify current audit report links before mainnet use)
- License: Rust/Cargo programs are AGPLv3 (copyleft — flag before bundling into a closed-source stack); JS/TS client libs are MIT/Apache-2.0
- Maintenance: actively maintained under Metaplex Foundation org; last major updates ongoing (re-verify commit recency for auction-house subpackage specifically, it moves slower than core Token Metadata)
- Fork vs import: read-for-reference for the vault/trade-state pattern; import-as-dep (JS SDK) if you only need client-side calls against an existing deployed Auction House instance — fork-and-adapt the Rust program only if you accept AGPLv3 obligations
- Known pitfalls: AGPLv3 on the program itself is the big one — don't silently vendor it into a closed-source product; the "escrowless" design (NFT stays in seller wallet) is elegant for NFT marketplaces but is the wrong model for a pure highest-bid-wins deposit auction like outbid.lol, where you actually want funds/slot locked in a vault — treat this as a pattern reference more than a drop-in for that use case

### Streamflow Protocol - audited token streaming / vesting / payout rails (SDK-first, not open-source program)
- Repo/Docs: https://github.com/streamflow-finance (org), SDKs at streamflow-finance/js-sdk and streamflow-finance/rust-sdk; app at https://app.streamflow.finance/escrow
- What you get: a hosted, audited on-chain protocol for streaming/vesting payouts and conditional escrow (release-on-milestone), reached via SDK calls against Streamflow's deployed program — good fit for the "payout" half of deposit→resolve→payout flows (grants, milestone releases, timed refunds).
- Chain/stack: solana, ts-sdk + rust-sdk
- Audit status: audited by FYEO and OPCODES (cited by Streamflow; re-verify current report links)
- License: SDKs are Apache-2.0/MIT (open); the actual on-chain program is NOT open source — `streamflow-finance/streamflow-program` is explicitly marked deprecated/AGPL-3 legacy, current mainnet program is closed-source and only reachable via SDK
- Maintenance: active org with multiple maintained SDK repos (re-verify)
- Fork vs import: import-as-dep only — you cannot fork the live program, you call it through the SDK
- Known pitfalls: because the program is closed-source, you're trusting Streamflow's deployed instance rather than code you can audit yourself; SDK version churn between js-sdk major versions has broken integrations before — pin versions

### Squads smart-account-program (Squads Protocol v4) - multisig/smart-account treasury for payouts and shared vaults
- Repo/Docs: https://github.com/Squads-Protocol/smart-account-program ; TS SDK docs https://v4-sdk-typedoc.vercel.app/
- What you get: a battle-tested multisig/smart-account program (time locks, spending limits, roles, sub-accounts) — reuse this instead of hand-rolling a treasury/payout-approval flow for auction proceeds, escrow releases, or team payouts.
- Chain/stack: solana+anchor, ts-sdk
- Audit status: audited (multiple public audits cited by Squads; secures reported multi-billion-dollar TVL) — re-verify current audit report links
- License: AGPL-3.0 on the smart-account-program itself (copyleft — flag); some SDK/client packages under more permissive terms — check each package.json individually. (Note: predecessor `squads-mpl` v3 repo is archived as of Apr 2025 — use v4/smart-account-program, not squads-mpl, for new builds.)
- Maintenance: actively maintained, current flagship repo (re-verify last-commit date)
- Fork vs import: import-as-dep (deploy/point at Squads' program or their SDK) for treasury/multi-approver payout; fork-and-adapt only if you need custom logic and accept AGPL-3.0
- Known pitfalls: AGPL-3.0 copyleft again — same caution as Auction House; multisig account setup has nontrivial UX (member key management) that's overkill if you just need a single-owner payout PDA, don't reach for this unless you actually need multi-approver control

### coral-xyz/anchor tests/escrow - the canonical, minimal Anchor escrow reference (read this before writing your own)
- Repo/Docs: https://github.com/coral-xyz/anchor/tree/master/tests/escrow
- What you get: the reference Anchor escrow implementation (inspired by the well-known PaulX tutorial) bundled directly in the Anchor framework's own test suite — token-for-token escrow with init/cancel/exchange instructions and idiomatic Anchor account constraints (PDA seeds, `#[account(mut, close = ...)]`, CPI to SPL Token).
- Chain/stack: solana+anchor
- Audit status: unaudited (framework test fixture, not a shippable program)
- License: Apache-2.0 (Anchor framework license)
- Maintenance: lives inside the actively-maintained coral-xyz/anchor repo (core Solana tooling, high commit velocity) (re-verify)
- Fork vs import: read-for-reference — this is the pattern to study for correct PDA/CPI idioms, not something to import wholesale
- Known pitfalls: it's SPL-token-to-SPL-token escrow, not native-SOL vault logic — pair it with `program-examples/basics/transfer-sol` if your deposit/bid asset is native SOL

### create-solana-dapp - official scaffolding CLI for a forkable Next.js + wallet-adapter + Anchor frontend
- Repo/Docs: https://github.com/solana-foundation/create-solana-dapp
- What you get: `npm create solana-dapp@latest` — a maintained template generator producing a Next.js frontend pre-wired with `@solana/wallet-adapter`, an Anchor program skeleton, and common UI scaffolding (this is the current, actively-maintained successor to the older solana-labs/dapp-scaffold, which was archived Jan 2025 — don't start new work from dapp-scaffold).
- Chain/stack: next.js, solana+anchor, ts-sdk
- Audit status: n/a (tooling/scaffold, not a program holding funds)
- License: MIT
- Maintenance: 644 stars / 204 forks under solana-foundation org, actively maintained official tool (re-verify latest release)
- Fork vs import: fork-and-adapt — run the CLI once to generate your starting frontend, then build the deposit/auction UI on top
- Known pitfalls: template selection matters (counter/anchor templates differ) — pick the Anchor-integrated template, not a plain wallet-only one, or you'll rewire program bindings yourself; templates repo is separate from the CLI repo, so check the linked official-templates list for what's current

### @solana/wallet-adapter (anza-xyz/wallet-adapter) - the standard wallet-connect layer every consumer site needs
- Repo/Docs: https://github.com/anza-xyz/wallet-adapter
- What you get: the de facto standard modular TS wallet adapters + React UI components (`wallet-adapter-react`, `wallet-adapter-react-ui`) for connecting Phantom/Solflare/Backpack/etc — this is what create-solana-dapp wires in for you, but useful standalone if you're hand-building a frontend.
- Chain/stack: ts-sdk, next.js/react
- Audit status: n/a (client-side connection library, not a fund-custody program)
- License: Apache-2.0
- Maintenance: ~2,000 stars, 2,200+ commits; moved from solana-labs to anza-xyz org (current canonical home) — actively maintained (re-verify)
- Fork vs import: import-as-dep — install the npm packages directly, no reason to fork
- Known pitfalls: import from `anza-xyz/wallet-adapter` / the `@solana/wallet-adapter-*` npm scope, not the old `solana-labs` mirror which is stale; mobile wallet adapter (MWA) support for in-app browsers is a separate package, add it explicitly if you need mobile bidder support

### Helio (heliopay) - payment links / checkout embed for fiat-adjacent payout and deposit flows
- Repo/Docs: https://github.com/heliofi/heliopay ; sample app https://github.com/heliofi/sample-dev-app ; docs https://docs.hel.io/developers/detailed-api-schema
- What you get: a non-custodial checkout widget/SDK (`@heliofi/react`, embed button, API + webhooks) for accepting SOL/SPL/multi-chain payments with instant settlement — useful if your "deposit" step is really a payment-link checkout rather than a raw on-chain PDA vault (e.g., selling a slot/spot rather than running a pure auction).
- Chain/stack: ts-sdk, next.js/react (embed widget), multi-chain (Solana included)
- Audit status: unaudited/unknown for the SDK layer (re-verify) — Helio itself is a live production payments product processing real volume, but that isn't the same as a published contract audit
- License: mixed — `@heliofi/react` is MIT, the core `heliopay` package is AGPL-3.0-or-later (check each package's own license before vendoring)
- Maintenance: active org, multiple maintained packages (re-verify last commit)
- Fork vs import: import-as-dep (call their hosted API/embed) — this is a payments product, not a program you'd fork
- Known pitfalls: AGPL-3.0 on the core package again — fine for calling their hosted API, riskier if you vendor the package source into a closed frontend; it's a payment processor dependency (third-party hosted service), not a self-custodied vault — understand the custody model before treating it as equivalent to an on-chain escrow

### solana-auctionhouse (community) - open-ascending / sealed-bid auction program closest to an "outbid.lol on-chain" reference
- Repo/Docs: https://github.com/udbhav1/solana-auctionhouse (mirrored/forked as https://github.com/mooncitydev/solana-auctionhouse)
- What you get: a from-scratch auction protocol supporting open ascending (English), sealed first-price, and sealed second-price (Vickrey) auctions, with the item held in an escrowed SPL vault and bids escrowed in SOL, including cumulative outbidding logic — structurally the closest public reference to a "highest SOL bid wins, losers refunded" auction program.
- Chain/stack: solana+anchor
- Audit status: unaudited, community/hackathon-grade project — treat as reference code, not production-ready as-is
- License: unclear/unspecified in search results — re-verify the actual LICENSE file before any reuse beyond reading
- Maintenance: smaller community project, uncertain current activity level — (re-verify) commit recency and whether it's still maintained vs. a point-in-time hackathon snapshot
- Fork vs import: read-for-reference primarily; fork-and-adapt only after re-verifying license and doing your own security pass (no audit exists) — this is exactly the shape of program outbid.lol-style sites need, but it needs hardening (duplicate-bid races, auction-close timing, rent/close-account correctness) before holding real funds
- Known pitfalls: no audit and unclear license are the two blockers to just shipping this — budget time for a security pass on bid-cancellation and auction-settlement paths, which is where these hand-rolled auction programs most commonly have bugs (reentrancy on refund, incorrect PDA closing leaking rent, off-by-one on auction end slot/timestamp)
