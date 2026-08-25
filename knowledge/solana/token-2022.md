---
title: Token-2022 Extension Gotchas
description: Traps naive escrow/AMM/mint code hits on Token-2022 (Token Extensions) mints, per-extension defenses, and reject-vs-whitelist guidance
applies_to: [solana]
sources:
  - "Solana Docs - Token Extensions overview - https://solana.com/docs/tokens/extensions (verified 2026-08-25)"
  - "Solana Docs - Permanent Delegate - https://solana.com/docs/tokens/extensions/permanent-delegate (verified 2026-08-25)"
  - "Solana Docs - Transfer Fees - https://solana.com/docs/tokens/extensions/transfer-fees (verified 2026-08-25)"
  - "Solana Docs - Transfer Hook guide - https://solana.com/developers/guides/token-extensions/transfer-hook (verified 2026-08-25)"
  - "Neodyme - SPL Token-2022: Don't shoot yourself in the foot with extensions - https://neodyme.io/en/blog/token-2022/ (verified 2026-08-25)"
  - "Offside Labs - Token-2022 Security Best Practices Part 2: Extensions - https://blog.offside.io/p/token-2022-security-best-practices-part-2 (verified 2026-08-25)"
  - "spl-token-2022 crate (v11.0.0) - https://crates.io/crates/spl-token-2022 (verified 2026-08-25)"
  - "@solana/spl-token JS docs (getTransferFeeConfig etc) - https://solana-labs.github.io/solana-program-library/token/js/ (verified 2026-08-25)"
last_verified: 2026-08-25
---

# Token-2022 (Token Extensions) Gotchas

If your escrow/AMM/vault code was written for classic SPL Token, it is **wrong by default** for
Token-2022 mints. Token-2022 keeps the same instruction shapes but lets a mint attach extensions
that change transfer semantics, balances, and even who can move funds. Never assume a mint is
"plain" — check its program owner and extensions before trusting amounts or authorities.

## TL;DR decision table

| Extension | Breaks naive code by... | Your move |
|---|---|---|
| `TransferFeeConfig` | received amount < sent amount | use `transferCheckedWithFee` / precompute post-fee amount, never assume 1:1 |
| `TransferHook` | arbitrary CPI runs during transfer, can touch your PDAs | validate hook program id, extra accounts, reentrancy; consider REJECT |
| `ConfidentialTransferMint` | amounts encrypted, no plaintext balance | REJECT for public-amount protocols (AMM/escrow) unless you built for it |
| `NonTransferable` | `transfer`/`transferChecked` always fails | REJECT for anything that needs to move the token (pools, escrow release) |
| `DefaultAccountState = Frozen` | new ATAs are frozen, deposits silently fail | check state before relying on a freshly-created account being usable |
| `PermanentDelegate` | issuer can move/burn funds from ANY account, no owner consent | REJECT for trustless escrow/vault; only whitelist if you trust the issuer |
| `InterestBearingConfig` | raw `amount` != displayed `uiAmount`, drifts over time | use `amountToUiAmountForMintWithoutSimulation` / read rate, don't hardcode |
| `MetadataPointer` / `TokenMetadata` | metadata may live off-mint or be mutable | resolve pointer before trusting name/symbol/uri; don't cache forever |

## Detecting a mint's extensions

**You cannot tell from the mint address.** You must fetch and parse.

### Client (TypeScript, `@solana/spl-token`)
```ts
import { getMint, getExtensionTypes, ExtensionType, TOKEN_2022_PROGRAM_ID } from "@solana/spl-token";

const mintInfo = await getMint(connection, mintPubkey, "confirmed", TOKEN_2022_PROGRAM_ID);
const exts = getExtensionTypes(mintInfo.tlvData); // ExtensionType[]

if (exts.includes(ExtensionType.PermanentDelegate)) throw new Error("reject: permanent delegate");
if (exts.includes(ExtensionType.NonTransferable)) throw new Error("reject: non-transferable");
if (exts.includes(ExtensionType.TransferHook)) { /* extra due-diligence path */ }
```
Per-extension getters exist and return `null` if absent — prefer these over manual TLV parsing:
`getTransferFeeConfig`, `getPermanentDelegate`, `getTransferHook`, `getNonTransferable`,
`getDefaultAccountState`, `getInterestBearingMintConfigState`, `getMetadataPointerState`,
`getConfidentialTransferMint` (all from `@solana/spl-token`).

First check the **owning program** — if `mintInfo.owner`/account owner is the classic
`TOKEN_PROGRAM_ID`, none of this applies. Token-2022 mints are owned by
`TOKEN_2022_PROGRAM_ID`. Never hardcode `TOKEN_PROGRAM_ID` when building ATAs/transfers if you
intend to support Token-2022 — always derive/pass the correct program id per mint
(`getAssociatedTokenAddressSync(mint, owner, allowOwnerOffCurve, programId)`).

### Program (Anchor/Rust, `spl-token-2022` / `anchor-spl`)
```rust
use anchor_spl::token_interface::{Mint, TokenInterface};
use spl_token_2022::extension::{StateWithExtensions, ExtensionType};
use spl_token_2022::state::Mint as MintState;

// In Anchor accounts struct, use `InterfaceAccount<Mint>` + `token_interface::TokenInterface`
// instead of `Account<token::Mint>` + `token::Token` — this accepts BOTH programs.

let mint_data = mint_account_info.try_borrow_data()?;
let mint_with_ext = StateWithExtensions::<MintState>::unpack(&mint_data)?;
let ext_types = mint_with_ext.get_extension_types()?;

for e in ext_types {
    if e == ExtensionType::PermanentDelegate || e == ExtensionType::NonTransferable {
        return err!(MyError::UnsupportedMintExtension);
    }
}
```
Anchor's `token_interface` module (in `anchor-spl` ≥ 0.30) gives you `TokenAccount`, `Mint`,
`TokenInterface`, and `transfer_checked` wrappers that work for both `Token` and `Token-2022` —
use these instead of hand-rolling program-id branches.

## Per-extension traps & defenses

### TransferFeeConfig
- **Trap:** amount received by the destination is `amount - fee`; fee is withheld *in the
  destination token account*, not deducted from sender. Naive escrow math (`assert dest.amount
  == pre + sent`) breaks.
- **Defense:** always use `transferCheckedWithFee` (client) / `transfer_checked_with_fee` (program)
  and precompute the expected fee with `calculateFee(transferFeeConfig, amount)` /
  `getTransferFeeConfig(mint)` reading `newerTransferFee`/`olderTransferFee` (epoch-gated). Read
  post-fee balance from-chain rather than trusting the pre-transfer amount. Accounts holding
  withheld fees cannot be closed until harvested — call `harvestWithheldTokensToMint` /
  `withdrawWithheldTokensFromAccounts` in any close-account flow that touches these mints.

### TransferHook
- **Trap:** the mint's designated program gets CPI'd into on every transfer, with extra accounts
  supplied via an `ExtraAccountMetaList` PDA (seeds `["extra-account-metas", mint]`). That hook
  program can read/write any account it declares — including ones that look like they belong to
  your protocol. It runs *after* balances are updated, so state can be reentered.
- **Defense:**
  - Resolve extra accounts via `spl-transfer-hook-interface` (`getExtraAccountMetas` /
    `addExtraAccountsToInstruction` helpers) rather than guessing.
  - In your own program, if you must interact with hook-having mints, use
    `transfer_checked` with `spl_token_2022::onchain::invoke_transfer_checked`, which resolves and
    forwards hook accounts correctly instead of a raw CPI that skips the hook (skipping the hook
    yourself will just fail the transfer, but a naive re-implementation is a common bug).
  - Don't trust hook program's own claims about its accounts; verify the `transferring` flag on
    involved accounts is true and that account mints match, if you're the one writing a hook.
  - Default posture for a new integration: **whitelist known-good hook programs only**; treat
    unknown transfer-hook mints as reject-by-default for pooled/composable protocols (AMM, lending)
    where arbitrary CPI during a swap/liquidation is a direct attack surface.

### PermanentDelegate
- **Trap:** the mint declares an address that can `Transfer`/`Burn` from **any** token account of
  that mint, at any time, without the owner's signature, and owners cannot revoke it. This is
  designed for compliance/stablecoin clawback use cases — but for an unaware protocol it means
  "your escrow/vault balance can go to zero out from under you at any time."
- **Defense: REJECT by default for trustless escrow, vaults, and AMM pools.** Only accept if you
  explicitly trust and have vetted the delegate authority (e.g., a known regulated stablecoin
  issuer) and your protocol design tolerates unilateral balance changes. Add monitoring/invariant
  checks (expected vs actual balance) rather than assuming conservation of tokens.

### NonTransferable
- **Trap:** `transfer`/`transferChecked` always errors for these mints (soulbound tokens). Any
  code path expecting to move the token (deposit to pool, release from escrow, LP transfer) fails.
- **Defense:** detect and REJECT at intake (don't let a user list/deposit a non-transferable
  token). Owner-initiated burn still works if you need an exit path.

### DefaultAccountState
- **Trap:** mint can force every newly created token account to start `Frozen`. A vault that
  creates an ATA and immediately expects to receive tokens into it will fail silently/loudly
  depending on your error handling.
- **Defense:** after creating an ATA for such a mint, check `tokenAccount.isFrozen` /
  `state === AccountState.Frozen` and thaw (requires the freeze authority — often not you) before
  relying on it. If you don't control the freeze authority, treat the mint as REJECT for
  auto-provisioned vault accounts.

### InterestBearingConfig
- **Trap:** the raw on-chain `amount` (u64) is the principal; the *displayed* balance accrues
  interest continuously via a formula, so `amount != uiAmount`. Code comparing raw amounts across
  time, or assuming `uiAmount` is just `amount / 10^decimals`, drifts.
- **Defense:** for display, use `amountToUiAmountForMintWithoutSimulation(connection, mint, amount)`
  (client) or the on-chain accrual math (program) instead of naive division. For settlement logic,
  prefer working in raw `amount` (principal) and treat interest as cosmetic unless your protocol
  specifically needs to account for it — this extension is low-risk (no fund-loss vector), it's
  a correctness/UX issue, not a security one.

### ConfidentialTransfer
- **Trap:** balances/amounts are encrypted (ElGamal + zero-knowledge proofs); a protocol reading
  plaintext `amount` off a confidential account gets garbage or zero. Interop with public-balance
  logic (AMM pricing, escrow release conditions) is not possible without redesign.
- **Defense: REJECT for standard AMM/escrow/lending unless you're explicitly building confidential
  support** (requires ElGamal client-side proof generation, `@solana/spl-token`'s confidential
  transfer instructions, and usually a separate audited integration). Also note: exceeding
  `maximumPendingBalanceCreditCounter` lets an attacker grief a recipient's ability to receive.

### MetadataPointer / TokenMetadata (Metadata extension)
- **Trap:** the pointer can reference metadata stored somewhere other than the mint itself (or a
  third-party account), and it can be mutated by the update authority after you last read it.
  Caching name/symbol/uri indefinitely, or trusting them for financial decisions (e.g. as a
  substitute for verifying the mint address), is a spoofing vector.
- **Defense:** resolve via `getMetadataPointerState(mint)` -> fetch the pointed-to account ->
  re-resolve periodically if displaying to users; never use metadata fields (symbol/name) as an
  identity check — always key off the mint pubkey.

## Reject vs whitelist — practical policy

For a 6-12h build, don't try to support every extension. Pick one of two postures per surface:

1. **Deny-list (fast, safer default for pooled funds — AMM, lending, escrow release):** allow any
   Token-2022 mint EXCEPT `PermanentDelegate`, `NonTransferable`, `ConfidentialTransferMint`, and
   `TransferHook` pointing at an unrecognized program. Always use `transferChecked`/
   `transferCheckedWithFee` and read post-transfer balances from chain, never assume amounts.
2. **Allow-list (for user-facing wallets/payment flows where you don't control counterparty
   mints):** maintain an explicit list of vetted mints (e.g. USDC, your own token) and their known
   extension set; treat any unlisted mint as untrusted input — show a warning, don't auto-integrate.

Either way: **always call `getExtensionTypes`/parse extensions before the first interaction with
an unfamiliar mint**, and gate on program id (`TOKEN_2022_PROGRAM_ID` vs `TOKEN_PROGRAM_ID`) — a
huge class of Token-2022 bugs is code that hardcoded the classic Token program id and either
crashes or, worse, silently no-ops.

## Reuse-first — don't hand-roll extension parsing

| Need | Use | License / status |
|---|---|---|
| Rust program-side extension read/parsing, checked transfer | `spl-token-2022` crate (v11.x as of 2026-05) | Apache-2.0, maintained by Anza/Solana Labs — canonical, don't reimplement TLV parsing |
| Anchor account wrappers that accept both Token & Token-2022 | `anchor-spl::token_interface` (Anchor ≥0.30) | Apache-2.0, part of Anchor — use `InterfaceAccount<Mint/TokenAccount>` + `TokenInterface` |
| Transfer-hook interface accounts/CPI resolution | `spl-transfer-hook-interface` crate + `@solana/spl-token` JS helpers | Apache-2.0, Anza-maintained |
| Client-side mint/account parsing, fee calc, extension getters | `@solana/spl-token` (`getMint`, `getExtensionTypes`, `getTransferFeeConfig`, `calculateFee`, `transferCheckedWithFee`) | Apache-2.0 |
| Newer/lighter client stack | `@solana/kit` (formerly web3.js v2) + `gill` — check current Token-2022 helper coverage before relying on it for confidential/hook edge cases (younger, re-verify) | MIT/Apache — actively evolving, re-verify API surface |

**(re-verify)** `@solana/kit`/`gill` Token-2022 extension coverage moves fast; confirm current
helper availability against their docs before depending on them for anything beyond basic
transfer/mint reads. `spl-token-2022` crate version above verified via crates.io on 2026-08-25 —
recheck before pinning in `Cargo.toml`.

## See also
- knowledge/security/solana-audit-checklist.md
- knowledge/solana/anchor-idioms.md
