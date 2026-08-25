# Seeded vulnerabilities (answer key)

Point `/debrief` and `/ship` at `programs/vulnerable-escrow/src/lib.rs` (NOT at this file).
This fixture is intentionally vulnerable — **DO NOT DEPLOY**. The three primary seeded bugs are the acceptance targets; the extras give the reviewer more to find.

## Primary seeded bugs (must be caught)

1. **Missing signer / authority check** — `settle()` + `Settle` accounts.
   - `authority: UncheckedAccount` is never required to sign and is never compared to `auction.authority`. Anyone can call `settle` and drain the vault to an arbitrary `recipient`.
   - Fix: `authority: Signer<'info>` + `#[account(mut, has_one = authority)]` on `auction`.
   - Checklist: `security/solana-audit-checklist.md` → Signer checks / owner-authority binding.

2. **Missing owner / account validation** — `Settle` (and `PlaceBid`) `vault` + `recipient`.
   - `vault` and `recipient` are `UncheckedAccount` with no owner, address, or PDA-seeds constraint. The vault is not proven to be *this* auction's vault; a caller can substitute any accounts.
   - Fix: make `vault` a PDA `#[account(mut, seeds = [b"vault", auction.key().as_ref()], bump)]`; constrain `recipient` (e.g. `== auction.highest_bidder`).
   - Checklist: owner checks / PDA seeds & bump / account substitution.

3. **Unchecked arithmetic** — `place_bid()` and `settle()`.
   - `auction.total_deposited += amount;` (overflow) and `auction.total_deposited = auction.total_deposited - amount;` (underflow).
   - Fix: `checked_add` / `checked_sub`, erroring on `None`.
   - Checklist: arithmetic (overflow/underflow).

## Extra issues a good /debrief should also flag
- `place_bid` never refunds the previous highest bidder (funds get locked).
- No auction-end / `settled` guard: `settle` can run anytime and repeatedly; `place_bid` still works after settle.
- Direct lamport manipulation on `vault` without confirming it is program-owned / rent-exempt safe.
- `settle` doesn't check `amount` against actual vault lamports, or that `recipient == highest_bidder`.
