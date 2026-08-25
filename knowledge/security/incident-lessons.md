---
title: Incident Lessons
description: Pattern library of real Solana + EVM exploit postmortems mapped to checklist items, for security-audit and scout subagents
applies_to: [solana, evm]
sources:
  - "Halborn - Explained the Wormhole Hack - https://www.halborn.com/blog/post/explained-the-wormhole-hack-february-2022 (verified 2026-08-25)"
  - "CertiK - Cashio App Incident Analysis - https://www.certik.com/resources/blog/cashio-app-incident-analysis (verified 2026-08-25)"
  - "CertiK - Crema Finance Exploit - https://www.certik.com/resources/blog/crema-finance-exploit (verified 2026-08-25)"
  - "Cointelegraph - How low liquidity led to Mango Markets losing over $116 million - https://cointelegraph.com/news/how-low-liquidity-led-to-mango-markets-losing-over-116-million (verified 2026-08-25)"
  - "Immunefi - Hack Analysis: Nomad Bridge, August 2022 - https://immunefi.com/blog/bug-fix-reviews/hack-analysis-nomad-bridge-august-2022/ (verified 2026-08-25)"
  - "Cyfrin - Deep Dive Exploit Analysis: Euler Finance - https://www.cyfrin.io/blog/how-did-the-euler-finance-hack-happen-hack-analysis (verified 2026-08-25)"
  - "CertiK - Nirvana Finance Incident Analysis - https://www.certik.com/blog/nirvana-finance-incident-analysis (verified 2026-08-25)"
  - "Rekt.news - https://rekt.news (index of exploit writeups, verify per-incident)"
last_verified: 2026-08-25
---

# Incident Lessons

Real exploits, tight entries. Each maps to a checklist item in
`knowledge/security/solana-audit-checklist.md` or `knowledge/security/evm-audit-checklist.md`
(create/reference those files; if the exact ID doesn't exist yet, treat the
prevention line as the checklist item). Use this file to pattern-match a
diff/design against known failure classes — not for history trivia.

## How to use this file (subagent instructions)

1. When auditing a Solana program, grep the diff for: raw `AccountInfo` reads
   without `Account<'info, T>`/Anchor constraints, manual `try_from_slice`,
   any oracle price read, any bridge/relayer message-verify path, any mint/burn
   authority check. Match against the ROOT-CAUSE rows below.
2. When auditing EVM, grep for: external calls before state writes, any
   function that changes balances/reserves without a subsequent health/solvency
   check, `donate`/`sync`/`skim`-style functions, single-block spot price reads
   (`getReserves`, `balanceOf` used as price), bridge message roots/merkle
   roots initialized to zero or attacker-controlled values.
3. Cite the matching incident by name in findings — it's a fast way to convey
   severity to a human reviewer.

---

## Solana incidents

### Wormhole (Feb 2022) — $326M
**What happened:** Attacker forged a fake `sysvar` account and passed it into
the guardian-signature verification instruction on the Solana side of the
bridge; the code path used the deprecated, unchecked `load_instruction_at`
instead of `load_instruction_at_checked`, so the forged account was never
confirmed to be the real `Instructions` sysvar. This let the attacker
fabricate a "120,000 wETH minted" message with no real guardian signatures.
**Root cause class → checklist item:** `verify-sysvar-account-identity` /
"never trust an `AccountInfo` — always check `.key` equals the expected
program-derived/sysvar address before reading it." Same family as missing
signer/owner checks.
**Prevention:** Use checked sysvar/instruction-introspection helpers only;
never accept an account's contents as authoritative until you've verified its
address and owner match what you expect. For any signature-verification
program, get a second audit specifically on the verify path — this is the
highest-value line of code in a bridge.

### Cashio (Mar 2022) — $52.8M "infinite mint"
**What happened:** Cashio's mint instruction accepted attacker-supplied
`saber_swap.arrow` and `crate_collateral_tokens` accounts without validating
the `mint` field inside them against the expected collateral mint. The
attacker built a chain of fake accounts that looked valid structurally but
held worthless "collateral," and minted unlimited CASH against it. Unaudited
project.
**Root cause class → checklist item:** `validate-full-account-chain` — every
account passed into a mint/deposit/withdraw instruction must have its owner,
discriminator, AND inner fields (mint, authority) checked against the
specific expected value, not just "is this owned by the right program."
Anchor's `#[account(constraint = ...)]` and `has_one` exist exactly for this;
don't rely on `UncheckedAccount` past the boundary.
**Prevention:** For any instruction that mints/burns/transfers based on a
supplied collateral/vault account, write an explicit constraint chain (mint →
vault → authority → pool) and add a test that passes a *structurally valid
but wrong* account at every hop.

### Crema Finance (Jul 2022) — $8.8M
**What happened:** Attacker created a fake "tick array" account and wrote a
legitimate-looking initialized tick address into it, bypassing an owner
check. The forged tick data was then used by the fee-calculation logic,
letting the attacker claim an inflated fee payout after flash-loaning
liquidity into the pool.
**Root cause class → checklist item:** `verify-account-owner-before-use` —
same family as Wormhole/Cashio: any account read for pricing/fee/state data
must be checked with `account.owner == expected_program_id` (or an Anchor
`Account<'info, T>` deserialize, which does this for you) before its fields
are trusted.
**Prevention:** Never use `AccountInfo` + manual deserialization for
state-bearing accounts (tick arrays, oracle accounts, pool state) — use
Anchor's typed `Account<'info, T>` wrapper, which enforces owner + discriminator
checks automatically, or an explicit `require_keys_eq!(account.owner, expected)`
if manual.

### Mango Markets (Oct 2022) — $117M
**What happened:** Attacker opened a large MNGO-PERP position, then pumped
thinly-traded spot MNGO from $0.02 to $0.91 using ~$10M, inflating the
perp mark price (sourced from that same thin market) and the unrealized PnL
on the position. Mango's risk engine let the attacker borrow ~$116M against
that unrealized (unmanipulated-market-unverified) PnL as collateral.
**Root cause class → checklist item:** `oracle-liquidity-and-twap-check` —
never price collateral/liquidation thresholds off a single spot price from a
thin market; require TWAP, minimum liquidity depth, and a cap on how much of
a position's collateral value can come from unrealized PnL on a
self-opened/correlated position.
**Prevention:** Use a manipulation-resistant oracle (Pyth/Switchboard with
confidence-interval checks; re-verify current recommended pattern), cap
borrow power derived from unrealized PnL, and set per-market open-interest
caps sized to actual spot liquidity, not just protocol TVL.

### Nirvana Finance (Jul 2022) — ~$10M, bonding-curve variant of the same class
**What happened:** Attacker flash-loaned $10.25M USDC from Solend, used it to
buy $ANA and push its bonding-curve price from ~$8 to ~$24 in one
transaction, then swapped the now-overvalued ANA back to the protocol's
USDT/USDC treasury at the inflated rate, draining ~$3.5–10M and collapsing
the NIRV peg.
**Root cause class → checklist item:** `no-flashloan-atomic-price-source` —
identical failure mode to Mango/Harvest: a price (here, a bonding-curve spot
price) that can be moved and consumed for value extraction within a single
atomic transaction.
**Prevention:** Never let a single transaction both move a price and cash out
against that moved price. Use a TWAP with a minimum window longer than one
block/slot, or require a cooldown between "supply a large trade" and
"redeem against the resulting price."

### Solend — near-incident, governance/liquidation-risk lesson (not a hack)
**What happened:** June 2022 — a single whale account held an oversized
SOL-collateralized position that risked cascading, market-disrupting
liquidation if SOL price fell further; Solend's DAO passed (then reversed) an
emergency governance proposal to seize/take over the account's liquidation
via a special admin-controlled position — raising centralization and
governance-attack concerns of its own.
**Root cause class → checklist item:** `position-size-caps-and-liquidation-simulation`
— protocols must cap single-account exposure relative to on-chain liquidity
and simulate worst-case liquidation impact before launch, and any "emergency
admin override" capability is itself an attack surface requiring the same
scrutiny as a mint authority.
**Prevention:** Set per-wallet / per-market borrow caps tied to available
liquidation liquidity; if you ship an emergency-pause/admin-override path,
document and test it as a privileged-role checklist item, not an afterthought.

---

## EVM incidents

### The DAO (2016) — ~$60M, the original reentrancy
**What happened:** `splitDAO` sent ETH to the caller via a low-level call
*before* updating the caller's internal token balance; the caller's fallback
function re-entered `splitDAO` recursively before the balance was zeroed,
draining funds repeatedly in one transaction.
**Root cause class → checklist item:** `checks-effects-interactions` — always
update state before making an external call/transfer, or use a reentrancy
guard (OpenZeppelin `ReentrancyGuard`) on any function that both changes
state and sends value/calls out.
**Prevention:** CEI ordering by default; `nonReentrant` modifier on any
function with an external call + state mutation, especially anything
touching ETH/token transfer to a caller-controlled address.

### bZx (Feb 2020, two incidents) — ~$954K combined
**What happened:** Attacker used flash loans to briefly manipulate the spot
price on a thin on-chain market (Uniswap/Kyber) that bZx used directly as its
price oracle, then borrowed against the manipulated price.
**Root cause class → checklist item:** `no-single-block-spot-oracle` — same
family as Mango/Nirvana/Harvest: don't read a price from a source that can be
moved and consumed atomically.
**Prevention:** Use TWAP or an external oracle (Chainlink) decoupled from any
single-block-manipulable AMM pool; add sanity bounds (max price delta per
block) as a circuit breaker.

### Harvest Finance (Oct 2020) — $24M
**What happened:** Attacker used a large flash-loaned trade to move the
Curve Y-pool exchange rate, deposited into Harvest's vault at the skewed
share price, reversed the trade to restore the rate, then withdrew — pocketing
the share-price delta. Repeated the cycle 17x/13x across two pools within one
block.
**Root cause class → checklist item:** `no-single-block-spot-oracle` (vault
share pricing variant) — vault `pricePerShare` must not be computed from an
instantaneously-manipulable pool balance.
**Prevention:** Price vault shares using a TWAP or a manipulation-resistant
virtual price; add deposit/withdraw slippage checks and consider a
minimum-holding-period or fee on same-block deposit+withdraw.

### Nomad Bridge (Aug 2022) — ~$190M "crowd-looted" bridge
**What happened:** A routine upgrade initialized the trusted Merkle `root`
used to verify inbound cross-chain messages to `0x00` — which is also the
value the code used to represent "not yet proven." The verification function
therefore treated *every* message as already-proven, valid or not. Once one
attacker found this, hundreds of copy-paste imitators replayed the same
exploit transaction with their own address substituted in, no Solidity
skill required.
**Root cause class → checklist item:** `no-unsafe-default-in-security-state`
— a security-critical state variable (trusted root, admin address,
initialized flag) must never share a value with its "unset/failure" sentinel;
initialize explicitly and add an invariant test that the zero/default value
is provably rejected.
**Prevention:** Treat every upgrade/init path touching a trust root, owner,
or verification key as a full-severity change requiring the same review as
new logic; write a unit test that asserts message-with-zero-root == rejected.

### Euler Finance (Mar 2023) — $197M
**What happened:** The `donateToReserves` function (added 8 months earlier
in an upgrade, out of audit scope) let a user move their own eTokens to the
reserves without triggering the account health check that every other
balance-changing function ran. Attacker donated collateral to worsen their
own health factor artificially, then self-liquidated at a favorable discount
via a separate function, extracting value while leaving bad debt behind.
**Root cause class → checklist item:** `every-balance-mutation-checks-health`
— any function that changes a user's collateral/debt balance, including
"donation"/no-op-looking paths, must run the same solvency/health check as
borrow/withdraw. Enumerate every state-mutating entrypoint and confirm each
one hits the invariant check — don't assume "donate" is economically inert.
**Prevention:** Centralize the health check as a modifier/hook applied to
every balance-mutating external function, not called ad hoc per-function;
audit new functions added post-launch with the same rigor as the original
audit (this one sat unaudited for 8 months).

### Common bridge-hack shape (Ronin Mar 2022 ~$625M, Poly Network 2021 ~$610M)
**What happened (pattern, not single postmortem):** Ronin — 5-of-9 validator
signature scheme, attacker compromised enough validator keys (partly via a
fake job offer / compromised RPC allowlist) to forge withdrawal approvals.
Poly Network — cross-chain manager contract's "keeper" role could be changed
by any properly-formatted cross-chain call because the call-verification
logic checked the wrong field, letting the attacker set themselves as keeper
and drain all chains.
**Root cause class → checklist item:** `bridge-trust-minimization` —
multisig/validator sets are a centralization + key-compromise risk
proportional to TVL secured; access-control functions reachable via
cross-chain/relayed calls need the same "who can call this and with what
verified identity" scrutiny as any admin function.
**Prevention:** Minimize validator/guardian set trust (higher threshold,
HSM/MPC key custody, key rotation); for any privileged role settable via a
relayed/cross-chain message, explicitly verify the message originates from
the expected source chain+contract, not just that it's well-formed.

---

## Cross-cutting patterns (map every finding to one of these)

| Pattern | Solana example | EVM example | One-line rule |
|---|---|---|---|
| Unchecked account identity | Wormhole, Crema | — | Verify `.key`/`.owner` before trusting any account's data |
| Missing field-level validation | Cashio | — | Check inner fields (mint, authority), not just outer owner |
| Single-block/atomic price manipulation | Mango, Nirvana | bZx, Harvest | Never let one tx both move and consume a price |
| Missing invariant check on a state-mutating path | — | Euler | Enumerate all mutating entrypoints; same guard on every one |
| Unsafe default/sentinel collision | — | Nomad | Security state's "unset" value must differ from "valid" values |
| Reentrancy / CEI violation | — | The DAO | State before external call, or reentrancy guard |
| Centralized/relayed trust surface | Solend (governance) | Ronin, Poly Network | Treat multisig/keeper/relayer roles as high-severity attack surface |

## See also
- `knowledge/security/solana-audit-checklist.md`
- `knowledge/security/evm-audit-checklist.md` (if present — EVM checklist items referenced above)
- `knowledge/security/ship-gate-checklist.md` (pre-deploy gate; oracle staleness among the criticals)
- `knowledge/reuse-index/README.md` (prefer audited SDKs over hand-rolled bridge/oracle code)
