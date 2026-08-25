---
title: Foundry Workflow & EVM Security Patterns
description: Foundry commands (build/test/fuzz/invariant/fork/script), OZ vs Solady library picks, and the recurring EVM vulnerability patterns to check for in an audit or logic-explain pass.
applies_to: [evm]
sources:
  - "Foundry Book - https://book.getfoundry.sh (verified 2026-08-25)"
  - "Foundry cheatcodes reference - https://book.getfoundry.sh/cheatcodes (verified 2026-08-25)"
  - "OpenZeppelin Contracts 5.x docs - https://docs.openzeppelin.com/contracts/5.x (verified 2026-08-25)"
  - "OpenZeppelin Contracts 5.0 announcement (ERC-7201 namespaced storage) - https://www.openzeppelin.com/news/introducing-openzeppelin-contracts-5.0 (verified 2026-08-25)"
  - "Solady (Vectorized) - https://github.com/Vectorized/solady (verified 2026-08-25)"
  - "CertiK: Curve/dForce read-only reentrancy - https://www.certik.com/resources/blog/curve-conundrum-the-dforce-attack-via-a-read-only-reentrancy-vector-exploit (verified 2026-08-25)"
  - "Cyfrin: Reentrancy attacks in Solidity - https://www.cyfrin.io/blog/what-is-a-reentrancy-attack-solidity-smart-contracts (verified 2026-08-25)"
last_verified: 2026-08-25
---

# Foundry Workflow & EVM Security Patterns

Secondary chain reference — keep EVM work tight, reuse Solidity's mature library ecosystem instead of writing primitives. Default here: **new project = Foundry + OZ (or Solady if gas-critical) + this checklist**, not custom crypto/access-control code.

## 1. Foundry workflow (reuse-first: don't hand-roll a test harness)

```bash
foundryup                          # install/update forge, cast, anvil, chisel
forge init my-project               # scaffold (forge-std included)
forge build                         # compile
forge test -vvv                     # run tests, -vvvv for full traces on fail
forge fmt                           # canonical formatter — run before every commit
forge coverage                      # line/branch coverage (catch untested branches)
```

**Fork testing** (test against real mainnet state — do this for anything touching a live protocol, e.g. Uniswap/Aave integration):
```bash
forge test --fork-url $RPC_URL --fork-block-number 20000000 -vvv
```
Or pin in code with `vm.createSelectFork(rpcUrl, blockNumber)` for deterministic CI runs.

**Fuzz testing** — property tests over random inputs, near-zero cost to add:
```solidity
function testFuzz_transferNeverExceedsBalance(uint256 amount) public {
    amount = bound(amount, 0, token.balanceOf(alice)); // bound() > vm.assume() for wide ranges
    vm.prank(alice);
    token.transfer(bob, amount);
}
```
Use `vm.assume(cond)` only to reject a small fraction of inputs (rejecting >~90% stalls the fuzzer) — prefer `bound()`.

**Invariant testing** — properties that must hold across *any* sequence of calls, the highest-signal test type for stateful protocols (vaults, AMMs, lending):
```solidity
// invariant: total shares always <= total assets deposited
function invariant_solvency() public view {
    assertLe(vault.totalSupply(), vault.totalAssets());
}
```
Define a `targetContract()` / handler pattern to bound the call surface; use `invariant.fail-on-revert = true` in `foundry.toml` for stricter runs. Configure `max_time_delay` / `max_block_delay` when a bug depends on elapsed time (e.g. TWAP, vesting, reward accrual) — forge fuzzes call sequence *and* time/block distance between calls.

**Key cheatcodes** (`vm.*`): `prank`/`startPrank` (impersonate sender), `deal` (set ETH/token balance), `expectRevert`/`expectEmit`, `warp`/`roll` (time/block travel), `mockCall`, `record`/`accesses` (storage diffing), `snapshot`/`revertTo`.

**Deploy & interact:**
```bash
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
cast call <addr> "balanceOf(address)(uint256)" <who> --rpc-url $RPC_URL
cast send  <addr> "transfer(address,uint256)" <to> <amt> --private-key $PK --rpc-url $RPC_URL
cast storage <addr> <slot> --rpc-url $RPC_URL     # raw slot read — use for storage-collision debugging
```
Use `forge script` (simulated + broadcast) over raw scripts for deploys — it dry-runs first and gives you a `.json` broadcast artifact for verification/record-keeping.

## 2. Library picks: OpenZeppelin vs Solady

| Need | Default | Why |
|---|---|---|
| Access control, general safety, anything upgradeable | **OpenZeppelin** | Most audited, most battle-tested, readable, huge Lindy effect. Use unless gas is the binding constraint. |
| Hot-path gas-critical code (high-frequency AMM/perp math, NFT mints at scale, L1 mainnet with real gas cost) | **Solady** | Heavily gas-optimized (assembly-heavy), same author ecosystem widely used by top protocols; audit reports in-repo but read less like textbook Solidity — review the assembly, don't assume readability. |
| Mixing both | Fine — e.g. OZ `AccessControl` + Solady `ECDSA`/`LibClone`/`MerkleProofLib` for the hot paths. Don't mix two reentrancy guards or two ERC20 impls in one contract. |

**Concrete OZ picks (don't reimplement these):**
- `Ownable2Step` — two-step ownership transfer (new owner must call `acceptOwnership()`); use over plain `Ownable` for any privileged role to prevent bricking to a typo'd address.
- `AccessControl` — role-based perms (`onlyRole(MINTER_ROLE)`) when you need more than one privileged role.
- `ReentrancyGuard` / `ReentrancyGuardTransient` (transient-storage variant, cheaper) — apply `nonReentrant` to any function with an external call before final state settles. OZ 5.x also ships **`nonReentrantView`**, a read-only guard for `view` functions that read state mid-mutation elsewhere — use it on any view fn whose return value a *different* protocol might trust mid-callback (see §3 read-only reentrancy).
- `SafeERC20` (`safeTransfer`/`safeTransferFrom`/`forceApprove`) — always wrap ERC20 calls; raw `.transfer()` breaks on non-standard tokens (USDT-style no-return-value, fee-on-transfer).
- Upgradeable (`@openzeppelin/contracts-upgradeable`): as of OZ v5 storage uses **ERC-7201 namespaced storage** (`@custom:storage-location erc7201:<id>`), which replaced the old sequential `__gap` pattern for OZ's own base contracts. Still add your own storage gap/namespace on *your* upgradeable contracts for future-proofing. **v4→v5 upgradeable migration is a known landmine** (layout incompatibility can brick a proxy) — never upgrade a v4-deployed proxy to v5 base contracts without running `validateUpgrade` from OZ Upgrades plugin first.

## 3. Vulnerability patterns to check (grep targets in parens)

| Pattern | What to check | Fix |
|---|---|---|
| **Reentrancy** (`.call{value`, external call before state write) | Any external call followed by a storage write for the same state the call could re-enter | CEI ordering + `nonReentrant`. Check *every* external call, not just `.call` — token transfers, hooks (ERC777, ERC1155 `onReceived`), NFT `safeTransferFrom` callbacks all reenter. |
| **Read-only reentrancy** | A `view` function whose return value is stale/wrong mid-transaction (e.g. `get_virtual_price()` during `remove_liquidity`) and is trusted by another contract's callback | Guard views with `nonReentrantView`; never let another protocol read your price/exchange-rate view without you guaranteeing it's only callable outside an active state mutation. Real losses: Curve/dForce Feb 2023 ($3.7M via dForce), Curve Vyper compiler bug July 2023 ($73M). |
| **Checks-Effects-Interactions (CEI)** violation | State changes *after* external calls | Reorder: validate → update state → external call last. |
| **Unchecked external call return** (`.call(`, `.send(`) | Low-level `call`/`send` return value ignored | Check the bool, or use `SafeERC20`/OZ `Address.sendValue`. |
| **Approval race / ERC20 approve front-run** (`.approve(`) | Non-zero→non-zero `approve()` allows a front-run to spend both allowances | Use `forceApprove` (OZ SafeERC20, resets to 0 first) or `increaseAllowance`/`safeIncreaseAllowance`. |
| **`tx.origin` auth** (`tx.origin`) | Any use of `tx.origin` for authorization | Never — use `msg.sender`. `tx.origin` is phishable via a malicious contract the user interacts with. |
| **Delegatecall storage collision** (`delegatecall`) | Proxy/implementation storage layout mismatch, or delegatecall to untrusted/arbitrary target | Match storage layout exactly (or use ERC-7201 namespacing); never `delegatecall` to a user-supplied address. |
| **Oracle / price manipulation** | Spot price from a single AMM pool used directly (`getReserves`, `slot0`) as an oracle | Use TWAP (Uniswap V3 `observe`), Chainlink, or multi-source aggregation; never trust single-block spot price for anything liquidatable. |
| **Signature replay** (`ecrecover`, `.isValidSignature`) | Signed message reusable across chains/contracts/time, or missing nonce | Use **EIP-712** typed structured data (domain separator binds chainId + verifying contract) + a nonce/deadline in the signed struct; invalidate nonce on use. OZ `ECDSA` + `EIP712` base contract, or Solady `SignatureCheckerLib`/`EIP712`. |
| **DoS by revert / unbounded loop** (`for (`, `.transfer(` to arbitrary address) | Loop over unbounded user-controlled array; external call to an address that can revert-on-receive (blocking a batch op) | Pull-over-push payments (let users withdraw, don't push to a loop of addresses); cap/paginate loops; avoid `.transfer()`'s fixed 2300 gas stipend causing silent failures on smart-contract recipients — use `call{value}` + checked return, or OZ `Address.sendValue`. |
| **Missing access control on init** | Upgradeable contract's `initialize()` callable by anyone, or `_disableInitializers()` missing from implementation constructor | `initializer` modifier + call `_disableInitializers()` in the implementation's constructor so the logic contract itself can't be initialized/hijacked. |
| **Integer edge cases** | Division-before-multiplication (precision loss), rounding direction favoring attacker in shares/debt math | Multiply before divide; round in the protocol's favor (e.g. round debt up, shares down) — same class of bug as Solana's checked-math/rounding items. |

## 4. Gas basics (quick wins, not micro-optimization rabbit holes)

- `calldata` over `memory` for external function array/struct params (no copy).
- Pack structs: order fields to fit multiple into one 32-byte slot (e.g. `uint128`+`uint128`, or `address`+`uint96`).
- `immutable`/`constant` for values fixed at deploy/compile time — no SLOAD.
- Custom errors (`error InsufficientBalance()`) over `require(cond, "string")` — cheaper deploy + revert.
- Cache storage reads used more than once in a function into a local `memory`/stack variable — each repeated SLOAD costs gas OZ/Solady code already does this; mirror the pattern in your own hot paths.
- `unchecked { }` only around arithmetic you've manually proven can't over/underflow (e.g. a loop counter bounded by array length) — never around user-controlled values.

## 5. Do / don't

- **Do** run `forge coverage` before calling any contract "done" — untested branches are exactly where reentrancy/access-control bugs hide.
- **Do** fork-test against mainnet state for any contract that integrates a live external protocol.
- **Do** default to OZ; reach for Solady only when gas is the measured bottleneck.
- **Don't** hand-roll ECDSA recovery, Merkle proofs, ERC20/721/1155, or a reentrancy guard — OZ/Solady are more audited than anything written in a 6-12h build.
- **Don't** ship an upgradeable contract without running the OZ Upgrades plugin's storage-layout validation before every upgrade.
- **Don't** trust a single-block spot price or an unguarded external view function as an oracle.

## See also
- knowledge/security/evm-audit-checklist.md
- knowledge/testing/frameworks-and-matrix.md
- knowledge/security/solana-audit-checklist.md
