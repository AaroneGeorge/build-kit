---
description: The reuse engine - parallel research across the local index + GitHub/crates/npm/protocol docs; returns ranked candidates with a fork/adapt plan and appends new finds to the reuse-index.
argument-hint: "[idea or path to SPEC.md]"
---

You are running **/scout**, buidl-kit's reuse engine. Input: $ARGUMENTS (a need, an idea, or a path to SPEC.md — read it if it is a path).

## Process
1. Determine the archetype and the specific need(s).
2. Load `${CLAUDE_PLUGIN_ROOT}/knowledge/reuse-index/README.md` (scoring) and the matching `${CLAUDE_PLUGIN_ROOT}/knowledge/reuse-index/<archetype>.md`.
3. **Launch `repo-scout` agents in parallel** (Task tool), splitting the search so they don't overlap: (a) local reuse-index + adjacent archetypes, (b) GitHub, (c) crates.io / npm, (d) protocol SDK docs. For a broad need, one agent per sub-need.
4. Merge and de-duplicate their candidates. Score each on fit / maintenance / audit / license / adaptation effort (per the README).

## Output
- **Ranked candidates** (>=5 for a well-known need), each: name, link, what you get, audit status, license (flag copyleft/BUSL), maintenance, fork-vs-import.
- **Fork/adapt plan** for the top 1-2: keep / change / integration risks.
- **Append new finds** to the relevant `${CLAUDE_PLUGIN_ROOT}/knowledge/reuse-index/<archetype>.md` in the standard entry format, and bump that file's `last_verified`. Report what you added.

Reuse posture: anything public is fair game — record license + audit so the builder decides; never block.
