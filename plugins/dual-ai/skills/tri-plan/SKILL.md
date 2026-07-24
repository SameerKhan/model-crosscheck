---
name: tri-plan
description: Plan a feature with Claude, OpenAI Codex, AND Google Gemini together — Claude drafts the implementation plan, Codex and Gemini independently critique it against the codebase in parallel, Claude adjudicates and implements after user approval, then /tri-review gates the merge. Use when the user says "tri plan", "triple plan", "plan with all three", or wants maximum independent scrutiny on a plan before code is written.
---

# Tri plan (Claude + Codex + Gemini)

Feature workflow with three models: Claude drives, Codex and Gemini
independently critique at two gates — the plan and (via /tri-review) the
final diff. The value is adversarial and cross-vendor: both critics are
prompted to find what the plan gets wrong, not to agree with it, and a
point BOTH critics raise independently is near-certain to be real.

## Model per leg — pin all three

| Leg | Model | Where it's set |
|---|---|---|
| **Claude** (plan draft, adjudication, implementation) | the strongest Claude tier available (Opus) | the session model — see below |
| Codex critic | whatever `~/.codex/config.toml` pins | `-c` override, effort forced to `high` |
| Gemini critic | newest Gemini on the plan | `--model` on every `agy` call |

Both critics get their model pinned explicitly, so the Claude leg shouldn't be
the one seat left to chance. It is also the load-bearing one: Claude drafts
the plan, rules on both critiques, and writes the code — the critics only ever
react to what Claude produced, so a weak draft caps the quality of the whole
run. Run it on the strongest Claude tier available — **not** a fast/cheap
tier, even if that is the session default.

Claude cannot switch its own main-loop model, so **check before starting**.
The active model is stated in the session's environment context (the user can
also confirm with `/status`).

- Already on the strongest tier → proceed.
- Anything else → **stop before step 1**, say which model the Claude leg
  would run on, and ask the user to switch (`/model opus`) and re-invoke.
  Don't draft on a downgraded model and then spend two critic CLIs on it.
- Pin any subagent this skill spawns to the same tier explicitly — passing an
  `agentType` inherits that agent definition's own model instead.

## Cross-platform — the snippets below are bash/zsh

On Windows (PowerShell) the stdin redirect breaks outright. Detect the shell
and translate; don't paste the bash form and hope:

| bash/zsh | PowerShell |
|---|---|
| `codex exec ... - < critique-prompt.md` | `Get-Content critique-prompt.md \| codex exec ... -` — PowerShell **reserves `<`** and errors on it |
| `mktemp` | `(New-TemporaryFile).FullName` |
| `~/.codex/config.toml` | `$env:USERPROFILE\.codex\config.toml` (or `$env:CODEX_HOME\config.toml` — `CODEX_HOME` is the directory, not the file) |
| `~/.gemini/antigravity-cli/settings.json` | `$env:USERPROFILE\.gemini\antigravity-cli\settings.json` |

`codex` and `agy` are on PATH on Windows when installed normally — the
`~/.local/bin/agy` fallback and the `codex-code-mode-host` symlink trap are
macOS/Linux-only. All CLI flags, the convergence rules, and the round cap are
identical on every platform.

## Steps

1. **Scope the feature.** Explore the codebase as usual (respect the repo's
   CLAUDE.md conventions and known landmines). Draft an implementation plan:
   goal, files to touch, approach, data-shape changes, risks, test plan.
   Write it to a scratch file OUTSIDE the repo (plain `mktemp`, or
   `$env:TEMP\plan.md` on Windows) — scratch files inside the repo would
   pollute a later `--uncommitted` review scope or get committed by accident.
   Both critics read this file, so use an absolute path.

2. **Critique gate — run both critics in parallel, in the background**
   (each takes minutes; two separate Bash calls with
   `run_in_background: true`):

   ```bash
   codex exec -s read-only -c model_reasoning_effort="high" - < /path/to/critique-prompt.md
   ```

   ```bash
   agy --sandbox --model <newest-gemini-on-plan> --print-timeout 15m -p "<critique prompt naming the plan file's absolute path>"
   ```

   Pass `-s read-only` (Codex) and `--sandbox` (Gemini) explicitly — a
   critic must never touch the tree. Remember `agy -p` does NOT read stdin:
   the prompt must name the plan file's absolute path for Gemini to
   `read_file`.

   Critique prompt template (same content for both critics; for Gemini,
   prepend "Read the plan at <ABS_PATH> with read_file first."):
   > You are reviewing an implementation plan for this repository (read the
   > code to check every claim; AGENTS.md — or CLAUDE.md if there is no
   > AGENTS.md — has project context, when present). Do NOT implement
   > anything, do NOT edit files. Verify the plan's claims against the
   > files and symbols it names — do not do an open-ended tour of the repo.
   > Find: (1) factually wrong assumptions about the codebase, (2) missed
   > files, call sites, or cross-repo blast radius, (3) simpler
   > alternatives, (4) risks/edge cases the plan ignores, (5) anything in
   > the test plan that wouldn't catch a regression. Be specific — cite
   > file paths. Then give an overall verdict: SOUND / NEEDS-CHANGES with a
   > ranked list.
   >
   > PLAN: <plan contents / path>

   The "verify, don't tour" line matters for Gemini especially — an
   unconstrained agent wanders the repo and exceeds `--print-timeout` with
   no output.

3. **Merge and adjudicate.** Dedupe the two critique lists, then:
   - **Both critics raised it**: treat as near-certain — revise the plan
     (only reject with strong code evidence, stated in the round notes).
   - **One critic raised it**: verify against the code first; accept
     (revise) or reject with the reason. Never dismiss unchecked, and
     never relay one model's claim into the plan unverified.

4. **Converge — BOTH critics must sign off on the FINAL plan.** Send the
   revised plan back to both in parallel (same prompt template, plus a
   "previous round's points and how each was addressed or rebutted"
   section). Repeat revise → re-critique until both return **SOUND**, up to
   **3 rounds** total — the cap is shared, not per-critic. Do not present a
   plan to the user that either critic has not seen in its final form.
   - If either critic still says NEEDS-CHANGES after round 3, stop looping:
     present the plan WITH each unresolved disagreement as a named decision
     point — who holds which position and your recommendation — and let the
     user rule. Never paper over a disagreement to fake consensus, and
     never keep looping past 3 rounds (models can trade nits forever).
   - A critic that keeps raising NEW nits each round (rather than defending
     old ones) is churning, not converging — after round 3 that also goes
     to the user as-is.

5. **User approval.** Present the converged plan with a short "what each
   critic changed / how many rounds / any [disputed] points" section — the
   user approves before any code is written.

6. **Implement.** Claude writes the code (Claude holds the tools, memory,
   and repo context). Neither critic edits the working tree — multiple
   writers on one tree causes conflicts.

7. **Close with /tri-review** (the sibling skill) on the finished diff
   before any PR/merge.

## Notes

- Plumbing is shared with the sibling skills — see **/dual-review's Notes**
  for the Codex leg (install/auth, `codex-code-mode-host` symlink trap,
  model pinned in `~/.codex/config.toml`, always `-c
  model_reasoning_effort="high"`) and **/tri-review's Notes** for the
  Gemini leg (install/auth, no-stdin trap, read-only allowlist in
  `~/.gemini/antigravity-cli/settings.json`, pick the newest **Gemini**
  model — `agy models` also lists Claude/GPT-OSS models, and picking one
  puts the same lab on two seats).
- Gemini gets a longer `--print-timeout` here (15m vs review's 8m) —
  checking a plan's claims against real code takes more reading than
  reviewing a patch file.
- If one critic CLI is unavailable (not installed / auth broken), say so
  and offer to fall back to /dual-plan rather than silently running with
  one critic under a three-critic banner.
- The co-coder variant (a critic implementing a separable piece in an
  isolated worktree) is documented in /dual-plan — it applies unchanged;
  use it only when the user asks.
