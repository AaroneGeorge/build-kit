---
title: Solana Test Frameworks and Minimum-Sufficient Matrix
description: Speed-vs-fidelity comparison of LiteSVM, bankrun, solana-program-test, and test-validator, plus the minimum test matrix and skeletons for a 6-hour build.
applies_to: [solana, evm]
sources:
  - "LiteSVM docs - https://www.litesvm.com/ (verified 2026-08-25)"
  - "LiteSVM GitHub - https://github.com/LiteSVM/litesvm (verified 2026-08-25)"
  - "Anchor LiteSVM testing docs - https://www.anchor-lang.com/docs/testing/litesvm (verified 2026-08-25)"
  - "litesvm npm package - https://www.npmjs.com/package/litesvm (verified 2026-08-25)"
  - "solana-bankrun (DEPRECATED Mar 2025) - https://kevinheavey.github.io/solana-bankrun/ (verified 2026-08-25)"
  - "Foundry fork testing - https://getfoundry.sh/forge/tests/fork-testing/ (verified 2026-08-25)"
  - "Metaplex Amman - https://github.com/metaplex-foundation/amman (verified 2026-08-25)"
last_verified: 2026-08-25
---

# Solana test frameworks and the minimum-sufficient matrix

## TL;DR (reuse-first)
- **Default to LiteSVM** for all unit/integration tests of program logic. In-process SVM, no validator process, sub-second runs. MIT-licensed, actively maintained (`litesvm` 0.9.x as of 2026-08).
- **`solana-bankrun` / `anchor-bankrun` are DEPRECATED (March 2025)** — do not start new projects on them. If you inherit a repo using them, port to LiteSVM rather than extend.
- **`solana-test-validator`** only when you need real RPC surface, real cluster behavior (rent/leader schedule/vote accounts), CPI to programs you can't easily load into LiteSVM, or a pre-deploy smoke test.
- **Amman** (Metaplex) is a thin wrapper around `solana-test-validator` for Metaplex-heavy stacks (NFT/cNFT) — only pull it in if you're already deep in Metaplex tooling; otherwise plain `solana-test-validator` + `@solana/kit` is less indirection.
- **`solana-program-test`** (Rust, BanksClient-based) still works but LiteSVM is faster to compile/run and is what new Anchor docs point to — prefer LiteSVM unless you have an existing `solana-program-test` suite that isn't worth migrating mid-sprint.

## Speed vs fidelity table

| Framework | Language | Startup | Per-test speed | Fidelity to mainnet | Use when |
|---|---|---|---|---|---|
| **LiteSVM** | Rust, TS/JS, Python | instant (in-process) | ms | High for program logic; no real gossip/leader/vote; sysvars mockable | Default for almost everything: happy path, auth, arithmetic, state machine tests |
| `solana-program-test` | Rust | ~1-2s (spins BanksServer) | 10s-100s of ms | High, closer to bankrun-era validator internals | Legacy Rust suites already using it; CPI-heavy programs not yet supported by LiteSVM |
| `anchor-bankrun` / `solana-bankrun` | TS + Rust | fast | fast | Similar to program-test | **Do not use for new work — deprecated.** |
| `solana-test-validator` | any (RPC) | 2-5s cold start | slow (real slots/blocks) | Highest short of mainnet — real RPC, real rent, real vote/clock behavior | 1 integration/fork-style test per feature; pre-deploy smoke test; testing wallet/CLI/RPC-dependent flows |
| Amman | TS wrapper on test-validator | same as test-validator + explorer overhead | slow | Same as test-validator | Metaplex NFT/cNFT-heavy repos wanting the Amman explorer/relay |
| Devnet | n/a | n/a | slowest (network) | Real cluster, fake money | Final pre-mainnet smoke test only — flaky, rate-limited, not for CI gating |

Rule of thumb: **LiteSVM for 90%+ of tests, one `solana-test-validator` (or devnet) run for the "does this actually work against something RPC-shaped" smoke test.**

## Minimum-sufficient matrix for a 6-hour build

Do not skip categories to save time — skip *volume* within a category instead. For each instruction/handler in the program, cover:

| Category | What to cover | Skip only if |
|---|---|---|
| **Happy path** | One test per instruction with valid inputs, asserting resulting account state + emitted values | Never skip |
| **Auth/permission boundary** | Every `has_one`, `signer`, PDA-seeds-derived authority, and `Access-Control` check — call with the *wrong* signer/authority and assert it fails with the expected error | Never skip — this is the #1 exploited class (see `knowledge/security/solana-audit-checklist.md`) |
| **Arithmetic edge** | Overflow/underflow at boundaries (0, `u64::MAX`, exact-divide-by-zero), fee/rounding direction, off-by-one on loop bounds | Never skip if any `+`, `-`, `*`, `/`, or checked_* math touches user-controlled or lamport/token amounts |
| **State transition** | Every enum/status field: valid transitions succeed, invalid transitions (double-claim, claim-before-init, close-after-close) are rejected | Never skip if program has any status/lifecycle field |
| **Fork/integration** | One end-to-end test against `solana-test-validator` (or a forked mainnet state if you depend on an external program/oracle) exercising the full client → program path | Only skip if truly zero external program deps AND shipping a throwaway prototype — otherwise keep it minimal (1 test) but present |

For a 6-hour build this is typically **15-40 LiteSVM tests + 1 validator/fork test**, not hundreds — density over volume. Each test should assert on-chain state via `get_account`/`getAccountInfo` deserialization, not just "tx didn't throw."

## Minimal LiteSVM skeleton — TypeScript (Anchor)

```ts
import { LiteSVM } from "litesvm";
import { fromWorkspace, LiteSVMProvider } from "anchor-litesvm";
import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Keypair, PublicKey, LAMPORTS_PER_SOL } from "@solana/web3.js";
import { MyProgram } from "../target/types/my_program";

describe("my_program", () => {
  const svm = fromWorkspace("."); // loads target/deploy/*.so + genesis accounts
  const provider = new LiteSVMProvider(svm);
  anchor.setProvider(provider);
  const program = anchor.workspace.MyProgram as Program<MyProgram>;

  const admin = Keypair.generate();
  const attacker = Keypair.generate();

  beforeEach(() => {
    svm.airdrop(admin.publicKey, BigInt(10 * LAMPORTS_PER_SOL));
    svm.airdrop(attacker.publicKey, BigInt(10 * LAMPORTS_PER_SOL));
  });

  it("happy path: initializes vault", async () => {
    await program.methods.initialize().accounts({ admin: admin.publicKey }).signers([admin]).rpc();
    const vault = await program.account.vault.fetch(vaultPda);
    expect(vault.admin).toEqual(admin.publicKey);
  });

  it("auth boundary: non-admin cannot withdraw", async () => {
    await expect(
      program.methods.withdraw(new anchor.BN(1)).accounts({ authority: attacker.publicKey }).signers([attacker]).rpc()
    ).rejects.toThrow(/Unauthorized|has_one/);
  });

  it("arithmetic edge: withdraw more than balance fails", async () => {
    await expect(
      program.methods.withdraw(new anchor.BN(u64Max)).accounts({ authority: admin.publicKey }).signers([admin]).rpc()
    ).rejects.toThrow(/overflow|InsufficientFunds/);
  });

  it("state transition: cannot close an already-closed vault", async () => {
    await program.methods.close().accounts({ authority: admin.publicKey }).signers([admin]).rpc();
    await expect(
      program.methods.close().accounts({ authority: admin.publicKey }).signers([admin]).rpc()
    ).rejects.toThrow(/AccountNotInitialized|already in use/);
  });
});
```

## Minimal LiteSVM skeleton — Rust

```rust
use litesvm::LiteSVM;
use solana_sdk::{signature::{Keypair, Signer}, transaction::Transaction, system_instruction};

#[test]
fn happy_path_transfer() {
    let mut svm = LiteSVM::new();
    let payer = Keypair::new();
    svm.airdrop(&payer.pubkey(), 10_000_000_000).unwrap();

    let program_id = load_program(&mut svm); // svm.add_program_from_file(id, "target/deploy/my_program.so")
    let ix = build_init_ix(program_id, payer.pubkey());
    let tx = Transaction::new_signed_with_payer(
        &[ix], Some(&payer.pubkey()), &[&payer], svm.latest_blockhash(),
    );
    let result = svm.send_transaction(tx).unwrap();
    assert!(result.logs.iter().any(|l| l.contains("Initialized")));
}

#[test]
fn auth_boundary_wrong_signer_rejected() {
    let mut svm = LiteSVM::new();
    let attacker = Keypair::new();
    svm.airdrop(&attacker.pubkey(), 10_000_000_000).unwrap();
    // ...build withdraw ix signed by attacker instead of admin...
    let err = svm.send_transaction(tx).unwrap_err();
    assert!(format!("{err:?}").contains("custom program error")); // match your specific error code
}
```

Notes:
- `svm.expire_blockhash()` / `svm.warp_to_slot(n)` to test time-dependent logic (vesting, cooldowns) without real clock waits.
- `svm.set_account(pubkey, account)` to seed arbitrary account state (e.g., a pre-existing token account) without running the real setup instructions.
- For CPI to well-known programs (SPL Token, Token-2022, Associated Token Account), `litesvm-token` / `anchor-litesvm` ship pre-loaded program binaries — don't hand-roll loading `.so` files for these.

## One fork/integration test — `solana-test-validator`

```bash
solana-test-validator --reset \
  --bpf-program <PROGRAM_ID> target/deploy/my_program.so \
  --clone <EXTERNAL_PROGRAM_ID> --url mainnet-beta &
```
Then in TS, point `@solana/kit`/`Connection` at `http://127.0.0.1:8899` and run one full client-flow test (build ix → send → confirm → refetch state). This is your "does the real RPC/CPI path work" gate before devnet/mainnet — keep it to 1 test, not a parallel full suite.

## EVM (secondary): Foundry

- `forge test` is the default — fast, in-process EVM (revm), fuzzing and invariant testing built in via `forge-std`/`forge test --fuzz-runs`.
- **Fork test** for any integration with live protocols (Uniswap, Aave, oracles): use `vm.createFork(rpcUrl)` / `--fork-url` so tests run against real on-chain state. Foundry caches fork data at `~/.foundry/cache/rpc/<chain>/<block>` — commit to a pinned block number for reproducibility.
```solidity
function test_liquidation_against_mainnet_fork() public {
    uint256 forkId = vm.createFork(vm.envString("MAINNET_RPC_URL"), 18_500_000);
    vm.selectFork(forkId);
    // ... exercise real Aave/Compound pool ...
}
```
- Apply the same matrix: happy path, every `onlyOwner`/`require(msg.sender==...)` boundary, arithmetic edges (post-0.8 checked math still needs edge tests for intended-behavior over/underflow in unchecked blocks), every state enum transition, one fork test. See `knowledge/evm/foundry-and-patterns.md` for patterns/cheatcodes.

## Do / Don't

| Do | Don't |
|---|---|
| Default new Solana test suites to LiteSVM | Start a new suite on `solana-bankrun`/`anchor-bankrun` (deprecated) |
| Write one test per auth check, named for what it rejects | Bundle all auth checks into one giant "security test" that's hard to diff on failure |
| Assert on decoded account state, not just tx success | Assert only `expect(tx).resolves` with no state check |
| Use `svm.warp_to_slot`/`expire_blockhash` for time logic | Add real `sleep()`/`setTimeout` waits in tests |
| Keep exactly 1 validator/fork integration test as a gate | Run the full matrix against `solana-test-validator` (slow, flaky in CI) |
| Pin fork tests to a specific block number | Fork against "latest" (non-reproducible, breaks silently as chain state moves) |

## See also
- `knowledge/testing/fuzz-and-invariants.md` — the layer above this matrix: property fuzzing + stateful invariants (Foundry, Echidna, Trident) for fund-conservation and share-accounting paths
- `knowledge/security/solana-audit-checklist.md` — what the auth/arithmetic edge tests above are guarding against
- `knowledge/solana/anchor-idioms.md` — account constraint patterns these tests exercise
- `knowledge/solana/tx-landing.md` — transaction construction used in fork/integration tests
- `knowledge/evm/foundry-and-patterns.md` — Foundry cheatcodes and patterns in more depth
