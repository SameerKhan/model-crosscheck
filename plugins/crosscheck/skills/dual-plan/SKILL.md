---
name: dual-plan
description: Plan and build a feature with Claude AND OpenAI Codex together: Claude drafts the implementation plan, Codex critiques it against the codebase, Claude merges and implements after user approval, then /dual-review gates the merge. Use when the user says "dual plan", "plan with both", "plan this with ChatGPT/Codex", or wants both models on a feature.
---

# Dual plan (Claude + Codex/ChatGPT)

Feature workflow with two models: Claude drives, Codex independently
critiques at two gates, the plan and the final diff. The value is
adversarial: Codex is prompted to find what the plan gets wrong, not to
agree with it.

## Model per leg: pin both

| Leg | Model | Where it's set |
|---|---|---|
| **Claude** (plan draft, adjudication, implementation) | the newest top-tier Claude available (2026-09: Fable 5.1, then Fable 5, then Opus 5) | the session model, see below |
| Codex critic | the CLI's default under config isolation, read the `model:` line Codex prints at startup; `-c model=...` to override | `--ephemeral --ignore-user-config -s read-only`, effort forced to `high` |

Claude drafts the plan and rules on the critique, the critic only ever
reacts to what Claude produced, so a weak draft caps the whole run. Check the
active model (stated in the session's environment context; `/status`
confirms it) before step 1: on a top-tier Claude (Fable/Opus-class) at least
as new as the dated example → proceed, newer also passes, the example is a
floor, not a pin, and a `[1m]` context-window suffix is the same model. On
a fast/cheap tier (Haiku/Sonnet-class) or an older top tier → stop, say
which model the Claude leg would run on, and ask the user to switch via
`/model` and re-invoke. Pin any subagent explicitly, `subagent_type`
(Agent tool) or `agentType` (Workflow scripts) without `model` inherits
that agent definition's own model.

## Cross-platform: the snippets below are bash/zsh

On Windows (PowerShell) the stdin redirect breaks outright. Detect the shell
and translate; don't paste the bash form and hope:

| bash/zsh | PowerShell |
|---|---|
| `codex exec ... - < "$PROMPT"` | `Get-Content $prompt \| codex exec ... -`, PowerShell **reserves `<`** and errors on it |
| `PROMPT=$(mktemp)` | `$prompt = (New-TemporaryFile).FullName` |
| `~/.codex/config.toml` | `$env:USERPROFILE\.codex\config.toml` (or `$env:CODEX_HOME\config.toml`, `CODEX_HOME` is the directory, not the file) |

`codex` is on PATH on Windows when installed normally, the
`codex-code-mode-host` symlink trap below is macOS-only. All CLI flags, the
convergence rules, and the round cap are identical on every platform.

## Steps

1. **Scope the feature.** Explore the codebase as usual (respect the repo's
   CLAUDE.md conventions and known landmines). Draft an implementation plan:
   goal, files to touch, approach, data-shape changes, risks, test plan.
   Write it to a scratch file OUTSIDE the repo (plain `mktemp`;
   `(New-TemporaryFile).FullName` on Windows), scratch files inside the
   repo would pollute the later `--uncommitted` review scope or get
   committed by accident, and a fixed name like `/tmp/plan.md` collides
   with a concurrent run and is world-predictable.

2. **Codex critique gate.** Build a critique prompt file containing the plan
   plus instructions, then run Codex read-only in the background (takes
   minutes):

   ```bash
   PROMPT=$(mktemp)
   # write the critique prompt (template below, plan inlined) into "$PROMPT", then:
   codex exec --ephemeral --ignore-user-config -s read-only -c model_reasoning_effort="high" - < "$PROMPT"
   ```

   Pass `-s read-only` explicitly, the user's config may default to a
   write-enabled sandbox, and the critic must never touch the tree.

   Critique prompt template:
   > You are reviewing an implementation plan for this repository (read the
   > code to check every claim; AGENTS.md, or CLAUDE.md if there is no
   > AGENTS.md, has project context, when present). Do NOT
   > implement anything. Find: (1) factually wrong assumptions about the
   > codebase, (2) missed files, call sites, or cross-repo blast radius,
   > (3) simpler alternatives, (4) risks/edge cases the plan ignores,
   > (5) anything in the test plan that wouldn't catch a regression.
   > Be specific, cite file paths. Then give an overall verdict:
   > SOUND / NEEDS-CHANGES with a ranked list.
   >
   > PLAN: <the plan contents, inlined, `codex exec -` reads stdin as its
   > whole prompt, so a path alone is not enough>

3. **Adjudicate and revise.** For each Codex critique point: accept (revise
   the plan) or reject (verify against the code first; never dismiss
   unchecked).

4. **Converge, Codex must sign off on the FINAL plan.** Send the revised
   plan back to Codex for re-critique (same prompt template, plus a
   "previous round's points and how each was addressed or rebutted"
   section). Repeat revise → re-critique until Codex returns **SOUND**, up
   to **3 rounds** total. Do not present a plan to the user that Codex has
   not seen in its final form.
   - If Codex still says NEEDS-CHANGES after round 3, stop looping: present
     the plan WITH the unresolved disagreement as a named decision point,
     each side's position and your recommendation, and let the user rule.
     Never paper over a disagreement to fake consensus, and never keep
     looping past 3 rounds (models can trade nits forever).

5. **User approval.** Present the converged plan with a short "what Codex
   changed / how many rounds" section, the user approves before any code
   is written.

6. **Implement.** Claude writes the code (Claude holds the tools, memory,
   and repo context). Codex does not edit the working tree, two writers on
   one tree causes conflicts.

7. **Close with /dual-review** (the sibling skill) on the finished diff
   before any PR/merge.

## Advanced: Codex as co-coder (only when the user asks)

For a large feature with a cleanly separable piece, Codex can implement that
piece itself in an ISOLATED git worktree:

```bash
WT=$(mktemp -d)
git worktree add "$WT" HEAD
cd "$WT" && codex exec --sandbox workspace-write "<subtask spec>"
```

(On Windows: `$WT = (New-Item -ItemType Directory -Path (Join-Path $env:TEMP ([guid]::NewGuid()))).FullName`,
the table's `New-TemporaryFile` creates a *file*, not a directory. The
requirement is that the worktree lives outside the primary working tree.)

Then Claude reviews Codex's working-tree diff in the worktree, applies and
commits the accepted changes onto the main branch, and /dual-review still
gates the combined result. Never point a write-enabled Codex at the user's
primary working tree.

## Notes

- Same plumbing as /dual-review: OpenAI Codex CLI installed + authenticated;
  don't edit the user's `~/.codex/config.toml`, always override reasoning
  effort to `high` via `-c`. Under config isolation the config's model pin
  does not apply: the CLI default runs unless you pass `-c model=...`.
  Codex prints `model: <name>` in its startup header, read it, and re-run
  with `-c model=<your flagship>` if it is a mini tier (a mini model gives
  shallow critiques).
  macOS + Codex desktop app: if `codex` is symlinked out of the app bundle,
  its sibling helper `codex-code-mode-host` must be symlinked into the same
  directory too, or every run fails with "failed to spawn code-mode host",
  recreate both symlinks if you hit that. Check where `codex` actually points
  with `ls -l`: as of 2026-07 it resolves to
  `/Applications/ChatGPT.app/Contents/Resources/codex`, not `Codex.app`.
- Always pass `-s read-only` on critique runs, don't rely on the sandbox
  default, which the user's config can change. Only the explicit co-coder
  flow uses `--sandbox workspace-write`, and only in a worktree.
- Run Codex calls via Bash `run_in_background: true`; do other work while
  waiting.
