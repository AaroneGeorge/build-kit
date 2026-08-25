---
title: Reuse Index - How to Use & Extend
description: The crown-jewel index of existing forkable/importable implementations per archetype, and the entry format /scout and /kb-update append to.
applies_to: [solana, evm]
sources:
  - "buidl-kit reuse-first philosophy - knowledge/stack-defaults.md (verified 2026-08-25)"
last_verified: 2026-08-25
---

# Reuse Index

The #1 job of buidl-kit: make **find → evaluate → adapt proven code** the default, and writing from scratch the exception. ~90% of what gets built already exists publicly.

**Reuse posture:** anything public is fair game. Always record **license + audit status** so the builder decides — but do NOT block on them.

## Files (one per archetype)
- `consumer-sites.md` — deposit/escrow/payout, auction (flagship)
- `defi-trading.md` — DEX/AMM, aggregators, vaults, staking
- `launch-mint.md` — launchpads, presales, bonding curves, mints, vesting
- `bots-infra.md` — sniper/copy-trade, Jito/MEV, indexers, price APIs, TG bots
- `wallets-payments.md` — smart wallets, AA, escrow, payments

## Entry format (used by /scout and /kb-update when appending)
```
### <Name> - <one-line what it is>
- Repo/Docs: <url(s)>
- What you get: <program / SDK / frontend / reference impl>
- Chain/stack: <solana+anchor | evm | ts-sdk | next.js ...>
- Audit status: <audited by X | unaudited | partial - cite>
- License: <MIT/Apache-2.0/AGPL/GPL/BUSL/unknown - flag copyleft/BUSL>
- Maintenance: <last commit / releases / stars; mark (re-verify)>
- Fork vs import: <fork-and-adapt | import-as-dep | read-for-reference> + why
- Known pitfalls: <the 1-3 things that bite>
```

## Scoring (how /scout ranks candidates)
1. **Fit** — how close to the need out of the box.
2. **Maintenance** — recent commits/releases, open-issue health.
3. **Audit status** — audited > partially > unaudited.
4. **License** — permissive (MIT/Apache) > copyleft (GPL/AGPL) > BUSL/unknown.
5. **Adaptation effort** — lines to change, integration risks.

## Discipline
- Each file carries `last_verified` in its front-matter; when /kb-update revisits, refresh dates and maintenance signals and re-check that repos still exist.
- Prefer maintained + permissive + audited. Always keep at least one "read-for-reference" implementation per archetype even when you'd import a dep.

## See also
- `knowledge/stack-defaults.md`
- `knowledge/recipes/` (per-archetype 6-hour playbooks)
