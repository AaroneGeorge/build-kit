---
title: Recipe - Launch & Mint
description: Ship a bonding-curve launchpad, NFT/token mint, or vesting/presale distribution in ~6 hours by composing audited, already-deployed protocols instead of writing curve math or a mint program from scratch
applies_to: [solana]
sources:
  - "../reuse-index/launch-mint.md (sibling reuse index - full candidate list, licenses, audit status)"
  - "Meteora Dynamic Bonding Curve - https://github.com/MeteoraAg/dynamic-bonding-curve , https://github.com/MeteoraAg/dynamic-bonding-curve-sdk , https://docs.meteora.ag/integration/dynamic-bonding-curve-dbc-integration/launchpad-template"
  - "Meteora Alpha Vault - https://github.com/MeteoraAg/alpha-vault-sdk"
  - "Raydium LaunchLab - https://github.com/raydium-io/raydium-cpi , https://docs.raydium.io/raydium/pool-creation/launchlab"
  - "pump-science (audited reference curve) - https://github.com/code-423n4/2025-01-pump-science"
  - "Metaplex Core Candy Machine - https://github.com/metaplex-foundation/mpl-core-candy-machine , https://developers.metaplex.com/core-candy-machine"
  - "Metaplex Core - https://github.com/metaplex-foundation/mpl-core"
  - "mpl-token-metadata / SPL Token - https://github.com/metaplex-foundation/mpl-token-metadata , https://github.com/solana-program/token"
  - "Streamflow js-sdk - https://github.com/streamflow-finance/js-sdk"
  - "Bonfida token-vesting (dormant fallback) - https://github.com/Bonfida/token-vesting"
  - "../testing/per-archetype-tests.md (link - section 3, Launch / mint / bonding-curve)"
  - "../latency/*.md (link - may not exist yet)"
  - "../solana/tx-landing.md"
last_verified: 2026-08-25
---

## TL;DR - the 6-hour spine

Launch & mint splits into two shapes: **token launch** (bonding curve → DEX graduation) and **NFT/asset mint**. Vesting is a bolt-on to either. Pick the shape in the first 30 minutes — do not hand-roll curve math or a mint account layout on a 6h clock; every piece below is a live, deployed program with a client SDK.

1. **Pick the shape.** Fungible token with price discovery → bonding curve path (step 2). NFT/digital collectible drop → mint path (step 3). Team/investor/presale unlock schedule on either → vesting bolt-on (step 4).
2. **Token launch: fork/import Meteora Dynamic Bonding Curve (DBC).** Use `dynamic-bonding-curve-sdk` against the deployed mainnet program to create a pool with your curve shape (linear/exponential), fees, and graduation market cap — do not deploy your own curve program. If the brief specifically wants Raydium as the graduation venue, swap in Raydium LaunchLab's SDK/CPI crate instead; same integration shape, different destination pool. Read `pump-science`'s SPEC.md first regardless of which you pick — it's the fastest way to understand curve math and where the integer-overflow/rounding landmines are, even though you're not deploying it.
3. **NFT/asset mint: fork/import Metaplex Core Candy Machine.** Mint against `mpl-core` assets (not legacy Token Metadata, unless the brief needs legacy-marketplace compat — then use `mpl-token-metadata` + SPL Token instead). Configure the guard set (allowlist, payment, start/end date, redemption limit, bot-tax) rather than writing your own gating logic.
4. **Vesting/presale bolt-on: import Streamflow (`@streamflow/stream`).** Create vesting contracts for team/investor allocations or presale unlocks against the deployed protocol. Fall back to Bonfida token-vesting only if Streamflow's GPL-3.0 SDK license is a hard blocker for your packaging (see Keep/Change/Cut) — it is dormant, treat it as a last resort.
5. **Anti-snipe (token launches only, if in scope):** pair DBC or LaunchLab with Meteora Alpha Vault to gate early allocation behind a vesting release before public trading opens. Create the vault config before or atomically with the pool — it cannot retroactively gate the first trades.
6. **Wire the client.** wallet-adapter for connect/sign; all curve/mint/vault state reads come from the SDKs' account-fetch methods, not a database you treat as source of truth. Your backend/indexer is a cache of on-chain state, never the authority on balances or allocation.
7. **Build the "launch" as a config, not code.** Curve params, guard set, and vesting schedule should be data you can review and freeze pre-launch — most of the dangerous mistakes in this archetype are wrong config committed on-chain, not wrong logic.
8. **Devnet demo end-to-end before touching mainnet** (see Deploy section): create pool/candy machine → buy/mint from a second wallet → (if vesting in scope) confirm a vested tranche unlocks/cranks correctly → graduation or sold-out path.

## Keep / Change / Cut

| Component | Reuse as-is | Modify | Drop |
|---|---|---|---|
| Bonding-curve math (constant-product / virtual reserves) | Meteora DBC or Raydium LaunchLab deployed program via SDK | Curve shape, fee tiers, graduation market cap (config only) | Writing your own curve program — use `pump-science` only to *read* the math, not as a live dependency |
| DEX graduation / migration pool | DBC → Meteora DAMM, LaunchLab → Raydium AMM/CPMM (both automatic) | Which pool type LaunchLab migrates into | Building a custom migration/LP-seeding flow |
| Anti-bot / anti-snipe allocation gating | Meteora Alpha Vault SDK | Whitelist size, Merkle-proof format, vesting release curve | Writing your own snipe-resistant allocation logic |
| NFT/asset mint account layout | `mpl-core` (new projects) or `mpl-token-metadata` (legacy-compat only) | Plugin selection (Core) or creator/royalty fields (legacy) | Rolling a custom mint/metadata account layout |
| Mint distribution / guard logic | Metaplex Core Candy Machine guard system | Guard combination (allowlist, payment, bot-tax, dates, limits) | Writing custom gating/reveal logic the default guards already cover |
| Fungible token base program | SPL Token (or Token-2022 only if you specifically need an extension) | — | Choosing Token-2022 without checking wallet/DEX extension support first |
| Vesting / presale unlock schedule | Streamflow deployed protocol via `@streamflow/stream` | Cliff/linear rate, cancel/transfer authority (set at creation) | Writing release-math yourself; do not build against deprecated `timelock-crate` |
| Vesting fallback (license-constrained only) | Bonfida token-vesting (dormant) as reference/fork base | Everything — it's minimal by design, expect to extend it | Depending on it for a live launch without re-verifying it against current runtime |
| Wallet connect/sign UX | wallet-adapter | — | Rolling your own signing UI |

## The 3 dangerous parts

1. **Mint/freeze authority left live after launch completes.** Whether it's an SPL fungible mint feeding a bonding curve or an NFT collection, a mint authority that's still active after the intended supply is fixed is a rug vector — an admin can mint more supply or freeze holder accounts after the fact, invisible in casual manual testing. Guardrail: after the curve completes (or the mint's fixed supply is reached), read the mint account directly on-chain and assert `mintAuthority` and `freezeAuthority` are `None`/revoked; assert any residual "admin mint" instruction errors when called. Do this as an automated check, not a manual glance at a dashboard.
2. **Curve/guard config is effectively immutable once live, and wrong config is a funds-loss or fairness bug, not a cosmetic one.** DBC/LaunchLab curve accounts and Candy Machine guard sets are set at pool/machine creation and are expensive-to-impossible to change after buyers/minters interact with them. Getting fee tiers, graduation market cap, or guard combination wrong post-launch either strands funds in a mispriced curve or lets a bot bypass your allowlist. Guardrail: treat curve params and guard config as a reviewed, frozen artifact before deploy — write them to a config file, diff-review it like code, and re-derive the on-chain values from a fresh read (not your local copy) immediately after creation to confirm what's actually live matches what you intended.
3. **Anti-snipe / allocation-fairness bypass via wallet-splitting or a vault created too late.** A single buyer using multiple wallets/ATAs to exceed a per-wallet cap, or an Alpha Vault config created *after* the pool instead of atomically with it, both defeat the fairness mechanism the whole feature exists for — and neither failure shows up in a 2-3 point manual test pass. Guardrail: test the multi-wallet-same-buyer bypass path explicitly (see Minimum Tests #4 below); sequence vault-then-pool (or a single atomic transaction creating both) so there is no window where public buys can land before the gate is active.

## Minimum tests - the 5 non-negotiables

See `../testing/per-archetype-tests.md` (section 3, "Launch / mint / bonding-curve") for the full checklist and rationale. At minimum:
1. **Curve monotonicity / no negative or zero-cost buy** across the full supply range of your configured curve — the most common launchpad bug and invisible in manual spot-checks.
2. **Graduation/migration triggers correctly** at the configured market cap and lands the pool on the intended destination (Meteora DAMM or Raydium AMM/CPMM) — test at, just-below, and just-above the threshold.
3. **`mint-authority-revoked-post-launch`** — after full mint or curve completion, read the mint account directly and assert mint + freeze authority are `None`; assert a residual admin-mint call errors.
4. **Per-wallet allocation cap actually holds** against a multi-ATA/multi-wallet bypass attempt from a single controlling buyer — the standard launch-fairness bug.
5. **Vesting release path tested for every authority branch** (recipient claim, sender cancel/clawback if configured, cliff-then-linear timing) — not just the happy-path claim after full unlock.

## Deploy

- **Devnet/demo-first, always.** Stand up pool/candy-machine creation, a buy/mint from a second wallet, and (if in scope) one vesting create + one claim, entirely on devnet before any mainnet key is involved.
- **Key handling:** curve/pool creation authority, candy machine update authority, and any deploy keys live in env vars or OS keychain — never committed, never shipped in a client bundle. If launch authority should be shared/multisig-governed (common for team allocations or an update authority you don't want as a single point of failure), consider routing it through a Squads vault rather than a single hot key (see `wallets-payments.md`).
- **Program verify:** you are not deploying DBC/LaunchLab/Candy Machine/Streamflow programs yourself — nothing to `anchor verify` there. If you *did* fork anything (e.g., adapting `pump-science` or Bonfida token-vesting into your own deployed program), run `anchor verify` / `solana-verify` against the published source before mainnet.
- **Upgrade authority:** for any program you deploy yourself, decide before mainnet whether upgrade authority stays with a single deploy key or moves to a multisig — the safer default for anything backing real value is moving it to a multisig before public launch.
- **Mainnet is LATER and gated, never automatic.** Explicit human go/no-go checkpoint after the devnet demo passes and the 5 minimum tests are green: re-verify current audit status for whichever protocol you're using (DBC has a public contest report, Core is Mad Shield-audited, pump-science is a Code4rena snapshot — not a live audit of your integration), re-verify license posture (DBC program repo's non-commercial license, Streamflow's GPL-3.0 SDK, Raydium's per-repo BUSL-flavored terms — see reuse index for details) fits your distribution model, then confirm mint/freeze authority revocation and curve/guard config are exactly what was reviewed before pool/machine creation goes live with real funds.

## Latency notes

- See `../latency/*.md` (link — may not exist yet) and `../solana/tx-landing.md` for general RPC/landing guidance.
- Bonding-curve buys are latency-sensitive by nature (price moves every block/slot as reserves shift) — use priority fees and retry-with-backoff from `tx-landing.md` on the buy/sell instruction path, and quote price client-side immediately before submit to reduce user-visible slippage surprises, but always enforce a slippage/min-out check on-chain, never trust the client quote alone.
- Candy Machine mint bursts (a popular drop's mint-open moment) are a landing-rate spike — expect priority-fee contention at mint-open; consider a queueing/rate-limited UI rather than a bare "spam the mint button" pattern to reduce failed-transaction noise for users.
- Graduation/migration events (DBC→DAMM, LaunchLab→Raydium AMM) are a state transition your indexer needs to catch promptly — poll or subscribe for the graduation event rather than assuming a fixed timeline, since it triggers on market cap, not a clock.
- Vesting claims (Streamflow) are low-frequency, non-time-critical transactions — `confirmed` commitment is fine for UI feedback; no special landing-rate handling needed beyond the general guidance.

## Common pitfalls

- Forking/redeploying the Meteora DBC *program* itself under its non-commercial license instead of using the SDK against Meteora's live deployment — the license blocks the former, not the latter; re-verify with Meteora before any commercial redeploy.
- Treating `pump-science` as an npm/cargo dependency to install — it's a point-in-time audit-contest snapshot meant to be read for curve-math reference, not tracked upstream.
- Choosing Token-2022 for a token launch without checking that the DEX/wallet ecosystem you're launching into actually supports the specific extensions you picked (transfer fee, transfer hook) — support still lags plain SPL Token in places.
- Leaving mint or freeze authority active after launch "just in case" — this is the single most common trust-destroying mistake in this archetype and the easiest to automate a check for.
- Creating an Alpha Vault (or equivalent anti-snipe gate) after the pool already exists, leaving a window where ungated public buys can land first.
- Vendoring Streamflow's GPL-3.0 `js-sdk` into a closed-source product without checking whether your packaging (arm's-length dependency vs. modified/redistributed source) actually triggers copyleft obligations.
- Depending on Bonfida token-vesting for a live launch without re-verifying it against the current runtime — it's flagged dormant, not actively maintained.
- Shipping Candy Machine with the guard set unreviewed — guard composition is easy to get wrong and hard to change once minting has started.
- Assuming a legacy `mpl-token-metadata` NFT project and a new `mpl-core` project are interchangeable — migration between the two standards is a distinct, separate flow, not automatic compatibility.
