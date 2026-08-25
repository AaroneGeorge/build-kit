---
title: Reuse Index - Launch & Mint
description: Bonding-curve launchpads, NFT/token mint programs, and vesting/presale contracts worth forking or importing instead of writing from scratch.
applies_to: [solana]
sources:
  - "MeteoraAg/dynamic-bonding-curve - https://github.com/MeteoraAg/dynamic-bonding-curve (verified 2026-08-25)"
  - "MeteoraAg/dynamic-bonding-curve-sdk - https://github.com/MeteoraAg/dynamic-bonding-curve-sdk (verified 2026-08-25)"
  - "MeteoraAg/alpha-vault-sdk - https://github.com/MeteoraAg/alpha-vault-sdk (verified 2026-08-25)"
  - "raydium-io/raydium-cpi - https://github.com/raydium-io/raydium-cpi (verified 2026-08-25)"
  - "code-423n4/2025-01-pump-science - https://github.com/code-423n4/2025-01-pump-science (verified 2026-08-25, contest snapshot)"
  - "metaplex-foundation/mpl-core-candy-machine - https://github.com/metaplex-foundation/mpl-core-candy-machine (verified 2026-08-25)"
  - "metaplex-foundation/mpl-core - https://github.com/metaplex-foundation/mpl-core (verified 2026-08-25)"
  - "metaplex-foundation/mpl-token-metadata - https://github.com/metaplex-foundation/mpl-token-metadata (verified 2026-08-25)"
  - "solana-program/token - https://github.com/solana-program/token (verified 2026-08-25)"
  - "streamflow-finance/js-sdk - https://github.com/streamflow-finance/js-sdk (verified 2026-08-25)"
  - "Bonfida/token-vesting - https://github.com/Bonfida/token-vesting (verified 2026-08-25, dormant)"
last_verified: 2026-08-25
---

Launch & mint covers three sub-problems that almost never need custom on-chain code anymore: bonding-curve price discovery (pump.fun-style and DEX-native), token/NFT minting, and vesting/presale distribution. Every serious Solana launch in 2026 composes these from existing, audited, mainnet-deployed programs rather than shipping a new AMM curve or mint program.
Reuse posture: anything public is fair game — ALWAYS record license + audit status so the builder decides, but do NOT block on it.

### Meteora Dynamic Bonding Curve (DBC) - configurable bonding-curve launchpad protocol
- Repo/Docs: https://github.com/MeteoraAg/dynamic-bonding-curve (program) · https://github.com/MeteoraAg/dynamic-bonding-curve-sdk (TS SDK) · https://docs.meteora.ag/integration/dynamic-bonding-curve-dbc-integration/launchpad-template
- What you get: a live mainnet program with fully customizable virtual bonding curves (linear/exponential), configurable fees, and automatic graduation into a Meteora DAMM pool at a set market cap — plus a TS SDK to create pools, quote, buy/sell, and migrate without touching Rust.
- Chain/stack: solana + anchor (program), ts-sdk (client)
- Audit status: audited — see code-423n4/2025-08-meteora contest report (https://github.com/code-423n4/2025-08-meteora); re-verify current report before mainnet use
- License: program repo ships `license.md` = **Non-commercial License** (FLAG); SDK repo (dynamic-bonding-curve-sdk) shows no LICENSE file in the tree (re-verify)
- Maintenance: program 97 stars/67 forks, 57 commits; SDK 41 stars/34 forks, 604 commits — both active orgs, frequent releases (re-verify exact last-commit date)
- Fork vs import: import-as-dep (use the SDK against the already-deployed mainnet program) — do NOT fork/redeploy the on-chain program itself given the non-commercial license on that repo
- Known pitfalls: (1) the non-commercial license applies to the *program source*, not to using the SDK against Meteora's live deployment — clarify with Meteora before any commercial fork/redeploy; (2) curve config accounts are immutable once a pool launches, get fee/curve params right pre-launch; (3) graduation to DAMM has its own pool-creation fees to budget for.

### Meteora Alpha Vault - anti-bot / anti-snipe vesting vault for pool bootstraps
- Repo/Docs: https://github.com/MeteoraAg/alpha-vault-sdk · https://docs.meteora.ag
- What you get: a vault program + SDK that lets early/whitelisted buyers lock in allocation before public trading opens, with configurable vesting release, deployed alongside DBC or DAMM pools to blunt sniper bots at launch.
- Chain/stack: solana + anchor (program), ts-sdk (client)
- Audit status: unaudited status not confirmed in this pass (re-verify) — check Meteora docs/audit page before relying on it for a large raise
- License: not visible in repo tree at fetch time (re-verify)
- Maintenance: 66 commits, active MeteoraAg org (re-verify exact last-commit date)
- Fork vs import: import-as-dep — pairs directly with DBC/DAMM pool creation, no reason to reimplement
- Known pitfalls: (1) vault config must be created before or atomically with the pool or it can't gate the first trades; (2) whitelist size and Merkle-proof format need to match your allowlist tooling exactly; (3) sparse public docs relative to DBC — expect to read SDK source for edge cases.

### Raydium LaunchLab - DEX-native bonding-curve launchpad with built-in Raydium migration
- Repo/Docs: https://github.com/raydium-io (org) · https://github.com/raydium-io/raydium-cpi (CPI adapter incl. `raydium-launch-cpi`) · https://docs.raydium.io/raydium/pool-creation/launchlab
- What you get: bonding-curve launch mechanics (linear/exponential/logarithmic curve choices) that graduate directly into a Raydium AMM/CPMM pool, plus a CPI crate so another Anchor program can call Launchpad instructions directly instead of only via off-chain SDK.
- Chain/stack: solana + anchor (program via CPI), ts-sdk (raydium-sdk-V2 has a `launchpad` module)
- Audit status: not confirmed in this pass — Raydium's docs point to the LICENSE file in each program repo as source of truth on terms; check for a published audit report before large launches (re-verify)
- License: Raydium's official docs state per-repo LICENSE files are authoritative and can change at the repo owner's discretion — historically Raydium core programs have used BUSL-style terms on some repos (FLAG, re-verify per-repo before relying on it)
- Maintenance: raydium-cpi at 38 stars, 24 commits; raydium-io org is a top-tier, actively shipping Solana DEX team (re-verify exact dates)
- Fork vs import: import-as-dep via SDK or CPI crate against the deployed mainnet program — same logic as DBC, don't attempt to redeploy Raydium's own program
- Known pitfalls: (1) license terms vary by repo and can be restrictive (BUSL-flavored) on core AMM code — read the specific LICENSE file for whichever repo you touch; (2) LaunchLab migration destination (which Raydium pool type) affects downstream LP mechanics; (3) CPI crate version must match the on-chain program's deployed IDL or CPI calls fail silently/error oddly.

### pump-science - audited pump.fun-style constant-product bonding-curve reference implementation
- Repo/Docs: https://github.com/code-423n4/2025-01-pump-science (Code4rena contest snapshot; SPEC.md has the curve math)
- What you get: a from-scratch Anchor implementation of the pump.fun constant-product (x*y=k) bonding curve — virtual reserves, buy/sell instructions, graduation threshold logic — that went through a public Code4rena audit contest in Jan 2025, unlike pump.fun itself which is closed-source.
- Chain/stack: solana + anchor
- Audit status: audited via Code4rena public contest (2025-01-pump-science) — read the contest findings report before adapting, several curve-math findings are typical in this class of code
- License: not stated in this pass (re-verify) — this is a contest-repo mirror, confirm the canonical org/license before using code verbatim, not just the audit snapshot
- Maintenance: contest repo is a point-in-time snapshot (by design, not "live" maintained) — treat as a reference implementation, not a dependency to track upstream (re-verify whether an actively maintained canonical repo now exists)
- Fork vs import: read-for-reference (and fork-and-adapt if building your own from-scratch curve rather than integrating an existing deployed protocol) — this is the best publicly-audited example of pump.fun-style curve math to copy logic from
- Known pitfalls: (1) it's a snapshot for an audit contest, not a maintained package — do not `npm install`/`cargo add` it as a live dependency; (2) constant-product curves are highly sensitive to integer overflow/rounding at extreme reserve ratios — the audit findings are the fastest way to learn where; (3) pump.fun-style clones are a popular scam vector (many unaudited "clones" on GitHub with backdoors) — this is the one worth trusting precisely because it has a public audit trail, don't substitute a random unaudited clone.

### Metaplex Core Candy Machine - primary NFT minting/distribution program (Core asset standard)
- Repo/Docs: https://github.com/metaplex-foundation/mpl-core-candy-machine · https://developers.metaplex.com/core-candy-machine
- What you get: a full on-chain "vending machine" mint program for Metaplex Core assets — guard system (allowlist, payment, bot-tax, start/end date, redemption limits), reveal mechanics, and TS/Rust clients.
- Chain/stack: solana + anchor (program), ts-sdk + rust client
- Audit status: unaudited/not confirmed for this specific Core version in this pass (re-verify); repo itself warns docs/readmes may be stale and the project is still described as experimental
- License: not explicitly surfaced in this pass, Metaplex programs are typically dual MIT/Apache-2.0-style — confirm per-repo LICENSE (re-verify)
- Maintenance: 121 commits, 38 stars/9 forks — smaller footprint than legacy mpl-candy-machine, actively developed by Metaplex Foundation (re-verify exact last-commit date)
- Fork vs import: import-as-dep (use the deployed program + client SDKs); fork only if you need a custom guard type the default guard set doesn't cover
- Known pitfalls: (1) repo explicitly warns its docs are stale — trust the test suite over the README for current usage; (2) Core is a newer, different asset standard from legacy Token Metadata NFTs — migration/compat tooling between the two is still maturing; (3) guard composition (which combination of guards is active) is easy to misconfigure and hard to change post-launch.

### Metaplex Core (mpl-core) - modern single-account NFT/digital-asset standard
- Repo/Docs: https://github.com/metaplex-foundation/mpl-core · program id `CoREENxT6tW1HoK8ypY1SxRMZTcVPm7R94rH4PZNhX7d`
- What you get: the underlying asset program Core Candy Machine mints against — single-account NFTs (cheaper than legacy Token Metadata's multi-account model), plugin system for royalties/freeze/attributes, JS + Rust clients.
- Chain/stack: solana + anchor (program), ts-sdk + rust client
- Audit status: audited by Mad Shield, completed 2024-05-03 — re-verify no material changes shipped since without a follow-up audit
- License: MIT
- Maintenance: 709 commits, 102 stars/58 forks, 15 watchers — actively developed by Metaplex Foundation (re-verify exact last-commit date; star count in some search indexes is inflated/wrong, 102 is the figure read directly off the repo page)
- Fork vs import: import-as-dep — this is the standard NFT primitive on Solana going forward, no reason to roll your own mint account layout
- Known pitfalls: (1) plugin system is powerful but each plugin adds account size/rent — budget accordingly; (2) if the collection needs cross-marketplace royalty enforcement, verify current marketplace support for Core plugins vs. legacy Token Metadata; (3) migrating an existing legacy NFT collection to Core is a distinct, separate flow from minting new Core assets.

### mpl-token-metadata + SPL Token / Token-2022 - legacy NFT metadata standard and fungible token program
- Repo/Docs: https://github.com/metaplex-foundation/mpl-token-metadata · https://github.com/solana-program/token (SPL Token, successor to solana-labs/solana-program-library's token module) · https://github.com/solana-program/token-2022 (extensions: transfer fees, metadata-in-mint, etc.)
- What you get: the program that attaches name/symbol/URI/creator/royalty metadata to any SPL mint (still the dominant standard for fungible token launches and much of the existing NFT market), plus the base SPL Token / Token-2022 programs every mint ultimately rides on.
- Chain/stack: solana (native + anchor-compatible), ts-sdk + rust clients
- Audit status: both are foundational, heavily-used, historically audited Solana primitives (specific current audit report not re-confirmed in this pass, re-verify); de facto the most battle-tested code in this whole list by transaction volume
- License: mpl-token-metadata — Rust/program code under Metaplex's Apache-style NFT open-source license, JS/TS clients dual MIT/Apache-2.0; SPL Token / Token-2022 — Apache-2.0
- Maintenance: mpl-token-metadata 707 commits/253 stars; solana-program/token 462 commits/188 stars — both actively maintained by their respective foundations (re-verify exact last-commit dates)
- Fork vs import: import-as-dep, always — these are the base primitives, never fork
- Known pitfalls: (1) SPL Token program moved orgs from solana-labs/solana-program-library to solana-program/token — make sure tooling/docs you copy reference the current org, not a stale fork; (2) Token-2022 extensions (transfer fee, transfer hook, metadata-in-mint) are NOT drop-in compatible with plain SPL Token — many DEXs/wallets lag on extension support, check before choosing Token-2022 for a launch; (3) mpl-token-metadata is being superseded by mpl-core for new NFT projects — only reach for it if you need compatibility with legacy NFT tooling/marketplaces.

### Streamflow - token vesting, streaming payments, and airdrop distribution protocol
- Repo/Docs: https://github.com/streamflow-finance/js-sdk (TS SDK) · https://github.com/streamflow-finance (org, incl. rust-sdk) · https://streamflow.finance/vesting
- What you get: a live mainnet protocol + SDK for linear/cliff vesting schedules, streaming payments (payroll-style), and mass airdrop distribution — the standard choice for team/investor token vesting and presale unlock schedules.
- Chain/stack: solana + anchor (program), ts-sdk + rust-sdk (client)
- Audit status: audited — Streamflow's site states a protocol security audit has passed; get the current audit report link before relying on it for a large token unlock schedule (re-verify)
- License: GPL-3.0 on js-sdk (FLAG copyleft — check implications before bundling into a closed-source app; a separate client/SDK-only usage is generally lower risk than modifying and redistributing the program itself)
- Maintenance: 712 commits, 165 stars — actively maintained, in active commercial use as a hosted product (re-verify exact last-commit date); note the older `timelock-crate` repo is deprecated/archived, use js-sdk/rust-sdk instead
- Fork vs import: import-as-dep — use the SDK against the deployed protocol rather than forking; GPL-3.0 makes forking-and-redistributing the program itself the higher-friction path anyway
- Known pitfalls: (1) GPL-3.0 on the JS SDK is a real license constraint for a closed-source frontend — confirm whether SDK usage (vs. modifying/redistributing SDK source) triggers copyleft obligations for your specific packaging; (2) the older `streamflow-program`/`timelock-crate` repos are explicitly deprecated — don't build against them; (3) vesting contract cancellation/transfer permissions need to be set correctly at creation, they're not universally changeable after the fact.

### Bonfida token-vesting - minimal audited SPL vesting contract (reference / fallback)
- Repo/Docs: https://github.com/Bonfida/token-vesting
- What you get: a simple, single-purpose vesting contract (SVC) — deposit SPL tokens, unlock to a pubkey at a given slot, permissionless crank to move tokens — plus JS bindings and a CLI; much smaller surface area than Streamflow if you only need basic cliff/linear unlocks.
- Chain/stack: solana (native, not anchor), ts client
- Audit status: audited by Kudelski
- License: LICENSE file present, type not surfaced in this pass (re-verify)
- Maintenance: 284 stars/184 forks but flagged not actively maintained — treat as **dormant** (re-verify before depending on it for a live launch)
- Fork vs import: read-for-reference primarily; fork-and-adapt only if Streamflow's GPL-3.0/complexity is a dealbreaker and you want the smallest possible audited vesting primitive to vendor in
- Known pitfalls: (1) dormant repo — no recent maintenance signal, so any Solana runtime/CPI changes since audit aren't guaranteed to be handled; (2) native Solana program (not Anchor) so integration ergonomics differ from the rest of this list; (3) permissionless crank model means someone (possibly the recipient) must trigger unlocks — make sure your frontend/bot actually cranks it, tokens don't move automatically.
