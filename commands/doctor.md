---
description: Environment preflight - verify toolchain versions, wallet, devnet SOL, RPC reachability, and optional boosters before a build burns an hour on drift. Exact fix command for every failure.
argument-hint: "[solana | evm | all - default: infer from the project]"
allowed-tools: Read, Grep, Glob, Bash
---

You are running **/doctor**, buidl-kit's environment preflight. Scope: $ARGUMENTS (default: infer — Anchor.toml/Cargo.toml → solana, foundry.toml/*.sol → evm, both → all, neither → solana, the primary). Toolchain drift — especially Anchor-version mismatch — is the #1 way builds lose their first hour. Run the checks via Bash, parallelizing independent ones. Read `${CLAUDE_PLUGIN_ROOT}/knowledge/stack-defaults.md` for the expected stack.

## Checks

**Core (always)**
- `git --version` · `node --version` (need ≥ 20) · a package manager (`pnpm`/`npm`).

**Solana**
- `solana --version` — installed and recent.
- `anchor --version` — and **match it against the project**: `anchor_version` in `Anchor.toml` and the `anchor-lang` version in `Cargo.toml`. Mismatch = FAIL with the fix: `avm install <ver> && avm use <ver>` (check `avm --version` exists; if not, give the avm install one-liner).
- `rustc --version` — meets the Anchor version's requirement.
- Wallet: `solana config get` → keypair path exists. Missing → `solana-keygen new` (warn it writes a new key; never overwrite an existing one).
- Devnet SOL: `solana balance -u devnet`. Under ~1 SOL → offer `solana airdrop 2 -u devnet` (may need retries; say so).
- RPC reachability: `getHealth` via curl against `$RPC_URL` if set, else the public devnet endpoint. If Helius is expected (stack-defaults) but `HELIUS_API_KEY` is unset, WARN with where to get one — never print a set key's value.

**EVM (when in scope)**
- `forge --version` · `anvil --version` · `cast --version`. Missing → `curl -L https://foundry.paradigm.xyz | bash && foundryup`.

**Boosters (WARN-level, never FAIL)**
- Official Solana Developer MCP available in-session? The plugin declares it in its `.mcp.json`, so it should be connected (free, no key — docs search + program autofixer; /build and /debrief use it when present). If its tools are missing, the builder likely declined it at install: fix via `/mcp` (approve/reconnect `solana-mcp`) or manually `claude mcp add --transport http solana-mcp https://mcp.solana.com/mcp`.
- EVM in scope: `slither --version` / `aderyn --version` — the evm-security-auditor uses them when installed.
- `DATABASE_URL` set if the project uses Neon (WARN if the string isn't the pooled variant).

## Output
A table: check · PASS/WARN/FAIL · found vs expected · **the exact fix command**. End with the verdict: **"safe to /build"**, or the FAILs as an ordered fix list (blockers first). Offer to run the fixes, but never install or overwrite anything without the builder's yes.
