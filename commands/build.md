---
description: Orchestrator - SPEC.md to scout-first vertical slices, each end-to-end, tested, committed, and redeployed to devnet, so there is always a demoable state. Always chains /debrief. Never touches mainnet without asking.
argument-hint: "[path to SPEC.md]"
---

You are running **/build**, buidl-kit's orchestrator. Input: $ARGUMENTS (path to SPEC.md; if none, look for `./SPEC.md`, and if still none, run a quick /brief-style clarification first).

## Process
1. **Read SPEC.md** and `${CLAUDE_PLUGIN_ROOT}/knowledge/stack-defaults.md`. If **`STATE.md`** exists (a /handoff snapshot), read it and resume from its "Next steps" — don't replan what a previous session already decided. Identify the archetype and load `${CLAUDE_PLUGIN_ROOT}/knowledge/recipes/<archetype>.md`.
2. **Scout first.** Run the scout step (launch `repo-scout` agents) to lock reuse candidates before writing code. Reuse is the default; writing from scratch must be justified in the plan.
3. **Plan vertical slices** off the recipe's 6-hour spine: 2–5 thin **end-to-end** slices (program instruction + client call + visible UI change — never a layer like "all models then all views"). Slice 1 is the walking skeleton: the thinnest fund-flow loop, deployable. Name what to fork/import, what to change, and the 3 dangerous parts — assigned to their slices.
4. **Implement slice by slice.** Fork/import the chosen candidates and adapt. Within a slice, parallelize independent work (program vs frontend vs services) with subagents. Follow `${CLAUDE_PLUGIN_ROOT}/knowledge/solana/anchor-idioms.md` and the security checklist as you write — fund-moving paths safe-by-construction. **After each slice: tests green → commit `slice-N: <what demos now>` → redeploy devnet.** Never leave the tree broken between slices — the last green slice is always a demoable state.
5. **Test** per `${CLAUDE_PLUGIN_ROOT}/knowledge/testing/` — fund-path tests land inside their slice; the archetype's 5 non-negotiables are all green by the final slice. Use LiteSVM/bankrun for speed.
6. **Use the Solana Developer MCP when available** (docs search + `program_autofixer`): look up APIs there instead of guessing, and before chaining /debrief run the autofixer over the program in a check → fix → recheck loop until clean. The plugin declares it in `.mcp.json`, so it is available once the builder approved it at install; if its tools aren't in-session anyway, mention `/doctor` diagnoses the connection — then continue without it.
7. **Deploy to devnet only.** Never deploy to mainnet as part of build.
8. **Always finish by chaining `/debrief`** on what you built, so the builder gets the walkthrough + review while it is fresh.

## Guardrails
- Devnet/demo first, always. Mainnet requires explicit human confirmation — stop and ask.
- Secrets/keys never in the repo; use env/keychain.
- If you ported unaudited logic, say so and flag it for the /debrief security pass.
- Long build? Write /handoff's STATE.md at natural pause points so a session loss costs minutes.
