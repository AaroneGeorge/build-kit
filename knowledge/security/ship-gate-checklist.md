---
title: /ship Advisory Pre-Deploy Gate
description: The advisory gate checklist + deploy runbook that /ship runs before a deploy. Criticals surface loudly; never blocking.
applies_to: [solana, evm]
sources:
  - "Anchor deploy/upgrade docs - https://www.anchor-lang.com/ (verified 2026-08-25)"
  - "solana-verify (verifiable builds) - https://github.com/Ellipsis-Labs/solana-verifiable-build (verified 2026-08-25)"
  - "Solana program deployment docs - https://solana.com/docs (verified 2026-08-25)"
  - "knowledge/security/solana-audit-checklist.md (verified 2026-08-25)"
last_verified: 2026-08-25
---

# /ship — Advisory Pre-Deploy Gate

**How to read this:** advisory, not blocking. List CRITICAL/HIGH findings loudly at the TOP of the /ship report; never silently pass them; never stop the builder. Mainnet steps require explicit human confirmation.

## 0. Critical banner (always first)
- Re-run a fresh security pass on the DIFF (`solana-security-auditor` / `evm-security-auditor`).
- Restate any CRITICAL/HIGH from the latest `DEBRIEF.md` that are still open.
- If funds can move, name every instruction/function that moves them and its guard.

## 1. Secrets & keys
- [ ] No private keys, mnemonics, or API keys in the repo or client bundle (grep for keypair JSON, `PRIVATE_KEY`, `mnemonic`).
- [ ] All secrets via env / keychain; `.env*` gitignored.
- [ ] Frontend exposes only keys/RPC intended to be public.

## 2. Program authority & verification (Solana)
- [ ] Upgrade authority known and intended (multisig/Squads for mainnet; document who holds it).
- [ ] Upgradeable vs immutable decided before mainnet; immutable is a one-way door.
- [ ] Verifiable build (`solana-verify`) planned for mainnet so on-chain bytecode matches source.
- [ ] `declare_id!` matches the deployed program id per cluster.

## 3. Security criticals (condensed — full list in `solana-audit-checklist.md`)
- [ ] Every fund-moving ix checks **signer + owner + PDA seeds/bump**.
- [ ] Arithmetic **checked** (no raw `+ - *` on balances/supply).
- [ ] No **arbitrary CPI / account substitution** on privileged paths.
- [ ] **Token-2022** mints handled or rejected (transfer-fee / hook / permanent-delegate).
- [ ] Oracle/price inputs validated (staleness, confidence).

## 4. Tests & build
- [ ] Program builds; tests green (per `knowledge/testing/`).
- [ ] The 5 per-archetype non-negotiable tests exist and pass.

## 5. Monitoring & ops
- [ ] Error/latency monitoring on the send path; alert on failed landings.
- [ ] RPC fallback configured; rate limits understood.
- [ ] Rollback / pause plan (admin switch or upgrade path) documented.

## Deploy runbook

### Devnet/demo (default — do this now)
1. `solana config set --url devnet`
2. `anchor build && anchor deploy` (fund from the devnet faucet).
3. Save the program id; update `declare_id!` + `Anchor.toml` if needed; rebuild.
4. Run integration tests against devnet.

### Mainnet (LATER — requires explicit confirmation)
> Never run mainnet steps without the builder's explicit "yes, mainnet." State this and stop for confirmation.
1. Fund a dedicated deploy keypair (hardware/keychain).
2. Verifiable build: `solana-verify build`.
3. `anchor deploy --provider.cluster mainnet` (or `solana program deploy`).
4. Set upgrade authority to multisig (Squads) or set immutable.
5. `solana-verify verify-from-repo` to publish verification.
6. Smoke-test with tiny amounts; enable monitoring; then announce.

## See also
- `knowledge/security/solana-audit-checklist.md`
- `knowledge/security/evm-audit-checklist.md`
- `knowledge/testing/per-archetype-tests.md`
