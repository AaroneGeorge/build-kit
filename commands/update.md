---
description: Update buidl-kit to the latest main from GitHub - with a check-only mode, a changelog of what changed, and protection for locally edited knowledge files.
argument-hint: "[check]"
allowed-tools: Read, Grep, Glob, Bash
---

You are running **/update**, buidl-kit's self-updater. Mode: $ARGUMENTS (`check` = report only, touch nothing; default = update). Upstream is `https://github.com/AaroneGeorge/build-kit` branch `main`. The marketplace entry is unpinned, so updating the marketplace delivers latest main.

## Process
1. **Detect the install type** from `${CLAUDE_PLUGIN_ROOT}`:
   - Contains `.git` → **local clone install** (the builder's own working tree).
   - Otherwise → **marketplace cache install** (a copied directory under `~/.claude/plugins/`).
2. **Fetch upstream** into a temp dir: `git clone --depth 50 https://github.com/AaroneGeorge/build-kit.git <tmp>`. Get the latest SHA (`git -C <tmp> rev-parse --short HEAD`).
3. **Compare** the installed tree against `<tmp>` (`diff -rq`, excluding `.git`). Identical → report "up to date at <sha>" and stop.
4. **Report what changed** (both modes): group differing files by area — commands / agents / skills / knowledge / other — as added, changed, removed. Use `<tmp>`'s `git log --oneline -15` to summarize recent upstream commits. **If mode is `check`, stop here.**
5. **Protect local edits.** Files that differ under `knowledge/` may be the builder's own customizations (the README encourages editing them — reuse-index entries, stack-defaults, checklists). List them, ask which are intentional edits, and copy those to `~/.claude/buidl-kit-backup-<date>/` (preserving paths) before updating. Never silently overwrite a customized knowledge file.
6. **Update:**
   - *Marketplace cache install:* run `claude plugin marketplace update buidl-kit-marketplace` then `claude plugin update buidl-kit@buidl-kit-marketplace` via Bash. If the `claude` CLI isn't available or errors, fall back to telling the builder to run `/plugin marketplace update buidl-kit-marketplace` themselves. Do NOT hand-edit the cache directory — it gets replaced on the next refresh.
   - *Local clone install:* `git -C ${CLAUDE_PLUGIN_ROOT} pull --ff-only origin main`. If local commits/dirty files block the fast-forward, stop and show `git status` — never force, never stash without asking.
7. **After updating:** offer to re-apply the backed-up knowledge edits on top of the new files (merge, don't clobber — e.g. re-append their reuse-index entries). Then tell the builder to run **`/reload-plugins`** (required for changes to take effect) and clean up `<tmp>`.

## Rules
- `check` mode is strictly read-only.
- Never delete or overwrite the builder's backups; print the backup path in the final report.
- End with: previous → new SHA, the area-grouped changelog, backup location (if any), and the `/reload-plugins` reminder.
