---
name: dual-review
description: Dual code review — run Claude's /code-review AND OpenAI Codex CLI review on the same diff, then merge both into one consolidated report. Use when the user says "dual review", "review with both", "Claude + ChatGPT review", or before a merge when they want two independent reviewers.
---

# Dual review (Claude + Codex/ChatGPT)

Two independent reviews of the same diff, merged into one report. The value is
in the merge: agreement between two different models is a strong signal;
disagreement tells the user where to look manually.

## Model per leg — pin both

| Leg | Model | Where it's set |
|---|---|---|
| **Claude** (verification + merge) | the newest top-tier Claude available (2026-09: Fable 5.1, then Fable 5, then Opus 5) | the session model — see below |
| Codex | the CLI's default under config isolation — read the `model:` line Codex prints at startup; `-c model=...` to override | `--ephemeral --ignore-user-config -s read-only`, effort forced to `high` |

The Claude leg holds the repo context, verifies Codex's findings, and writes
the merge, so it must not be the cheap seat. Check the active model (stated
in the session's environment context; `/status` confirms it) before step 1:
on a top-tier Claude (Fable/Opus-class) at least as new as the dated example
→ proceed — newer also passes, the example is a floor, not a pin, and a
`[1m]` context-window suffix is the same model. On a fast/cheap tier
(Haiku/Sonnet-class) or an older top tier → stop, say which model the
Claude leg would run on, and ask the user to switch via `/model` and
re-invoke. Pin any subagent explicitly — `subagent_type` (Agent tool) or
`agentType` (Workflow scripts) without `model` inherits that agent
definition's own model.

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
   codex exec --ephemeral --ignore-user-config -s read-only review --base origin/<trunk> -c model_reasoning_effort="high"
   # or: codex exec --ephemeral --ignore-user-config -s read-only review --uncommitted -c model_reasoning_effort="high"
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

- **Cross-platform:** the snippets above are bash/zsh, but this skill runs
  only `git` and `codex` commands — both identical on Windows. The one
  translation needed is the config path: `~/.codex/config.toml` is
  `$env:USERPROFILE\.codex\config.toml` in PowerShell — or
  `$env:CODEX_HOME\config.toml`, since `CODEX_HOME` names the directory, not
  the file.
  The `codex-code-mode-host` symlink trap below is macOS-only.
- Requires the OpenAI Codex CLI (`codex`) installed and authenticated
  (`codex login`). Don't change the user's global `~/.codex/config.toml`;
  use `-c` overrides only.
- Under config isolation your `~/.codex/config.toml` model pin does **not**
  apply — the CLI's built-in default runs unless you pass `-c model=...`.
  Codex prints `model: <name>` in its startup header on every run: read it
  off the first lines of the leg's output, and if it is a mini/small tier,
  re-run with `-c model=<your flagship>` (and pass that explicitly from then
  on — the default tracks the CLI release, not your choice). Effort `high`
  on a small model still yields a shallow reviewer — and the merge logic
  would then treat "Codex found nothing" as an independent signal.
- **`-s read-only` sandboxes the shell, not MCP** — which is why the step 2
  command also passes `--ephemeral --ignore-user-config`. Without them, a
  `~/.codex/config.toml` that wires MCP servers (databases, billing, mail)
  boots that fleet while Codex parses an untrusted diff. Auth still works
  (`--ignore-user-config` skips only `config.toml`), and `--ephemeral` also
  keeps the diff out of persisted session files. With the config skipped its
  pins no longer apply, so keep effort explicit and add `-c model=...` if
  the CLI's default model isn't the one you want reviewing.
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
