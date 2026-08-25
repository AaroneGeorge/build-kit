---
title: Anchor Account-Constraint Idioms
description: Safe-by-construction Anchor account constraints, PDA design, and CPI safety patterns for Solana programs
applies_to: [solana]
sources:
  - "Anchor account constraints reference - https://www.anchor-lang.com/docs/references/account-constraints (verified 2026-08-25)"
  - "Anchor account space reference - https://www.anchor-lang.com/docs/references/space (verified 2026-08-25)"
  - "Anchor 1.0.0 release notes - https://www.anchor-lang.com/docs/updates/release-notes/1-0-0 (verified 2026-08-25)"
  - "solana-foundation/anchor releases - https://github.com/solana-foundation/anchor/releases (verified 2026-08-25)"
  - "RareSkills - init_if_needed reinitialization attack - https://rareskills.io/post/init-if-needed-anchor (verified 2026-08-25)"
  - "Solana bump seed canonicalization - https://github.com/etherfuse/solana-course/blob/main/content/bump-seed-canonicalization.md (verified 2026-08-25)"
  - "Zealynx Solana security checklist - https://www.zealynx.io/research/smart-contracts/solana-security-checklist (verified 2026-08-25)"
last_verified: 2026-08-25
---

# Anchor account-constraint idioms

REUSE-FIRST: every check below is a battle-tested Anchor macro. Writing manual
`require!(...)` for something a constraint already does is a code smell —
it's more code, less audited, and a common source of missed checks. Only drop
to `constraint =` / manual logic when no built-in constraint covers the case.

## Version baseline (re-verify before relying on exact numbers)

- **Anchor is on major version 1.x** — `anchor-lang` / `anchor-spl` at **1.1.2**
  as of 2026-08-25. The repo moved from `coral-xyz/anchor` to
  **`solana-foundation/anchor`**; old `coral-xyz` links may redirect.
- **Anchor 1.0.0 (Apr 2026) was a breaking release**: the TS client package
  renamed `@coral-xyz/anchor` → **`@anchor-lang/core`** (`npm install
  @anchor-lang/core`; update all imports, including IDL types). Targets
  **Solana 3.x**. **LiteSVM** is now the default test template; **Surfpool**
  is the recommended local-validator replacement for `solana-test-validator`.
- `Cargo.toml`: pin `anchor-lang = "1.1"` / `anchor-spl = "1.1"`, keep CLI
  (`avm install latest && avm use latest`) and crate versions in lockstep —
  version-skew between `anchor-cli` and `anchor-lang` is a top source of
  "works on my machine" build failures.

## Discriminator & account space

- Every `#[account]` struct gets an **8-byte discriminator** prepended
  automatically = first 8 bytes of `sha256("account:<StructName>")`. This is
  what makes account-type confusion (passing a `Vault` where a `UserConfig`
  is expected) fail *before* your handler code runs — don't disable it.
  Newer Anchor allows `#[discriminator(...)]` overrides for custom byte
  layouts; never set it to all-zero (reserved).
- Use `#[derive(InitSpace)]` on the account struct, then:
  ```rust
  #[account(init, payer = payer, space = 8 + MyAccount::INIT_SPACE, seeds = [...], bump)]
  pub my_account: Account<'info, MyAccount>,
  ```
  `INIT_SPACE` is the Borsh size **excluding** the 8-byte discriminator — you
  must add the `8 +` yourself. Forgetting it is the #1 "account did not
  serialize" bug.
- Variable-length fields need explicit caps for `InitSpace` to compute a
  size: `#[max_len(64)] pub name: String` / `#[max_len(10)] pub items:
  Vec<Pubkey>`.
- `zero` constraint (skip discriminator check on init) is for accounts too
  large to `init` in one CPI (>10 KiB) — create with `system_program` +
  `zero` externally, then hand off; rare in a 6-12h ship, don't reach for it
  by default.
- `realloc = <new_space>, realloc::payer = <acc>, realloc::zero = <bool>` —
  grows/shrinks an account at instruction start; `realloc::zero = true`
  zeroes new bytes (needed if you later re-read them as a fresh struct).

## Constraint cheat-sheet

| Constraint | Checks | Use for | Gotcha |
|---|---|---|---|
| `signer` | account signed the tx | any authority/payer | doesn't check *ownership*, only that it signed — pair with `has_one` |
| `mut` | marks account writable, persists changes | any account you write to | Anchor silently drops writes without it — no error, just no-op |
| `has_one = field` | `account.field == other_account.key()` | linking a data account to its owner/authority stored on-chain | field name in the struct must match; doesn't imply `signer` — add separately |
| `seeds = [...], bump` | account is the canonical PDA for these seeds under *this* program | any PDA account | bare `bump` (no stored value) re-derives and finds canonical bump each call — cheap enough, prefer it unless you've profiled CU cost |
| `seeds = [...], bump = account.bump_field` | PDA matches using a **stored** bump | hot-path PDAs where you already persisted the bump at `init` | never accept the bump as a raw instruction arg from the client — that's the reinitialization/bump-manipulation footgun |
| `address = <pubkey>` | account key equals a fixed/known pubkey | canonical addresses (a specific mint, a known program config) | pubkey must be `const` or in scope; wrong for anything user-supplied |
| `owner = <expr>` | account's on-chain **owner program** equals expr | accepting accounts owned by another program (rare outside CPI targets) | not the same as `has_one` — this is the *program* that owns the account, not a data field |
| `executable` | account is a program | validating a passed-in program before CPI | still verify it's the *right* program via `Program<'info, T>` or `address =`, not just that it's executable |
| `token::mint = m, token::authority = a` | validates (and can init) an SPL token account's mint + authority | any token account you read/write | on `init`, also add `token::token_program = ...` if not the legacy SPL Token program |
| `mint::authority`, `mint::decimals` | validates/creates a mint account | mint creation flows | pair with `mint::freeze_authority` if you need freeze |
| `associated_token::mint = m, associated_token::authority = a` | validates/derives the canonical ATA | user token accounts | prefer this over manual ATA PDA derivation every time — canonical ATA is deterministic and this constraint enforces it |
| `init` | CPIs to System Program to create + zero the account, sets discriminator | first-time account creation | fails if account already exists — use `init_if_needed` deliberately, not by default |
| `init_if_needed` | same as `init`, no-ops if already initialized | idempotent setup instructions **only** | **requires `anchor-lang` feature `init-if-needed`**; see reinit risk below — never use for accounts holding balances/state without extra guards |
| `close = destination` | zeroes data, sends lamports to `destination`, marks discriminator closed | account cleanup / rent reclaim | Anchor auto-adds a closed-account discriminator; still add a manual `require!(!account.is_closed)` style guard if the account could be resurrected via `init_if_needed` elsewhere in the same program |
| `constraint = <bool expr>` | arbitrary custom expression | anything not covered above | last resort — every custom `constraint` is un-typed and un-audited by Anchor itself; keep the expression to a single readable predicate, factor complex logic into a named method |
| `#[instruction(arg1, arg2)]` | exposes instruction args to constraint expressions above it | seeds/constraints that depend on ix args | args must be listed in the same order as the handler signature; trailing unused args can be omitted, leading ones cannot |

## PDA design

- **Seed hygiene**: mix a static domain-separator byte string with the
  narrowest identifying data, e.g. `seeds = [b"vault", owner.key().as_ref(),
  mint.key().as_ref()]`. A static prefix per account *type* prevents
  cross-type collisions (a `Vault` PDA and a `Config` PDA can never collide
  even with identical dynamic seeds).
- **Always use the canonical bump.** Prefer bare `bump` (Anchor searches
  bumps 255→0 for you) on hot paths where re-derivation cost is acceptable;
  when you need to skip re-derivation, **store the bump on the account at
  `init`** and reference it via `bump = account.field` — never accept a bump
  as a plain instruction argument and trust it. A non-canonical bump lets an
  attacker mint a second, different-address "PDA" for seeds you thought were
  unique, splitting state across two accounts.
- **PDA as signing authority (CPI)**: derive the seeds on the Rust side
  exactly as they were derived to create the PDA, build a `&[&[&[u8]]]`
  signer-seeds slice (include the bump byte), and pass via
  `CpiContext::new_with_signer` / `invoke_signed`:
  ```rust
  let seeds: &[&[u8]] = &[b"vault", owner.key.as_ref(), &[vault_bump]];
  let signer_seeds: &[&[&[u8]]] = &[seeds];
  token::transfer(
      CpiContext::new_with_signer(token_program, cpi_accounts, signer_seeds),
      amount,
  )?;
  ```
  A mismatched seed order/content vs. the original `init` derivation fails
  silently at the signature-check level (wrong signer, not a compile error)
  — test this path explicitly.
- Avoid seeding PDAs off client-controlled free-text without a length cap;
  combine with a `u8`/`u64` index seed for enumerable per-user accounts
  (`seeds = [b"order", owner.key().as_ref(), &order_id.to_le_bytes()]`)
  rather than trusting a string.

## CPI safety ("don't trust the account list")

- **Type your program accounts as `Program<'info, T>`**, never
  `UncheckedAccount` or raw `AccountInfo`, for any program you CPI into.
  `Program<'info, T>` checks both `executable` and that the key equals
  `T::id()` — this is what stops "arbitrary CPI" where an attacker swaps in
  a malicious program with the same interface.
- For non-Anchor / custom programs without an Anchor `Program` wrapper,
  pin the id explicitly: `#[account(address = expected_program::ID)]` on the
  `AccountInfo`, or check `program.key() == expected_id` before `invoke`.
- **Never `invoke` (or `invoke_signed`) into a program ID read from account
  data or an instruction argument** unless you've validated it against an
  allowlist — that's the canonical "arbitrary CPI" vulnerability class
  (attacker supplies a lookalike program that drains funds instead of, say,
  the real SPL Token program).
- When CPI-ing into SPL Token / Token-2022, prefer Anchor's typed `token::*`
  / `associated_token::*` constraints and the `anchor_spl::token_interface`
  module over manually building `Transfer`/`MintTo` instructions — they
  already pin the program id and account layout.
- Re-verify signer/writable flags on CPI'd accounts match what the target
  program expects; Anchor's `CpiContext` mirrors the accounts you pass, it
  does not re-derive privileges for you.

## `init_if_needed` — reinitialization risk

- Gate behind the Cargo feature explicitly: `anchor-lang = { version = "1.1",
  features = ["init-if-needed"] }` — Anchor makes you opt in on purpose.
- The risk: if the "already initialized" branch doesn't re-validate the
  account's *existing* state (owner, mint, amount == 0, etc.), an attacker
  can call the instruction a second time to reset fields you assumed were
  set once. **Always add explicit `constraint =` / in-handler checks for the
  invariants that must hold whether this is the first or a repeat call**
  (e.g. `constraint = vault.amount == 0 @ ErrorCode::AlreadyFunded` right
  after an `init_if_needed` token account).
- If the account only ever needs to be created once and never re-entered,
  use plain `init` and let the second call fail — that failure *is* your
  safety check.

## Copy-paste `#[derive(Accounts)]` example

```rust
use anchor_lang::prelude::*;
use anchor_spl::token_interface::{Mint, TokenAccount, TokenInterface};
use anchor_spl::associated_token::AssociatedToken;

#[account]
#[derive(InitSpace)]
pub struct Vault {
    pub owner: Pubkey,
    pub mint: Pubkey,
    pub bump: u8,
    #[max_len(32)]
    pub label: String,
}

#[derive(Accounts)]
#[instruction(label: String)]
pub struct OpenVault<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,

    /// CHECK: only used as a pubkey reference for `has_one` linkage below
    pub owner: UncheckedAccount<'info>,

    pub mint: InterfaceAccount<'info, Mint>,

    #[account(
        init,
        payer = payer,
        space = 8 + Vault::INIT_SPACE,
        seeds = [b"vault", owner.key().as_ref(), mint.key().as_ref()],
        bump,
    )]
    pub vault: Account<'info, Vault>,

    #[account(
        init,
        payer = payer,
        associated_token::mint = mint,
        associated_token::authority = vault,
        associated_token::token_program = token_program,
    )]
    pub vault_token_account: InterfaceAccount<'info, TokenAccount>,

    pub token_program: Interface<'info, TokenInterface>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

// Later ix that debits vault-owned tokens, signed by the PDA:
#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(
        mut,
        seeds = [b"vault", vault.owner.as_ref(), vault.mint.as_ref()],
        bump = vault.bump,
        has_one = owner,
    )]
    pub vault: Account<'info, Vault>,
    pub owner: Signer<'info>,
    #[account(mut, associated_token::mint = vault.mint, associated_token::authority = vault)]
    pub vault_token_account: InterfaceAccount<'info, TokenAccount>,
    #[account(mut, associated_token::mint = vault.mint, associated_token::authority = owner)]
    pub destination: InterfaceAccount<'info, TokenAccount>,
    pub token_program: Interface<'info, TokenInterface>,
}
```

Note the pattern: `init` derives with a bare `bump` and stores it
(`vault.bump = ctx.bumps.vault` in the handler); every later ix re-derives
with `bump = vault.bump` instead of re-searching — cheaper and immune to
bump-substitution.

## Constraints you probably forgot (checklist)

- [ ] Every `Signer<'info>` that should also be a specific stored authority
      also has `has_one = <field>` (or `constraint =`) — a valid signature
      alone doesn't mean it's *the right* signer.
- [ ] Every `mut` account that's written actually has `mut`; every account
      that *shouldn't* change lacks it (missing `mut` errors loudly, extra
      `mut` fails silently to protect you from anything).
- [ ] `init_if_needed` accounts re-validate invariants on the "already
      exists" path, not just the "just created" path.
- [ ] PDA `bump` is either bare (`bump`) or sourced from a **stored** field
      (`bump = x.bump`) — never a raw ix argument.
- [ ] All CPI target programs are `Program<'info, T>` / `Interface<'info,
      T>`, not `AccountInfo`/`UncheckedAccount`.
- [ ] Token accounts use `token::mint` + `token::authority` (or
      `associated_token::*`) rather than trusting caller-supplied token
      accounts unchecked.
- [ ] `close = dest` on every account meant to be single-use / reclaimable,
      so rent doesn't get stranded and stale accounts don't linger as attack
      surface.
- [ ] `space = 8 + T::INIT_SPACE` — the `8 +` isn't implied by
      `#[derive(InitSpace)]`.
- [ ] No `UncheckedAccount`/`AccountInfo` without an adjacent `/// CHECK:`
      comment explaining *why* it's safe unchecked (Anchor's lint enforces
      the comment exists; make sure the reasoning is actually correct, not
      boilerplate).
- [ ] `#[instruction(...)]` arg order matches the handler function
      signature exactly when used for seed derivation.
- [ ] Any `constraint =` expression is covering a case no built-in
      constraint already covers (dedupe against the table above).

## See also

- knowledge/security/solana-audit-checklist.md
- knowledge/solana/token-2022.md
- knowledge/testing/frameworks-and-matrix.md
- knowledge/reuse-index/consumer-sites.md
