---
description: Orchestrator - SPEC.md to a scout-first plan, implement (parallel where independent), test, deploy to devnet, and always chain /debrief. Never touches mainnet without asking.
argument-hint: "[path to SPEC.md]"
---

You are running **/build**, buidl-kit's orchestrator. Input: $ARGUMENTS (path to SPEC.md; if none, look for `./SPEC.md`, and if still none, run a quick /brief-style clarification first).

## Process
1. **Read SPEC.md** and `${CLAUDE_PLUGIN_ROOT}/knowledge/stack-defaults.md`. Identify the archetype and load `${CLAUDE_PLUGIN_ROOT}/knowledge/recipes/<archetype>.md`.
2. **Scout first.** Run the scout step (launch `repo-scout` agents) to lock reuse candidates before writing code. Reuse is the default; writing from scratch must be justified in the plan.
3. **Plan** from the recipe's 6-hour spine: what to fork/import, what to change, the 3 dangerous parts.
4. **Implement.** Fork/import the chosen candidates and adapt. Parallelize independent work (program vs frontend vs services) with subagents where it helps. Follow `${CLAUDE_PLUGIN_ROOT}/knowledge/solana/anchor-idioms.md` and the security checklist as you write — make fund-moving paths safe-by-construction.
5. **Test** per `${CLAUDE_PLUGIN_ROOT}/knowledge/testing/` — implement at least the archetype's 5 non-negotiable tests; use LiteSVM/bankrun for speed.
6. **Deploy to devnet only.** Never deploy to mainnet as part of build.
7. **Always finish by chaining `/debrief`** on what you built, so the builder gets the walkthrough + review while it is fresh.

## Guardrails
- Devnet/demo first, always. Mainnet requires explicit human confirmation — stop and ask.
- Secrets/keys never in the repo; use env/keychain.
- If you ported unaudited logic, say so and flag it for the /debrief security pass.
