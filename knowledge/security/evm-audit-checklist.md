---
title: EVM Audit Checklist
description: Actionable Solidity/EVM security audit checklist by vulnerability class, with detection heuristics and OZ/Solady-first safe patterns
applies_to: [evm]
sources:
  - "Solodit Checklist (Cyfrin) - https://github.com/Cyfrin/audit-checklist (verified 2026-08-25)"
  - "solcurity (transmissions11) - https://github.com/transmissions11/solcurity (verified 2026-08-25)"
  - "SWC Registry (legacy, superseded by EEA EthTrust) - https://swcregistry.io (verified 2026-08-25)"
  - "OpenZeppelin Contracts - https://github.com/OpenZeppelin/openzeppelin-contracts (verified 2026-08-25)"
  - "Solady (Vectorized) - https://github.com/Vectorized/solady (verified 2026-08-25)"
  - "DeFiHackLabs (exploit reproductions) - https://github.com/SunWeb3Sec/DeFiHackLabs (verified 2026-08-25)"
  - "pcaversaccio reentrancy-attacks list - https://github.com/pcaversaccio/reentrancy-attacks (verified 2026-08-25)"
  - "Trail of Bits Building Secure Contracts - https://github.com/crytic/building-secure-contracts (verified 2026-08-25)"
last_verified: 2026-08-25
---

# EVM Audit Checklist

Reuse-first: prefer **OpenZeppelin Contracts** (audited, battle-tested, slightly more gas) or **Solady** (gas-optimized, heavily tested but historically un-audited as a whole — verify per-primitive audit status before using in high-value paths) over hand-rolled primitives. Run **Slither** + **Aderyn**/**4naly3er** as static-analysis first pass before manual review; this checklist is for what static tools miss or flag without context.

## 1. Access Control
| Risk | Spot it | Safe pattern |
|---|---|---|
| Missing modifier on privileged fn | grep for `external`/`public` fns that set state, mint, withdraw, upgrade, pause — check each has `onlyOwner`/role check | OZ `Ownable2Step` (not 1-step `Ownable` — avoids bricking to a typo'd address) or `AccessControl` for role-based |
| `tx.origin` used for auth | grep `tx.origin` | Never use for auth; use `msg.sender`. Phishing via malicious contract calling into victim fn |
| Uninitialized/front-runnable initializer | proxy `initialize()` callable by anyone before deployer calls it | `_disableInitializers()` in constructor (OZ `Initializable`); deploy+initialize atomically (multicall/factory) |
| Self-destruct / arbitrary `delegatecall` reachable by non-owner | grep `delegatecall`, `selfdestruct` | Gate behind admin; never delegatecall to user-supplied address |
| Centralization risk (single EOA owns everything) | who can pause, upgrade, drain fees, blacklist? | Multisig (Safe) + timelock for anything mutating funds/logic; document as known risk if out of scope |
| Signature-based access without nonce/role binding | any `ecrecover`-gated privileged action | see §7 Signatures |

## 2. Reentrancy (incl. read-only)
| Risk | Spot it | Safe pattern |
|---|---|---|
| Classic reentrancy | external call (`.call`, token transfer to arbitrary address) before state update | CEI ordering + OZ `ReentrancyGuard` (`nonReentrant`) or transient-storage `ReentrancyGuardTransient` (cheaper, needs Cancun/EIP-1153) |
| Cross-function reentrancy | two external fns share state; guard only on one | Guard *all* fns touching the shared state, or use a single shared lock |
| Cross-contract reentrancy | protocol A calls into B which calls back into A via a different entrypoint | Threat-model the full call graph, not just one contract |
| **Read-only reentrancy** | a `view` fn (e.g. `get_virtual_price`, LP price oracle) reads state mid-callback while balances are updated but totalSupply isn't (or vice versa) during an external call in an unguarded function (e.g. Curve/Balancer `remove_liquidity` sending ETH before finalizing state) | Any external protocol that reads a price/exchange-rate `view` fn from Curve/Balancer/similar AMMs MUST check the pool isn't mid-reentrancy — call the pool's own reentrancy guard check if exposed, or use TWAP/oracle instead of spot on-chain reads during a callback window. Real losses: dForce ($3.7M, Feb 2023, Curve LP price read during `remove_liquidity` callback), Balancer-dependent protocols via ETH refund callback |
| ERC-777/ERC-1155 callback reentrancy | token has `tokensReceived`/`onERC1155Received` hook that reenters | Treat any token transfer as an external call; CEI + guard even for "just a transfer" |

## 3. External Calls & CEI
| Risk | Spot it | Safe pattern |
|---|---|---|
| Checks-Effects-Interactions violated | state write *after* `.call`/`.transfer`/`.send`/token transfer | Reorder: validate → update state → interact |
| Unchecked low-level call return | `address.call(...)` without checking bool, or ignoring return data | Always check success; use OZ `Address.functionCall` which reverts with the returned reason |
| `.transfer`/`.send` for ETH (2300 gas stipend) | grep `.transfer(` / `.send(` on payable address | Use `.call{value: x}("")` + checked return; 2300 gas breaks with contracts that have a fallback needing more gas (e.g. Safe wallets, EIP-2929 cost changes) |
| Untrusted external call in a loop | loop calling `.call`/token transfer per element, one revert DoS's the whole batch | Pull-over-push (let users withdraw individually) instead of push-pay-all |
| Arbitrary external target/calldata from user input | `target.call(userSuppliedCalldata)` | Whitelist targets/selectors, or isolate in a sacrificial proxy with no privileges |
| Return-bomb / unbounded returndata | calling untrusted contract can return huge data, griefing gas | `excessivelySafeCall` pattern (nomad-xyz/ExcessivelySafeCall) or cap returndata read |

## 4. Arithmetic
| Risk | Spot it | Safe pattern |
|---|---|---|
| Overflow/underflow | Solidity ≥0.8.0 reverts by default — check pragma. `unchecked{}` blocks bypass this | Only use `unchecked` where overflow is provably impossible (documented with a comment) and gas matters; verify bounds first |
| Precision loss / division before multiplication | `a / b * c` pattern | Multiply before dividing; round in the protocol's favor (usually against the user, in favor of the pool) |
| Rounding direction exploitable | rounds down when should round up (or vice versa) on shares/debt calc, exploitable via repeated small ops | Explicitly choose rounding per OZ `Math.Rounding` (Up for debt owed to protocol, Down for shares paid out) |
| Type casting truncation | downcast `uint256 → uint128/uint96/uint32` without range check | OZ `SafeCast` |
| Off-by-one in loop/array bounds | `<=` vs `<` on array length | Standard fuzzing/unit test on boundary indices |

## 5. Oracle Manipulation / TWAP
| Risk | Spot it | Safe pattern |
|---|---|---|
| Spot price from AMM reserves used directly | `getReserves()` or `balanceOf(pool)` used as price | Never; single-block flash-loan-manipulable |
| Single-source oracle | one Chainlink feed / one DEX pool, no fallback | Multiple sources + sanity bounds (deviation check between sources), circuit breaker on stale/out-of-range price |
| Chainlink feed staleness/round not checked | `latestRoundData()` return ignored except `answer` | Check `updatedAt` freshness, `answeredInRound >= roundId`, and `answer > 0` |
| TWAP window too short | Uniswap V3 TWAP < ~30 min, cheap to manipulate across a few blocks with capital | Use ≥30 min TWAP window (cost scales with duration); consider Uniswap V3 oracle + a secondary source |
| Manipulable LP token price (`get_virtual_price`-style) used as collateral value | grep for LP token pricing feeding into a lending/collateral calc | Use a purpose-built LP oracle (e.g. Chainlink's LP token feeds) that accounts for reentrancy and manipulation, not raw pool math |

## 6. Approvals
| Risk | Spot it | Safe pattern |
|---|---|---|
| `approve()` race condition (front-run allowance change) | direct `approve()` to change a nonzero allowance | `safeIncreaseAllowance`/`safeDecreaseAllowance` (OZ `SafeERC20`), or `permit` (avoids the race by construction) |
| Unlimited/infinite approvals held by protocol contracts | `type(uint256).max` approvals stored long-term | Prefer per-tx `permit` (EIP-2612) so no standing allowance exists; if standing approval required, document as accepted risk and support revocation UX |
| Missing `SafeERC20` on non-standard tokens | direct `IERC20.transfer`/`transferFrom` calls, no return-value check | OZ `SafeERC20` — handles tokens that don't return bool (USDT-style) and reverts on failure |
| Fee-on-transfer / rebasing token breaks accounting | assumes `amount` sent == `amount` received | Measure balance before/after transfer instead of trusting the input amount, or explicitly disallow such tokens |
| `permit` griefing / replay across chains | no `chainId`/domain separator, or missing deadline check | Use EIP-2612-compliant `permit` w/ EIP-712 domain incl. chainId; always check `deadline` |

## 7. Signatures & Replay
| Risk | Spot it | Safe pattern |
|---|---|---|
| Missing nonce → replay same signature multiple times | `ecrecover` used to authorize an action with no nonce/used-hash tracking | Track nonces per signer (OZ `Nonces`) or mark hash as consumed in storage |
| Cross-chain replay | signed message doesn't include `chainId` | Include `chainId` in the signed struct, or use EIP-712 domain separator (binds to chain + contract + name/version) |
| Signature malleability | raw `ecrecover` without `s`-value / `v` range check | OZ `ECDSA.recover` (rejects malleable `s`, validates `v`) — never hand-roll `ecrecover` |
| No domain separator / raw hash signing | `keccak256(abi.encodePacked(...))` signed directly, no typed structure | EIP-712 (`EIP712` + `_hashTypedDataV4`) so signed data is human-readable in wallets and domain-bound |
| Signature front-running (griefing, not theft) | anyone can submit a valid sig they observed in mempool, causing revert/DoS for intended relayer | Design so front-running the tx doesn't harm the signer (e.g. idempotent, or benefits go to intended recipient regardless of submitter) |

## 8. Upgradeability & Storage Layout
| Risk | Spot it | Safe pattern |
|---|---|---|
| Storage collision across upgrade | new version reorders/inserts/changes type of existing state vars | Use OZ Upgrades plugin (`@openzeppelin/hardhat-upgrades` / `foundry-upgrades`) storage-layout diff check in CI; only *append* new vars, never reorder/remove |
| Missing storage gaps (transparent/UUPS non-namespaced) | no `uint256[50] private __gap;` in upgradeable base contracts, base contract adds a var later | Include gaps in every upgradeable base, or use ERC-7201 namespaced storage (OZ 5.x default) to eliminate the issue |
| Uninitialized implementation contract | logic contract's `initialize()` never called/locked, callable directly | `_disableInitializers()` in constructor of the implementation |
| Constructor logic in upgradeable contract | `constructor` sets state that should be in `initialize()` | Constructors only for immutable/no-storage-effect logic in upgradeable contracts; state setup goes in `initialize` |
| Function selector clash (UUPS/diamond) | two functions across proxy/implementation or diamond facets share a 4-byte selector | Selector-clash checker (e.g. Slither's `function-id-collision`); avoid diamond pattern unless team has strong tooling |
| Unprotected `upgradeTo`/`upgradeToAndCall` | UUPS `_authorizeUpgrade` missing or not access-controlled | OZ `UUPSUpgradeable` requires overriding `_authorizeUpgrade` — verify it's gated `onlyOwner`/role |

## 9. DoS / Gas
| Risk | Spot it | Safe pattern |
|---|---|---|
| Unbounded loop over user-growable array | `for` loop over array that users can push into (e.g. all depositors) | Pull-based accounting, pagination, or cap array size |
| Revert-triggered DoS on shared batch op | one recipient's `.transfer` reverting (e.g. contract with no `receive`) blocks payout to everyone else | Pull-over-push pattern; isolate each recipient's claim |
| Block gas limit griefing | attacker inflates state (e.g. tiny deposits) to grow a loop until it always exceeds gas limit | Bound iteration count or move to O(1) accounting (accumulator pattern, not per-user loop) |
| Griefing via failed external call blocking critical path | admin/critical function calls out to an untrusted contract that can revert | Isolate untrusted calls behind try/catch or a separate non-blocking step |

## 10. Front-Running / MEV
| Risk | Spot it | Safe pattern |
|---|---|---|
| No slippage protection on swaps | `amountOutMin = 0` or missing entirely | Always require caller-supplied `minAmountOut`/`maxAmountIn` + deadline |
| Missing deadline on time-sensitive tx | swap/permit fn with no `deadline` param | Add `deadline` and check `block.timestamp <= deadline` |
| Sandwich-able on-chain price-dependent action | any action whose payout depends on spot AMM price, executed without slippage bound | Same as above — bound the acceptable price range explicitly |
| Commit-reveal absent where ordering matters (e.g. auctions, reveal games) | value/outcome depends on being first/last in a block | Commit-reveal scheme, or use a private mempool / MEV-protected RPC as a mitigation layer (not a substitute for on-chain bounds) |
| First-depositor / share-price manipulation (ERC-4626 inflation attack) | vault mints shares 1:1 pre-liquidity, attacker deposits 1 wei then donates assets directly to inflate `pricePerShare`, rounds later depositors to 0 shares | OZ `ERC4626` decimals offset (virtual shares/assets) mitigation, or require minimum initial deposit burned to a dead address |

## Quick triage order for a subagent
1. Static pass: Slither (`slither .`) + note all High/Medium.
2. Access control matrix: list every state-mutating external/public fn × required role.
3. Trace every external call site for CEI + reentrancy guard coverage (esp. anything touching AMM/LP pricing → read-only reentrancy).
4. Oracle/price inputs: identify every price source, check staleness + manipulation resistance.
5. Upgrade path (if proxy): storage layout diff, initializer lock, `_authorizeUpgrade` gate.
6. Value-transfer paths: slippage/deadline params present, `SafeERC20` used, fee-on-transfer handled.
7. Cross-reference findings against DeFiHackLabs PoCs for the same pattern class before writing up.

## See also
- knowledge/security/solana-audit-checklist.md
