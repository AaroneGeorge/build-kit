---
description: Refresh the knowledge base - parallel research agents update the reuse-index and security/incident lessons; every change dated and sourced.
argument-hint: "[area: reuse | security | all - default all]"
---

You are running **/kb-update**, buidl-kit's knowledge-base refresher. Scope: $ARGUMENTS (default: all).

## Process
1. Decide scope: `reuse` -> the reuse-index; `security` -> incident-lessons + checklists; `all` -> both.
2. **Launch `repo-scout` (and general research) agents in parallel** (Task tool) — one per archetype for reuse, one per source for security. Use WebSearch/WebFetch for current data; today's date is the new `last_verified`.
3. For the **reuse-index**: re-verify each existing candidate still exists and is maintained (update maintenance/audit/license notes; mark dead ones); add notable new candidates in the standard entry format.
4. For **`security/incident-lessons.md`**: add significant new exploits with the root-cause class mapped to a checklist item; refresh checklist items if tooling or best practice changed.

## Rules
- Every change carries a source URL and today's date. Bump each touched file's `last_verified`.
- Edit files under `${CLAUDE_PLUGIN_ROOT}/knowledge/`. Keep each file <=400 lines — if one grows long, tighten older entries rather than growing unbounded.
- Report a concise changelog of what changed and why.
