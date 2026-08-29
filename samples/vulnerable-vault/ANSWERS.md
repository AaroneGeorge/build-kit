# Seeded vulnerabilities (answer key)

Point `/audit`, `/debrief`, or `/ship` at `src/VulnerableVault.sol` (NOT at this file).
Intentionally vulnerable — **DO NOT DEPLOY.** The three primary seeded bugs are the acceptance targets; the extras give the reviewer more to find.

## Primary seeded bugs (must be caught)

1. **Reentrancy / CEI violation** — `withdraw()`.
   - `src/VulnerableVault.sol:59` sends ETH to `msg.sender` **before** `shares[msg.sender]` and `totalShares` are decremented (lines 62–63). A contract caller re-enters `withdraw()` with its share balance still intact and drains the vault. No reentrancy guard exists.
   - Fix: checks-effects-interactions — decrement `shares`/`totalShares` before the external call; add a `nonReentrant` guard (OZ `ReentrancyGuard` or a Solady equivalent).
   - Checklist: `security/evm-audit-checklist.md` → reentrancy / external calls & CEI.

2. **Missing access control** — `setFeeRecipient()`.
   - `src/VulnerableVault.sol:73` has no owner check, so anyone can redirect the entire fee stream to themselves — and point `feeRecipient` at a contract to open a second reentrancy surface via the fee callback in `withdraw()` (line 65). Contrast with `setFeeBps()` (line 79), which is correctly `onlyOwner`.
   - Fix: `require(msg.sender == owner, "only owner");` (or an OZ `Ownable`/`AccessControl` modifier).
   - Checklist: access control / privileged functions.

3. **Share-accounting error (inflation / rounding)** — `deposit()`.
   - `src/VulnerableVault.sol:40` mints `minted = (msg.value * totalShares) / backing` with `backing` read from raw `address(this).balance` (line 39), no virtual-shares offset and no minimum-shares floor. A small deposit into a large-backing vault rounds `minted` to **0** (depositor loses the ETH, inflating existing holders), and the first depositor can be front-run / the share price inflated by force-sent ETH (selfdestruct or `receive`).
   - Fix: use a stored asset accumulator rather than `address(this).balance`; add virtual shares/assets (ERC4626 offset) or a dead-shares mint; revert on `minted == 0`.
   - Checklist: arithmetic / rounding · oracle-or-balance manipulation · first-depositor inflation.

## Extra issues a good review should also flag
- No `ReentrancyGuard` anywhere; the fee transfer (line 65) is a second untrusted external call.
- `deposit()` derives share price from `address(this).balance`, which is manipulable by forced ETH — a balance-as-oracle smell independent of the rounding.
- `withdraw()` computes payout from live `address(this).balance`, so the amount depends on intra-block ordering (MEV / sandwich surface).
- No events emitted on deposit/withdraw/`setFeeRecipient` (privileged change is unobservable off-chain).
