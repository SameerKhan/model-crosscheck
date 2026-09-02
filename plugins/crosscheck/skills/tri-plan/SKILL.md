---
name: tri-plan
description: Plan a feature with Claude, OpenAI Codex, AND Google Gemini together: Claude drafts the implementation plan, Codex and Gemini independently critique it against the codebase in parallel, Claude adjudicates and implements after user approval, then /tri-review gates the merge. Use when the user says "tri plan", "triple plan", "plan with all three", or wants maximum independent scrutiny on a plan before code is written.
---

# Tri plan (Claude + Codex + Gemini)

Feature workflow with three models: Claude drives, Codex and Gemini
independently critique at two gates, the plan and (via /tri-review) the
final diff. The value is adversarial and cross-vendor: both critics are
prompted to find what the plan gets wrong, not to agree with it, and a
point BOTH critics raise independently is near-certain to be real.

## Model per leg: pin all three

| Leg | Model | Where it's set |
|---|---|---|
| **Claude** (plan draft, adjudication, implementation) | the newest top-tier Claude available (2026-09: Fable 5.1, then Fable 5, then Opus 5) | the session model, see below |
| Codex critic | the CLI's default under config isolation, read the `model:` line Codex prints at startup; `-c model=...` to override | `--ephemeral --ignore-user-config -s read-only`, effort forced to `high` |
| Gemini critic | the newest Gemini on the plan (2026-09: `gemini-3.8-flash-high`, a floor, not a pin) | `--model` on every `agy` call |

Both critics get their model set on the command line, Gemini by `--model`,
Codex by the CLI default under config isolation or an explicit `-c model=`,
so the Claude leg shouldn't be the one seat left to chance. It is also the load-bearing one: Claude drafts
the plan, rules on both critiques, and writes the code, the critics only ever
react to what Claude produced, so a weak draft caps the quality of the whole
run. Run it on the newest, most capable Claude the plan offers at run time,
**not** a fast/cheap tier, even if that is the session default, and not a
name pinned in this file: the dated example in the table is a **floor, not
an exact match**, a tier hard-coded last quarter quietly becomes the
second-best seat when the next model ships.

Claude cannot switch its own main-loop model, so **check before starting**.
The active model is stated in the session's environment context (the user can
also confirm with `/status`).

- On a top-tier Claude (Fable/Opus-class) at least as new as the table's
  dated example → proceed. Newer than the example also passes, and a `[1m]`
  context-window suffix on the model id is the same model.
- On a fast/cheap tier (Haiku/Sonnet-class), or a top tier older than the
  example → **stop before step 1**, say which model the Claude leg would
  run on, and ask the user to switch (`/model` lists what the plan offers,
  pick the newest top-tier Claude) and re-invoke. Don't draft on a
  downgraded model and then spend two critic CLIs on it. If you genuinely
  can't classify the session model, name it and ask rather than deciding
  silently.
- Pin any subagent this skill spawns to the same tier explicitly: passing
  `subagent_type` (Agent tool) or `agentType` (Workflow scripts) without
  `model` inherits that agent definition's own model.

## Cross-platform: the snippets below are bash/zsh

On Windows (PowerShell) the stdin redirect breaks outright. Detect the shell
and translate; don't paste the bash form and hope:

| bash/zsh | PowerShell |
|---|---|
| `codex exec ... - < critique-prompt.md` | `Get-Content critique-prompt.md \| codex exec ... -`, PowerShell **reserves `<`** and errors on it |
| `mktemp` | `(New-TemporaryFile).FullName` |
| `~/.codex/config.toml` | `$env:USERPROFILE\.codex\config.toml` (or `$env:CODEX_HOME\config.toml`, `CODEX_HOME` is the directory, not the file) |
| `~/.gemini/antigravity-cli/settings.json` | `$env:USERPROFILE\.gemini\antigravity-cli\settings.json` |

`codex` and `agy` are on PATH on Windows when installed normally, the
`~/.local/bin/agy` fallback and the `codex-code-mode-host` symlink trap are
macOS/Linux-only. All CLI flags, the convergence rules, and the round cap are
identical on every platform.

## Steps

1. **Scope the feature.** Explore the codebase as usual (respect the repo's
   CLAUDE.md conventions and known landmines). Draft an implementation plan:
   goal, files to touch, approach, data-shape changes, risks, test plan.
   Write it to a scratch file OUTSIDE the repo (plain `mktemp`, or
   `(New-TemporaryFile).FullName` on Windows), scratch files inside the
   repo would pollute a later `--uncommitted` review scope or get committed
   by accident, and a fixed name collides with a concurrent run.
   Gemini reads this file by absolute path; Codex gets its contents inlined
   into the critique prompt, because `codex exec -` reads stdin as its whole
   prompt.

2. **Critique gate, run both critics in parallel, in the background**
   (each takes minutes; two separate Bash calls with
   `run_in_background: true`):

   ```bash
   codex exec --ephemeral --ignore-user-config -s read-only -c model_reasoning_effort="high" - < /path/to/critique-prompt.md
   ```

   ```bash
   agy --sandbox --model <newest-gemini-on-plan> --print-timeout 15m -p "<critique prompt naming the plan file's absolute path>"
   ```

   Pass `-s read-only` (Codex) and `--sandbox` (Gemini) explicitly, a
   critic must never touch the tree. Remember `agy -p` does NOT read stdin:
   the prompt must name the plan file's absolute path for Gemini to
   `read_file`.

   **Two lenses, not one prompt.** Send each critic BOTH lenses as
   **separate passes**, never a single merged prompt. Lens A asks whether
   the plan is *right*; Lens B asks whether you would *let it run*. They
   surface different defect classes, and a plan can pass A completely while
   failing B in ways that damage production.

   For Gemini, prepend "Read the plan at <ABS_PATH> with read_file first.
   Begin your reply with one line: READ: <the plan file's first line,
   verbatim>, or FILE-NOT-READ if you could not open it." to each lens.
   A SOUND or AUTHORIZE without that READ line is a failed run, not a
   sign-off, the hollow-verdict failure is reproduced, not hypothetical
   (see /tri-review's Notes): check whether the critique cites the plan's
   actual content; if not, discard it, re-check the path, and re-run once.

   **Lens A, correctness:**
   > You are reviewing an implementation plan for this repository (read the
   > code to check every claim; AGENTS.md, or CLAUDE.md if there is no
   > AGENTS.md, has project context, when present). Do NOT implement
   > anything, do NOT edit files. Verify the plan's claims against the
   > files and symbols it names. Do not tour the repo at large, but DO
   > open every API, function, CLI flag, config key and credential path the
   > plan says it will use, and confirm the capability actually exists with
   > the signature the plan assumes. Find: (1) factually wrong assumptions
   > about the codebase, (2) missed files, call sites, or cross-repo blast
   > radius, (3) simpler alternatives, (4) risks/edge cases the plan
   > ignores, (5) anything in the test plan that wouldn't catch a
   > regression. Be specific, cite file paths. Then give an overall
   > verdict: SOUND / NEEDS-CHANGES with a ranked list.
   >
   > PLAN: <for Codex, the plan contents inlined, `codex exec -` reads stdin
   > as its whole prompt; for Gemini, the absolute path it must read_file>

   **Lens B, authorization / operations:**
   > You are deciding whether to AUTHORIZE this plan to run, assume it will
   > execute unattended, against production, with the credentials the
   > operator already holds. Do NOT implement anything, do NOT edit files.
   > You may read any file needed to answer these. Check: (1) what
   > privileges it needs, and whether they are ENFORCED or merely assumed,
   > "read-only by convention" is not read-only; (2) what shared or
   > long-lived resources it mutates (shared virtualenvs, global config,
   > caches, other people's checkouts); (3) what untrusted input it fetches
   > or parses, from where, and what the egress path can reach, if it
   > fetches attacker-influenceable URLs from a host holding credentials,
   > treat SSRF as in scope; (4) secrets and raw data: what is written,
   > where, with what permissions, what is redacted, how long it is kept,
   > and whether any of it can reach version control; (5) failure and
   > cleanup paths, orphaned processes, tunnels, browsers, temp state, and
   > whether cleanup failure is detected or merely hoped for;
   > (6) reversibility, and what a partial or interrupted run leaves
   > behind. Be specific, cite file paths. Verdict: AUTHORIZE /
   > DO-NOT-AUTHORIZE with a ranked list of blockers.
   >
   > PLAN: <for Codex, the plan contents inlined, `codex exec -` reads stdin
   > as its whole prompt; for Gemini, the absolute path it must read_file>

   **The executable-claim check (in Lens A) is the highest-value single
   rule here.** A plan that says "inject the credentials at call time"
   against a function whose signature takes no credentials is a plan that
   cannot run, and that gap is invisible to anyone reviewing only the
   plan's prose. Confirm the capability in the source, not the intent.

   The "verify, don't tour" line matters for Gemini especially, an
   unconstrained agent wanders the repo and exceeds `--print-timeout` with
   no output.

3. **Merge and adjudicate.** Dedupe the critique lists, then:
   - **Both critics raised it**: treat as near-certain, revise the plan
     (only reject with strong code evidence, stated in the round notes).
   - **One critic raised it**: verify against the code first; accept
     (revise) or reject with the reason. Never dismiss unchecked, and
     never relay one model's claim into the plan unverified.

   ⚠️ **Weigh convergence by whether the critics shared a question.**
   Two models agreeing *within the same lens* is much weaker evidence than
   it feels: they were independent of each other but perfectly dependent on
   the prompt you wrote, so they share its blind spots exactly. Agreement
   **across different lenses** is the strong signal. And unanimous silence
   on a whole category means nobody was asked about it, never read it as
   "no problems there".

   This is not hypothetical. In the run that produced these instructions,
   three model rounds under a single correctness-only prompt returned
   converging verdicts and one outright SOUND. A later pass, **same model,
   same CLI, same effort setting**, asked instead whether the plan was safe
   to run unattended against production, immediately found credential
   enforcement, SSRF, shared-environment mutation and data-retention
   defects that all three earlier rounds had missed. The capability was
   there the whole time; the question wasn't.

4. **Converge, BOTH critics must sign off on the FINAL plan**: on **both
   lenses**. Send the revised plan back to both in parallel (same lens
   prompts, plus a "previous round's points and how each was addressed or
   rebutted" section). Repeat revise → re-critique until both return
   **SOUND** and **AUTHORIZE**, up to **3 rounds** total, the cap is
   shared, not per-critic. **Rounds are not a substitute for a second
   question:** if all rounds so far have run one lens, adding a fourth
   round is worth less than running the other lens once. Do not present a
   plan to the user that either critic has not seen in its final form.
   - If either critic still says NEEDS-CHANGES after round 3, stop looping:
     present the plan WITH each unresolved disagreement as a named decision
     point, who holds which position and your recommendation, and let the
     user rule. Never paper over a disagreement to fake consensus, and
     never keep looping past 3 rounds (models can trade nits forever).
   - A critic that keeps raising NEW nits each round (rather than defending
     old ones) is churning, not converging, after round 3 that also goes
     to the user as-is.

5. **User approval.** Present the converged plan with a short "what each
   critic changed / how many rounds / any [disputed] points" section, the
   user approves before any code is written.

6. **Implement.** Claude writes the code (Claude holds the tools, memory,
   and repo context). Neither critic edits the working tree, multiple
   writers on one tree causes conflicts.

7. **Close with /tri-review** (the sibling skill) on the finished diff
   before any PR/merge.

## A human who owns the resource is a third reviewer class

If the plan touches something a specific person is accountable for, the
production database, the deploy pipeline, the cloud account, route it past
that person **before** spending three model rounds, not after. They are not
a slower critic; they ask a different question, because they are the one
who gets paged. In practice their review lands the operational blockers
(enforced privilege, egress exposure, retention) that correctness-focused
review does not reach, and it lands them in one pass.

Treat their sign-off as a **gate**, not a data point, and give them the
same lens B checklist so the ask is concrete.

If such a reviewer requires a change that contradicts the written spec or
brief, do **not** silently pick a side: implement the safer, more
reversible option, define exactly one behaviour so an unattended run is
never ambiguous, and escalate the conflict to whoever owns the brief.

## Review the artifact that will actually execute

A plan is not an implementation. When the deliverable is scripts, a
runbook, or config that will run later, say plainly what remains
unverifiable until it exists, and gate the real run behind a **bounded dry
run against the actual scripts** rather than another document round.

Also: **execute state-machine logic instead of reasoning about it.** For
supervisors, retry/cleanup/timeout handling and exit-code contracts, write
the truth table and run it. In the run behind these notes, a cleanup
supervisor was reviewed by three models; a bug that made *every* timeout
report as a fatal error, and a second where an unreaped zombie process
faked a liveness check, only surfaced when the code was actually run.

## Notes

- Plumbing is shared with the sibling skills, see **/dual-review's Notes**
  for the Codex leg (install/auth, `codex-code-mode-host` symlink trap,
  config isolation via `--ephemeral --ignore-user-config` and why `-s
  read-only` doesn't cover MCP, always `-c model_reasoning_effort="high"`)
  and **/tri-review's Notes** for the Gemini leg (install/auth, no-stdin
  trap, the read-receipt contract for hollow verdicts, read-only allowlist
  in `~/.gemini/antigravity-cli/settings.json`, pick the newest **Gemini**
  model, `agy models` also lists Claude/GPT-OSS models, and picking one
  puts the same lab on two seats).
- Gemini gets a longer `--print-timeout` here (15m vs review's 8m),
  checking a plan's claims against real code takes more reading than
  reviewing a patch file.
- If one critic CLI is unavailable (not installed / auth broken), say so
  and offer to fall back to /dual-plan rather than silently running with
  one critic under a three-critic banner.
- The co-coder variant (a critic implementing a separable piece in an
  isolated worktree) is documented in /dual-plan, it applies unchanged;
  use it only when the user asks.
