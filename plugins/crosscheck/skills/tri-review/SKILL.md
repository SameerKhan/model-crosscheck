---
name: tri-review
description: Triple code review — run Claude's /code-review, OpenAI Codex CLI, AND Google Gemini (Antigravity CLI) on the same diff, then merge all three into one consolidated report. Use when the user says "tri review", "triple review", "review with all three", "Claude + Codex + Gemini review", or before a merge when they want maximum independent coverage.
---

# Tri review (Claude + Codex + Gemini)

Three independent reviews of the same diff, merged into one report. The value
is in the merge: agreement across different models is the strongest signal a
finding is real; disagreement tells the user exactly where to look manually.

## Model per leg — pin all three

| Leg | Model | Where it's set |
|---|---|---|
| **Claude** (verification + merge; see step 4 re `/code-review`) | the newest top-tier Claude available (2026-09: Fable 5.1, then Fable 5, then Opus 5) | the session model — see below |
| Codex | the CLI's default under config isolation — read the `model:` line Codex prints at startup; `-c model=...` to override | `--ephemeral --ignore-user-config -s read-only`, effort forced to `high` |
| Gemini | the newest Gemini on the plan (2026-09: `gemini-3.8-flash-high` — a floor, not a pin) | `--model` on every `agy` call |

The other two legs get their model set on the command line — Gemini by
`--model`, Codex by the CLI default under config isolation or an explicit
`-c model=` — so the Claude leg shouldn't be the one seat left to chance. It is also the load-bearing one: it
holds the repo context, verifies the other two models' findings before
relaying them, and writes the merge. Run it on the newest, most capable
Claude the plan offers at run time — **not** a fast/cheap tier, even if
that is the session default, and not a name pinned in this file: the dated
example in the table is a **floor, not an exact match**, because a tier
hard-coded last quarter quietly becomes the second-best seat when the next
model ships.

Claude cannot switch its own main-loop model, so **check before starting**.
The active model is stated in the session's environment context (the user can
also confirm with `/status`).

- On a top-tier Claude (Fable/Opus-class) at least as new as the table's
  dated example → proceed. Newer than the example also passes, and a `[1m]`
  context-window suffix on the model id is the same model.
- On a fast/cheap tier (Haiku/Sonnet-class), or a top tier older than the
  example → **stop before step 1**, say which model the Claude leg would
  run on, and ask the user to switch (`/model` lists what the plan offers —
  pick the newest top-tier Claude) and re-invoke. Don't quietly run a
  "triple review" with a downgraded Claude seat. If you genuinely can't
  classify the session model, name it and ask rather than deciding
  silently.
- Pin any subagent this skill spawns to the same tier explicitly: passing
  `subagent_type` (Agent tool) or `agentType` (Workflow scripts) without
  `model` inherits that agent definition's own model.

## Cross-platform — the snippets below are bash/zsh

On Windows (PowerShell) three of them break outright. Detect the shell and
translate; don't paste the bash form and hope:

| bash/zsh | PowerShell |
|---|---|
| `PATCH=$(mktemp)` | `$PATCH = (New-TemporaryFile).FullName` |
| `cmd - < prompt.md` | `Get-Content prompt.md \| cmd -` — PowerShell **reserves `<`** and errors on it |
| `rm -f "$PATCH"` | `Remove-Item $PATCH -Force` |
| `~/.codex/config.toml` | `$env:USERPROFILE\.codex\config.toml` (or `$env:CODEX_HOME\config.toml` — `CODEX_HOME` is the directory, not the file) |
| `~/.gemini/antigravity-cli/settings.json` | `$env:USERPROFILE\.gemini\antigravity-cli\settings.json` |

`codex` and `agy` are on PATH on Windows when installed normally — the
`~/.local/bin/agy` fallback and the `codex-code-mode-host` symlink trap are
macOS/Linux-only. Everything else (the `git` commands, all CLI flags, and the
merge logic) is identical on every platform.

## Steps

1. **Determine diff scope.**
   - Branch has commits vs the main branch (check the repo's CLAUDE.md for
     which branch is the trunk — it is not always `main`): scope =
     `origin/<trunk>...HEAD`, Codex flag = `--base origin/<trunk>`. Run
     `git fetch` first and give all three reviewers the SAME ref — a stale
     local trunk vs `origin/<trunk>` silently produces different diffs.
   - Only uncommitted working-tree changes: Codex flag = `--uncommitted`,
     and review the working-tree diff on the Claude and Gemini sides. Run
     `git add --intent-to-add .` first so newly created untracked files
     appear in `git diff HEAD` — otherwise two of the three reviewers
     silently never see them. (Undo afterwards with `git reset` if the user
     doesn't want them staged.)
   - Both committed AND uncommitted changes: `--base` and `--uncommitted`
     are mutually exclusive, so don't pick silently — ask the user to
     commit/stash first, or review the committed scope and state explicitly
     that uncommitted edits are excluded.

2. **Write the diff to a patch file** (Gemini needs it — see Notes):

   ```bash
   PATCH=$(mktemp)
   git diff origin/<trunk>...HEAD > "$PATCH"
   # or: git diff HEAD > "$PATCH" for uncommitted scope
   ```

   Use a unique temp file (`mktemp`), not a fixed path — a fixed name
   collides with a concurrent review and is world-predictable. Delete it
   when the review is done. Plain `mktemp` with no template is the portable
   form: BSD/macOS `mktemp -t foo.XXXXXX` treats the argument as a *prefix*
   and appends its own suffix, so the literal `XXXXXX` survives in the
   filename. The extension doesn't matter — Gemini reads the file by path.

3. **Start Codex and Gemini in the background, in parallel** (each takes
   several minutes). Two separate Bash calls with `run_in_background: true`:

   ```bash
   codex exec --ephemeral --ignore-user-config -s read-only review --base origin/<trunk> -c model_reasoning_effort="high"
   # or: codex exec --ephemeral --ignore-user-config -s read-only review --uncommitted -c model_reasoning_effort="high"
   ```

   ```bash
   agy --sandbox --model <newest-gemini-on-plan> --print-timeout 8m -p "You are a senior code reviewer. Read the file <PATCH_PATH> with read_file — it is a git diff. Review it for real bugs only (correctness, security, data loss), not style. You MAY read_file the repo files named in the diff headers for surrounding context, but do NOT search or explore beyond them and do NOT run commands. Begin your reply with one line: INSPECTED: <number of files in the diff> — <the first diff --git header line, verbatim>. If you could not read the file, output FILE-NOT-READ instead of a review. Then output findings as one line each: file:line — issue — why it breaks. If none, output CLEAN on the line after the INSPECTED preamble."
   ```

   Always pass `-s read-only` (Codex) and `--sandbox` (Gemini) — a reviewer
   must never touch the tree, and the diff under review is untrusted input:
   a prompt-injected diff could otherwise steer an unsandboxed agent into
   running commands. Prompt-level "do NOT run commands" text is a
   constraint, not a boundary. If a sandbox blocks network access, grant
   network to the sandboxed run; never disable the sandbox for a review.

4. **While they run, invoke `/code-review` at high effort** on the same scope.
   **Don't assume `/code-review` inherits the session model** — some
   implementations fan out to their own worker agents on a tier the plugin
   chooses, not your session (the official `code-review` plugin command, for
   one, spawns its own finder agents). The model gate reliably covers the main-loop work:
   the verification pass in step 5, the rebuttal round, and the merge. If the
   finding-generation itself must run on the top tier, spawn the review
   agents directly with an explicit `model` rather than relying on
   inheritance.

4b. **When the diff is something that gets EXECUTED — a runbook, plan,
   migration, CI config, IaC, or deploy script — add an operations pass**
   alongside the bug review. Same patch, separate prompt:

   > Assume this will run unattended, in production, with the credentials
   > the operator already holds. What privileges does it need, and are they
   > enforced or merely assumed? What shared or long-lived state does it
   > mutate? What untrusted input does it fetch or parse, and what can that
   > egress path reach? What secrets or raw data does it write, where, with
   > what permissions and retention, and can any of it reach version
   > control? What happens on failure — orphaned processes, tunnels, temp
   > state — and is cleanup failure detected or merely hoped for? What does
   > a partial run leave behind? Verdict: AUTHORIZE / DO-NOT-AUTHORIZE.

   Reviewing such a diff for "bugs" alone reliably misses this entire
   class, because nobody was asked.

4c. **Execute state-machine logic; don't just read it.** For supervisors,
   retry/backoff, cleanup handlers, signal handling and exit-code
   contracts, write the truth table and actually run it on the Claude leg.
   (Keep `-s read-only` / `--sandbox` and no-command-execution on the two
   external legs — the diff is untrusted input. The Claude leg is where
   deliberate, scoped execution belongs.) Reading a cleanup path and
   running it produce different findings: timeout-vs-leak confusion and
   unreaped-zombie liveness checks look correct on the page.

5. **Merge the findings** once all three are done. Dedupe by file + line +
   issue, then rank:
   ⚠️ **Convergence is only strong when the reviewers were asked different
   questions.** Models that shared one prompt are independent of each other
   but perfectly dependent on that prompt, so they share its blind spots.
   Unanimous silence on a category usually means nobody asked about it —
   not that the category is clean.

   - **All three agree**: report first — near-certain, no verification needed.
   - **Two agree**: report next, tagged with which two.
   - **Claude-only**: report as normal /code-review findings.
   - **Codex-only / Gemini-only**: verify each against the actual code before
     reporting; mark CONFIRMED or REJECTED (with the reason). Never relay an
     external model's finding unverified.

6. **Rebuttal round — a refuted finding gets one defense.** For findings
   REJECTED in step 5, send the originating model ONE follow-up containing
   the finding plus your refutation evidence, asking it to CONCEDE or DEFEND
   with code citations:
   - Codex: `codex exec` (read-only, config-isolated as in step 3).
   - Gemini: `agy --sandbox --model <model> -p "..."` (include the
     refutation inline; reference the patch file again).
   Require the reply to open by quoting the disputed finding's file:line
   verbatim — a bare CONCEDE with no quote is a failed run, not a
   concession; re-send once. Tell **Gemini** it may not run commands: a
   headless `agy` rebuttal that tries to reproduce the failure dies on the
   permission auto-deny and returns nothing (seen 2026-09-02). Codex keeps
   its read-only shell — re-reading the code is how it cites.
   Concede → drop silently. Defend → re-examine once; if you still
   disagree, report it as **[disputed]** with both positions and your
   recommendation — the user rules. One rebuttal round only (reviews are expensive; the diff,
   unlike a plan, doesn't change mid-review). Skip when nothing was rejected.

7. **Report one consolidated list**, most severe first, tagging each finding
   with its source: `[all]`, `[claude+codex]`, `[claude+gemini]`,
   `[codex+gemini]`, `[claude]`, `[codex]`, `[gemini]`, or `[disputed]`.
   Never omit a disputed finding.

## Notes — Gemini leg (Antigravity CLI)

- Requires Google's Antigravity CLI (`agy`) installed and authenticated with
  a Google plan login (run `agy` interactively once to sign in). On
  macOS/Linux it may live at `~/.local/bin/agy` and not be on PATH in
  non-interactive shells — use the absolute path if `agy` isn't found. On
  Windows a normal install puts it on PATH.
- **`agy -p` does NOT pass stdin to the model.** Piping a diff in silently
  loses it and yields a hollow CLEAN. Always write the diff to a file and
  name the absolute path in the prompt.
- **Treat a CLEAN without the INSPECTED preamble as a failed run, not a
  clean review.** Reproduced on Gemini 3.7: piping the diff instead of
  naming the file returned "I am checking the git diff now. CLEAN" — an
  inspection that never happened. The INSPECTED line in the prompt makes a
  hollow CLEAN detectable. No preamble, or a header line that doesn't match
  the patch file → first check whether the findings cite files and lines
  actually present in the patch (that proves the file was read even when the
  preamble was skipped, and the review stands); if nothing diff-specific
  either, discard the verdict, re-check the path, and re-run once.
- **Machine-checked variant** (verified 2026-09-03 on Gemini 3.8 Flash) —
  for the Gemini leg, the one handed a file path. Instead of the INSPECTED
  preamble, let the CLI enforce the receipt. A schema ships next to this
  file as `receipt.schema.json` (fields `inspected_files`, `first_header`,
  `verdict` ∈ CLEAN / FINDINGS / FILE-NOT-READ, `findings[]` of
  `file:line — issue — why` strings). Pick one path per run, not both:

  ```bash
  agy --sandbox --model <model> --print-timeout 8m --output-format json \
    --json-schema /path/to/receipt.schema.json -p "<the step 3 prompt, with its last two sentences replaced by: Fill the schema — inspected_files = number of files in the diff, first_header = the first diff --git line verbatim, verdict = CLEAN or FINDINGS (FILE-NOT-READ if you could not open the file), findings = one string per defect as file:line — issue — why it breaks>"
  ```

  The reply is a JSON envelope: read its `structured_output` object (the one
  validated against the schema — the free-text `response` field may carry
  extra keys the model invented) and compare `inspected_files` and
  `first_header` to the patch yourself; a mismatch is a hollow run.
  `--json-schema` is rejected unless `--output-format` is `json` or
  `stream-json`. No receipt applies to the step 3 Codex leg: the built-in
  `review` subcommand takes neither a prompt nor a schema, and it reads the
  repo itself, so there is no path to lose. `codex exec --output-schema
  <file> "<prompt>"` exists for the custom-prompt form (tri-research's
  auditor, for one) and prints the constrained JSON directly — there is no
  `structured_output` envelope to look for.
- **Constrain exploration explicitly** ("do NOT search or explore beyond
  them, do NOT run commands") — without it the agent wanders the repo and
  exceeds `--print-timeout` with no output.
- Headless mode auto-denies any tool not allowlisted in
  `~/.gemini/antigravity-cli/settings.json` → `permissions.allow`. Keep that
  allowlist READ-ONLY (read_file, grep_search, …) — headless mode
  auto-approves whatever is allowlisted, so a write or terminal rule left
  over from other work becomes an unattended grant here. Pair it with
  `--sandbox` (defense in depth). If a run dies with "required the X
  permission", add a read-only rule there — never use
  `--dangerously-skip-permissions`.
- Pass `--model` explicitly and pick the newest **Gemini** model your plan
  offers (e.g. `gemini-3.8-flash-high` as of 2026-09 — the 3.7 example that
  stood here went stale within a month, which is why the table calls it a
  floor); a newer flash tier at high effort tends to out-review an older
  pro tier. If the newest Gemini listed is *older* than the dated example,
  the seat is below floor: still run it — Gemini is the tie-breaker, not the
  load-bearing seat — but label the report `gemini seat: <model>, below the
  documented floor` so the user can discount it. Do not stop for it the way
  the Claude gate stops. Note that `agy models`
  may also list Claude and GPT-OSS models — don't pick those, or two of your
  three "independent" reviewers share a lab and the agreement signal is void.
  Run `agy models` and copy a name from the list rather than guessing one:
  new generations appear silently, and the pro line lags the flash line
  (as of 2026-09 Flash is at 3.8 while the newest Pro is still 3.1), so an
  invented name just fails.
- Auth error / "Please sign in" → tell the user to run `agy` in their own
  terminal and complete the Google login; do not attempt to re-auth headless
  (it requires an interactive OAuth code paste).

## Notes — Codex leg

- Requires the OpenAI Codex CLI (`codex`) installed and authenticated
  (`codex login` or the Codex desktop app). Don't change the user's global
  `~/.codex/config.toml`; use `-c` overrides only. Always override reasoning
  effort to `high` — a low default is too weak for review.
- Under config isolation your `~/.codex/config.toml` model pin does **not**
  apply — the CLI's built-in default runs unless you pass `-c model=...`.
  Codex prints `model: <name>` in its startup header on every run: read it
  off the first lines of the leg's output, and if it is a mini/small tier,
  re-run with `-c model=<your flagship>` (and pass that explicitly from then
  on — the default tracks the CLI release, not your choice). Effort `high`
  on a small model still yields a shallow reviewer — and the merge logic
  would then treat "Codex found nothing" as an independent signal.
- **`-s read-only` sandboxes the shell, not MCP** — which is why the step 3
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
