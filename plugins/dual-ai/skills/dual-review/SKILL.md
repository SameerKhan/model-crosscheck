---
name: dual-review
description: Dual code review — run Claude's /code-review AND OpenAI Codex CLI review on the same diff, then merge both into one consolidated report. Use when the user says "dual review", "review with both", "Claude + ChatGPT review", or before a merge when they want two independent reviewers.
---

# Dual review (Claude + Codex/ChatGPT)

Two independent reviews of the same diff, merged into one report. The value is
in the merge: agreement between two different models is a strong signal;
disagreement tells the user where to look manually.

## Steps

1. **Determine diff scope.**
   - Branch has commits vs the main branch (check the repo's CLAUDE.md for
     which branch is the trunk — it is not always `main`): scope =
     `origin/<trunk>...HEAD`, Codex flag = `--base origin/<trunk>`. Run `git fetch` first
     and give both reviewers the SAME ref — a stale local trunk vs
     `origin/<trunk>` silently produces two different diffs.
   - Only uncommitted working-tree changes: Codex flag = `--uncommitted`,
     and review the working-tree diff on the Claude side.
   - Both committed AND uncommitted changes: `--base` and `--uncommitted`
     are mutually exclusive, so don't pick silently — ask the user to
     commit/stash first, or review the committed scope and state explicitly
     that uncommitted edits are excluded.

2. **Start the Codex review in the background** (it takes several minutes):

   ```bash
   codex exec -s read-only review --base origin/<trunk> -c model_reasoning_effort="high"
   # or: codex exec -s read-only review --uncommitted -c model_reasoning_effort="high"
   ```

   Run via Bash with `run_in_background: true`. Always pass
   `-s read-only` — the user's `~/.codex/config.toml` may default to a
   write-enabled sandbox, and a reviewer must never touch the tree. Always
   override reasoning effort to `high` — a low default is too weak for
   review. If the sandbox blocks network access, grant network to the
   sandboxed run; never disable the sandbox for a review.

3. **While Codex runs, invoke `/code-review` at high effort** on the same scope.

4. **Merge the findings** once both are done:
   - **Agreed** (both flagged the same issue): report first — highest confidence.
   - **Claude-only**: report as normal /code-review findings.
   - **Codex-only**: verify each against the actual code before reporting;
     mark CONFIRMED or REJECTED (with the reason). Never relay a Codex finding
     unverified.
   - Dedupe by file + line + issue.

5. **Rebuttal round — a refuted finding gets a defense.** If any Codex
   findings were REJECTED in step 4, send Codex ONE follow-up
   (`codex exec`, read-only) containing each rejected finding plus the
   refutation evidence, asking it to CONCEDE or DEFEND each with code
   citations. Concede → drop silently. Defend → re-examine once; if you still
   disagree, include it in the report as **[disputed]** with both positions
   and your recommendation — the user rules, same as dual-plan's deadlock
   rule. One rebuttal round only (reviews are expensive; the diff, unlike a
   plan, doesn't change mid-review). Skip this step entirely when nothing
   was rejected.

6. **Report one consolidated list**, most severe first, tagging each finding
   with who found it: `[both]`, `[claude]`, `[codex]`, or `[disputed]`.
   Never omit a disputed finding.

## Notes

- Requires the OpenAI Codex CLI (`codex`) installed and authenticated
  (`codex login`). Don't change the user's global `~/.codex/config.toml`;
  use `-c` overrides only.
- Check which model `~/.codex/config.toml` pins. Effort `high` on a
  small/mini model still yields a shallow reviewer — and the merge logic
  would then treat "Codex found nothing" as an independent signal. If a mini
  model is pinned, override it for the review via `-c model=...`.
- macOS + Codex desktop app: if `codex` is a symlink into the app bundle,
  the sibling helper `codex-code-mode-host` must be symlinked into the same
  directory too — codex resolves that helper next to the invoked binary, and
  without it every run fails with "failed to spawn code-mode host" and
  returns a useless provisional verdict. If you hit that error, recreate both
  symlinks and re-run. Check where `codex` actually points with `ls -l`
  rather than assuming: as of 2026-07 it resolves to
  `/Applications/ChatGPT.app/Contents/Resources/codex`, not `Codex.app`.
- Codex reads `AGENTS.md` for project context automatically. If the repo
  only has a CLAUDE.md, consider keeping an `AGENTS.md` copy so both models
  see the same ground rules.
- If Codex reports an auth error, tell the user to re-login (app or
  `codex login`) — do not attempt to fix auth yourself.
