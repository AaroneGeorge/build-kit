---
title: Fuzzing and Invariant Testing (Foundry, Echidna, Trident)
description: When and how to add property-based fuzzing and stateful invariant tests on top of the unit matrix — Foundry invariant tests and Echidna for EVM, Trident for Anchor/Solana — with the per-archetype invariants worth encoding.
applies_to: [solana, evm]
sources:
  - "Foundry invariant testing - https://getfoundry.sh/forge/invariant-testing (verified 2026-08-29)"
  - "Cyfrin - fuzz testing with Foundry - https://www.cyfrin.io/blog/smart-contract-fuzz-testing-using-foundry (verified 2026-08-29)"
  - "Patrick Collins - fuzz/invariant tests as the bare minimum - https://patrickalphac.medium.com/fuzz-invariant-tests-the-new-bare-minimum-for-smart-contract-security-87ebe150e88c (verified 2026-08-29)"
  - "Echidna - https://github.com/crytic/echidna (verified 2026-08-29)"
  - "Trident (Ackee Blockchain) - https://github.com/Ackee-Blockchain/trident (verified 2026-08-29)"
  - "Trident docs - https://ackee.xyz/trident/docs/ (verified 2026-08-29)"
last_verified: 2026-08-29
---

# Fuzzing and invariant testing

The unit matrix in `frameworks-and-matrix.md` proves *specific* cases pass. Fuzzing proves a **property holds across thousands of random inputs and call sequences** — it finds the case you didn't think to write. This is the layer above the matrix, not a replacement: write the matrix first, add invariants for anything where funds are conserved or shares/accounting must balance.

## TL;DR (reuse-first)
- **Default fuzzer per chain:** Foundry (`forge test`) for EVM — property fuzzing and stateful invariant testing are built in, zero extra deps. **Trident** (Ackee, Solana-Foundation-backed) for Anchor/Solana — the Anchor-aware fuzzer. **Echidna** (Trail of Bits) for EVM when you want a second engine or property-mode assertions.
- **When to add it (not always):** any vault/AMM/staking/escrow where *fund conservation* or *share accounting* is an invariant; any supply cap or vesting schedule; anything with a state machine that must never reach an illegal state. A throwaway demo with no pooled funds can skip it — say so rather than skipping silently.
- **Cost:** an invariant suite is ~1–2 hours to stand up (handler + 3–5 properties). Budget it only for the fund-moving core, not the whole app.

## EVM — Foundry invariant tests

Foundry calls an invariant test a **stateful fuzz test**: it fires random sequences of calls and asserts the property still holds after each. Import `StdInvariant` from `forge-std`, set targets, write `invariant_*` functions.

```solidity
import {StdInvariant, Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {VaultHandler} from "./handlers/VaultHandler.sol";

contract VaultInvariants is StdInvariant, Test {
    Vault vault;
    VaultHandler handler;

    function setUp() public {
        vault = new Vault();
        handler = new VaultHandler(vault);
        // Only let the fuzzer call the handler's guided methods, not the raw vault.
        targetContract(address(handler));
    }

    // Property: the vault never owes more than it holds.
    function invariant_solvency() public view {
        assertGe(address(vault).balance, handler.ghost_totalOwed());
    }

    // Property: sum of shares == totalShares (no accounting drift).
    function invariant_shareAccounting() public view {
        assertEq(handler.ghost_sumOfShares(), vault.totalShares());
    }
}
```

- **Handler pattern (do this).** Pointing the fuzzer straight at the contract wastes runs on reverting calls (unbounded/nonsensical inputs). A **handler** wraps each function, bounds inputs (`bound(amount, 0, maxReasonable)`), tracks actors, and records **ghost variables** (running sums the invariant reads — e.g. total deposited, sum of shares). Set only the handler as `targetContract`.
- **Config** (`foundry.toml`): `[invariant] runs`, `depth` (calls per run), `fail_on_revert` (start `false` while shaping the handler, flip to `true` once calls are meaningful).
- **Plain (stateless) fuzz** is the cheaper cousin — one function, random args, no sequences: `function testFuzz_deposit(uint256 amount) { amount = bound(amount, 1, 1e24); ... }`. Use it for pure math (fee/rounding, price curves) before reaching for invariants.

## EVM — Echidna (second opinion)

Trail of Bits' property fuzzer. Write boolean properties (`echidna_*` returning `bool`) or assertion mode; run `echidna Contract.sol --contract C`. Reach for it when you want an independent engine on the same invariants, or corpus-guided coverage the auditor flagged as thin. Overlaps Foundry — not both by default; add it for the fund-moving core of a serious protocol.

## Solana / Anchor — Trident

The Anchor-aware fuzzer (Ackee Blockchain, Solana Foundation supported) — it has found criticals in Kamino, Marinade, and Wormhole audits. **Manually guided**: you specify realistic instruction sequences (setup → permutations → teardown) with Anchor-like macros, and assert **invariants** as properties checked after each flow (compare account state before/after).

- Use it when a Solana program pools funds or has multi-instruction ordering hazards (deposit/withdraw/settle, AMM swap paths, vesting claims). The invariant is the same idea as EVM: *funds conserved*, *shares balance*, *no illegal state transition*.
- It complements — does not replace — the LiteSVM unit matrix. LiteSVM proves the named auth/arithmetic cases; Trident hunts the sequence you didn't write.

## Invariants worth encoding, per archetype

| Archetype | Invariants to assert |
|---|---|
| **consumer-sites** (escrow/auction/payout) | Vault balance ≥ sum of owed payouts; exactly one winner settles; `settled` is one-way; no withdrawal exceeds deposit |
| **defi-trading** (DEX/AMM/vault/staking) | Constant-product `k` never decreases on swap (fees only grow it); `sum(shares) == totalShares`; vault solvency (assets ≥ redeemable); no free-mint of shares |
| **launch-mint** (launchpad/bonding-curve/vesting) | Minted ≤ supply cap; vested ≤ total allocation and monotonic in time; funds raised == tokens sold × price; no double-claim |
| **bots-infra / oracle consumers** | Price used is fresh (staleness bound); no unbounded loop over user-controlled length; idempotent handlers (replay changes nothing) |
| **wallets-payments** | Sum of balances == total custodied; a transfer conserves total; nonce/replay monotonic; no path spends another account's funds |

## Do / Don't

| Do | Don't |
|---|---|
| Write the unit matrix first, then add invariants for fund conservation / share accounting | Reach for fuzzing before the happy-path + auth + arithmetic unit tests exist |
| Use a handler with bounded inputs and ghost variables | Point the fuzzer at the raw contract and drown in reverting runs |
| Assert the few invariants that would mean "funds are safe" | Assert 20 shallow properties that restate the code |
| Scope the fuzz suite to the fund-moving core | Fuzz the whole app when only the vault holds value |

## See also
- `knowledge/testing/frameworks-and-matrix.md` — the unit matrix this layer sits on top of
- `knowledge/testing/per-archetype-tests.md` — the 5 non-negotiable unit tests per archetype
- `knowledge/security/evm-audit-checklist.md` / `knowledge/security/solana-audit-checklist.md` — the classes these invariants guard
