---
title: Solana/Anchor Security Audit Checklist
description: Greppable, category-by-category Solana + Anchor program security checklist (risk / spot / safe pattern) for pre-ship audits
applies_to: [solana]
sources:
  - "coral-xyz/sealevel-attacks - https://github.com/coral-xyz/sealevel-attacks (verified 2026-08-25)"
  - "Neodyme - Solana Common Pitfalls - https://neodyme.io/en/blog/solana_common_pitfalls/ (verified 2026-08-25)"
  - "Neodyme - Token-2022 extensions pitfalls - https://neodyme.io/en/blog/token-2022/ (verified 2026-08-25)"
  - "Neodyme Solana Security Workshop - https://workshop.neodyme.io/ (verified 2026-08-25)"
  - "Trail of Bits - solana-vulnerability-scanner skill - https://trailofbits.com/skills/solana-vulnerability-scanner/ (verified 2026-08-25)"
  - "Anchor changelog (v1.1.2 current, org now solana-foundation/anchor) - https://www.anchor-lang.com/docs/updates/changelog (verified 2026-08-25)"
  - "Sec3 X-Ray static analyzer - https://github.com/sec3-product/x-ray (verified 2026-08-25)"
  - "Helius - Hitchhiker's Guide to Solana Program Security - https://www.helius.dev/blog/a-hitchhikers-guide-to-solana-program-security (verified 2026-08-25)"
last_verified: 2026-08-25
---

# Solana/Anchor Security Audit Checklist

Reuse-first: run **Sec3 X-Ray** (`x-ray scan`, open-source, 50+ vuln patterns, GH Action available) and **Trail of Bits' `solana-vulnerability-scanner` Claude Code skill** (6 core Sealevel patterns) as automated first passes before manual review below. Anchor is `>=0.31` / `1.x` (org moved `coral-xyz/anchor` -> `solana-foundation/anchor`, latest `1.1.2`) — most items below are Anchor constraints; native/pinocchio programs need the equivalent manual check.

For each item: **Risk** (what goes wrong) -> **Spot** (grep/read for this) -> **Safe** (the fix / Anchor constraint that enforces it).

## 1. Signer checks
- Risk: instruction executes a privileged action (withdraw, set-authority, close) without proving the caller controls the claimed authority key.
- Spot: `grep -n "AccountInfo" programs/**/*.rs`; any account used as an authority that is typed `AccountInfo`/`UncheckedAccount` instead of `Signer`; native code checking `*acc.key == authority` without `acc.is_signer`.
- Safe: type the account as `Signer<'info>` in the Anchor `#[derive(Accounts)]` struct — Anchor auto-rejects if `is_signer == false`. Native: explicit `if !authority_info.is_signer { return Err(...) }`. Reference: sealevel-attacks `0-signer-authorization`.

## 2. Owner / account-ownership checks
- Risk: attacker passes a lookalike account owned by a different (attacker-controlled) program; your code deserializes it as trusted state.
- Spot: `AccountInfo`/`UncheckedAccount` fields that get manually deserialized (`try_from_slice`, `unpack`) instead of using Anchor's typed `Account<'info, T>`; missing `owner = <program>` constraint on non-Anchor-owned accounts (e.g. token accounts, other programs' PDAs).
- Safe: `Account<'info, T>` checks `owner == program_id` automatically. For cross-program accounts use `#[account(owner = token_program.key())]` or `InterfaceAccount<'info, TokenAccount>` (owner-agnostic for Token/Token-2022). Reference: sealevel-attacks `2-owner-checks`.

## 3. Account data validation + type cosplay / discriminator
- Risk: "type cosplay" — attacker supplies an account of a *different* struct with the same byte layout/size so raw deserialization succeeds but fields mean something else.
- Spot: raw `AccountInfo` + manual `T::try_from_slice(&data.borrow())`; any struct without an 8-byte Anchor discriminator check; `#[account(zero_copy)]` structs missing discriminator validation on manual bytemuck casts.
- Safe: use `Account<'info, T>` — Anchor prepends and checks an 8-byte sighash discriminator per type automatically. For zero-copy, use `AccountLoader<'info, T>` (also discriminator-checked). Never hand-roll deserialization for typed state. Reference: sealevel-attacks `7-type-cosplay`.

## 4. PDA seeds / bump canonicalization
- Risk: accepting an attacker-supplied bump (`create_program_address` with arbitrary bump) lets them derive a *different*, non-canonical PDA that still "looks" like your account, bypassing seed-based access control; or seeds too loose (missing a discriminating seed) let one PDA be reused across contexts.
- Spot: `create_program_address(` calls with a caller-supplied bump byte instead of `find_program_address`; `#[account(seeds = [...], bump)]` without pinning `bump = state.bump` on later instructions (re-deriving lets a non-canonical bump slip through if you don't store+reuse it); seed lists missing a unique per-entity component (e.g. only `["vault"]`, no owner/mint key).
- Safe: derive with `find_program_address` (or `#[account(seeds=[...], bump)]` on the init instruction), **store the canonical bump in account state**, and on every later instruction reference it via `bump = state.bump` so Anchor re-derives and rejects mismatches. Include all entity-scoping keys in the seed list. Reference: sealevel-attacks `3-bump-seed-canonicalization`, `8-pda-sharing`.

## 5. Arithmetic (overflow/underflow, checked math, casts)
- Risk: unchecked `+ - * /` panics (DoS) in debug but silently wraps in release unless `overflow-checks = true`; unvalidated `as` casts (`u64 as u32`, `i64 as u64`) truncate or reinterpret sign, corrupting balances/amounts.
- Spot: `grep -nE '[^.]\b(amount|balance|supply)\b.*[+\-*/][^=]' programs/**/*.rs` for raw arithmetic on money fields; any `as u32`/`as u64`/`as i64` cast on a value that came from user input or another mint's decimals; confirm `Cargo.toml`/`[profile.release] overflow-checks = true` is actually set (Solana's default release profile does **not** enable it).
- Safe: use `checked_add/sub/mul/div` (or the `num-traits`/`anchor_lang::solana_program` checked helpers) and propagate `.ok_or(ErrorCode::MathOverflow)?`; prefer `TryFrom`/`try_into()` over `as` for narrowing casts; set `overflow-checks = true` in the program's release profile as defense-in-depth (don't rely on it alone — checked math must still be explicit). Reference: sealevel-attacks `6-overflow-underflow` (Anchor pre-0.24 had checked overflow by default via `#[program]` — verify current build target, re-verify).

## 6. CPI + program-id verification / arbitrary CPI
- Risk: instruction takes a "token_program"/"system_program" (or any target program) as a plain `AccountInfo` and CPIs into whatever address the caller passes — attacker substitutes a malicious program that mimics the expected interface (e.g. fake token program that "succeeds" a transfer without moving funds).
- Spot: `AccountInfo` fields fed into `invoke`/`invoke_signed` without an address check; `.to_account_info()` args passed to CPI helpers where the field type is `UncheckedAccount`.
- Safe: type program accounts as `Program<'info, Token>` / `Program<'info, System>` (Anchor checks the account key equals the well-known program ID) or, for custom programs, `#[account(address = expected_program::ID)]`. For Token-2022 support both mints, use `Interface<'info, TokenInterface>` which accepts either SPL Token or Token-2022 program IDs specifically (not arbitrary ones). Reference: sealevel-attacks `5-arbitrary-cpi`.

## 7. Account substitution + remaining_accounts
- Risk: instructions that iterate `ctx.remaining_accounts` (multi-hop swaps, batch ops, oracle lists) trust order/count/type without per-account validation, letting an attacker insert an extra or swapped account to redirect funds or spoof data.
- Spot: `remaining_accounts` usage with indexing (`remaining_accounts[i]`) and no owner/discriminator/key check inside the loop; account count assumed equal to a caller-supplied length field without bounds check.
- Safe: validate every remaining account's owner + discriminator + expected relationship (e.g. re-derive its PDA from a seed you control) before use; bound-check `remaining_accounts.len()` against expected count; never trust caller-supplied indices/lengths as sole determinant of trust. Prefer explicit typed accounts in the `Accounts` struct wherever the set is statically known.

## 8. Sysvar / clock assumptions
- Risk: reading `Clock`/`Rent`/`SlotHashes`/`Instructions` sysvar from a caller-passed `AccountInfo` instead of the syscall — pre-Solana-1.8.1-era spoofing bug class; also logic bugs treating `Clock::unix_timestamp` as precise/monotonic across validators or trusting `slot` for fine-grained timing.
- Spot: sysvar accounts declared as plain `AccountInfo`/`UncheckedAccount` and read via `Sysvar::from_account_info` on a passed-in key instead of `Sysvar::get()`; instruction-introspection code using `sysvar::instructions::get_instruction_relative` with **absolute** indices (replay/reorder risk) instead of relative.
- Safe: use `Sysvar<'info, Clock>` (Anchor validates the address) or the zero-account `Clock::get()?` syscall — never accept Clock/Rent as an arbitrary account on modern (>=1.8.1) validators. For instruction introspection use relative indexing and re-validate program IDs of neighboring instructions. Reference: sealevel-attacks `4-duplicate-mutable-accounts` workshop notes / Trail of Bits scanner "sysvar account check", "improper instruction introspection".

## 9. Rent / close-account revival + zeroing
- Risk: "closed" account (lamports drained, meant to be dead) is not zeroed/re-owned, so within the same transaction — or by refunding rent before garbage collection — an attacker revives it with stale-but-valid discriminator data ("revival attack").
- Spot: manual close logic that only does `**dest.lamports.borrow_mut() += acc.lamports()` / `**acc.lamports.borrow_mut() = 0` without zeroing `data` or reassigning `owner`; missing the `close = destination` Anchor constraint on accounts meant to be permanently closed.
- Safe: use `#[account(mut, close = destination)]` — Anchor sends lamports to `destination`, **zeroes the discriminator** (writes `CLOSED_ACCOUNT_DISCRIMINATOR`), and any subsequent deserialize attempt fails. If closing manually (native or cross-program), zero all data bytes AND drain lamports to below rent-exempt minimum in the same instruction. Reference: sealevel-attacks `9-closing-accounts`.

## 10. Duplicate mutable accounts
- Risk: an instruction takes two independent `mut` account params expected to be distinct (e.g. `source`/`destination` token accounts) but the caller passes the *same* account for both, causing double-counting, self-transfer draining fees, or logic that assumes independence to double-credit.
- Spot: instructions with 2+ same-typed mutable accounts and no `constraint = a.key() != b.key()`; manual balance-diff logic that would misbehave if `source == destination`.
- Safe: add explicit `#[account(mut, constraint = source.key() != destination.key() @ ErrorCode::DuplicateAccount)]` (or equivalent) wherever aliasing is unsafe; alternatively make the logic alias-safe (compute deltas idempotently). Reference: sealevel-attacks `4-duplicate-mutable-accounts`.

## 11. Reinit attacks
- Risk: an `init`-once account (e.g. config, vault) can be re-initialized by calling the init instruction again, resetting authority/state and letting an attacker take it over — especially if init logic doesn't check "already initialized" or relies on lamport balance alone.
- Spot: custom `initialize` handlers using `init_if_needed` without also validating that mutable state fields (authority, bump) aren't being silently overwritten; manual (non-`init`) account setup that just checks `lamports == 0` as the sole "not yet initialized" signal (can be griefed by pre-funding the PDA).
- Safe: use Anchor's `#[account(init, payer = ..., space = ...)]` (fails if the account already has data/discriminator — can't double-init). If you must use `init_if_needed` (requires the `init-if-needed` feature flag — audit-flagged as risky), add explicit `is_initialized` state-field guards in the handler body so re-entry is a no-op or errors. Reference: Neodyme common pitfalls; sealevel-attacks `1-account-data-matching` adjacent pattern.

## 12. Oracle / price manipulation
- Risk: reading price from a single spot-price source (a DEX pool's instantaneous reserves, or one CEX-fed oracle account) that can be flash-loaned/sandwiched within one transaction to misprice a mint/borrow/liquidation.
- Spot: price reads sourced directly from an AMM pool's token balances (`reserve_a / reserve_b`) instead of a TWAP or dedicated oracle; single-oracle reads with no staleness check (`price_update.timestamp`) and no confidence-interval check.
- Safe: use audited oracle SDKs — **Pyth** (`pyth-solana-receiver-sdk` / Pyth Pull Oracle, check `price_feed.get_price_no_older_than(clock, max_age)` and confidence band) or **Switchboard** (on-chain aggregator with staleness + variance guards); never derive price solely from a single pool's instantaneous reserves. Cross-check against a second source or a TWAP for high-value paths.

## 13. SPL-Token + Token-2022 pitfalls
- Risk (mint/decimals confusion): trusting a token account's `amount` without checking it belongs to the expected `mint`, or applying wrong decimals in a UI/calc.
- Risk (Token-2022 extensions): programs written against classic SPL Token silently mis-handle Token-2022 mints with **transfer fees** (received amount != sent amount), **transfer hooks** (extra CPI mid-transfer to an attacker-influenced program — reentrancy-like control-flow risk that classic Solana never had), or **freeze/permanent-delegate/confidential-transfer** extensions that change who can move funds.
- Spot: use of `spl_token::instruction::transfer` (deprecated, silently fails/ignores extensions) instead of `transfer_checked`; `TokenAccount`/`Program<'info, Token>` typed accounts where the mint could plausibly be Token-2022 (won't compile against Token-2022 mints, but check you *meant* to exclude them); no `mint.key() == expected_mint` constraint; transfer-hook-mint flows using `invoke` instead of the hook-aware CPI.
- Safe: always use `transfer_checked`/`transfer_checked_with_fee` (validates mint + decimals); for hook-aware transfers use `spl_transfer_hook_interface`'s `invoke_transfer_checked` helper which builds `ExtraAccountMetaList` correctly; to support both standards use `InterfaceAccount<'info, TokenAccount>` / `Interface<'info, TokenInterface>` from `anchor-spl`; explicitly decide and constrain which Token-2022 extensions your program accepts (reject mints with unexpected extensions via `get_mint_extension_types`). Reference: Neodyme "SPL Token-2022: Don't shoot yourself in the foot with extensions".

## 14. Upgrade authority + program mutability
- Risk: program is upgradeable (default for `solana program deploy`) and the upgrade authority is a single hot EOA key (or worse, still the deployer's default keypair) — a leaked key means instant, silent logic replacement and total fund loss; conversely, forgetting to eventually lock this down leaves a permanent rug vector visible to any auditor/user.
- Spot: `solana program show <program_id>` -> check "Upgradeable" and "Authority" fields; repo/CI for `solana program deploy` without a subsequent `set-upgrade-authority`; no multisig (Squads) or timelock governing upgrades pre-mainnet-serious-TVL.
- Safe: set upgrade authority to a **Squads multisig** (or DAO-controlled PDA) before/at mainnet launch; for genuinely finished programs, `solana program set-upgrade-authority <id> --final` to permanently disable upgrades (irreversible — only after audit + time-in-production); document the authority + threshold in your security disclosure. Reference: Trail of Bits Squads v4 audit; general Solana Program Security docs.

## 15. Front-running / MEV
- Risk: Solana has no public mempool but validators/searchers (via Jito bundles) can still see and reorder transactions within a leader's block; instructions with slippage-unaware pricing, auctions, or "first valid claimer" logic are sandwichable or back-runnable.
- Spot: swap/AMM instructions with no `min_amount_out`/`max_amount_in` slippage param; auction/claim instructions where value is purely a function of arrival order with no commit-reveal or randomness; liquidation instructions paying a flat, front-runnable bounty.
- Safe: require explicit slippage bounds passed and enforced on-chain (`require!(amount_out >= min_amount_out)`); use commit-reveal for order-sensitive allocation (e.g. NFT mints); route sensitive txs through Jito bundles for atomicity when ordering-safety matters; consider Dutch-auction-style decaying bounties for liquidations to reduce pure race dynamics.

## Quick pre-ship grep pass
```
rg -n "AccountInfo|UncheckedAccount" programs/*/src        # unvalidated accounts
rg -n "as u32|as u64|as i64|as usize" programs/*/src        # unchecked casts
rg -n "\.unwrap\(\)|\.expect\(" programs/*/src              # panics on untrusted input
rg -n "invoke\(|invoke_signed\(" programs/*/src             # manual CPI — verify program-id check nearby
rg -n "init_if_needed" programs/*/src                       # reinit-risk instructions
rg -n "spl_token::instruction::transfer\b" programs/*/src   # use transfer_checked instead
```

## See also
- knowledge/solana/anchor-idioms.md
- knowledge/solana/token-2022.md
- knowledge/testing/per-archetype-tests.md
- knowledge/security/evm-audit-checklist.md
- knowledge/security/ship-gate-checklist.md
