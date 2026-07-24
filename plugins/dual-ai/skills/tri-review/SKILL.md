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
| **Claude** (verification + merge; see step 4 re `/code-review`) | the strongest Claude tier available (Opus) | the session model — see below |
| Codex | whatever `~/.codex/config.toml` pins | `-c` override, effort forced to `high` |
| Gemini | newest Gemini on the plan | `--model` on every `agy` call |

The other two legs get their model pinned explicitly, so the Claude leg
shouldn't be the one seat left to chance. It is also the load-bearing one: it
holds the repo context, verifies the other two models' findings before
relaying them, and writes the merge. Run it on the strongest Claude tier
available — **not** a fast/cheap tier, even if that is the session default.

Claude cannot switch its own main-loop model, so **check before starting**.
The active model is stated in the session's environment context (the user can
also confirm with `/status`).

- Already on the strongest tier → proceed.
- Anything else → **stop before step 1**, say which model the Claude leg
  would run on, and ask the user to switch (`/model opus`) and re-invoke.
  Don't quietly run a "triple review" with a downgraded Claude seat.
- Pin any subagent this skill spawns to the same tier explicitly — passing an
  `agentType` inherits that agent definition's own model instead.

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
   PATCH=$(mktemp -t tri-review.XXXXXX.patch)
   git diff origin/<trunk>...HEAD > "$PATCH"
   # or: git diff HEAD > "$PATCH" for uncommitted scope
   ```

   Use a unique temp file (`mktemp`), not a fixed path — a fixed name
   collides with a concurrent review and is world-predictable. Delete it
   when the review is done.

3. **Start Codex and Gemini in the background, in parallel** (each takes
   several minutes). Two separate Bash calls with `run_in_background: true`:

   ```bash
   codex exec -s read-only review --base origin/<trunk> -c model_reasoning_effort="high"
   # or: codex exec -s read-only review --uncommitted -c model_reasoning_effort="high"
   ```

   ```bash
   agy --sandbox --model <newest-gemini-on-plan> --print-timeout 8m -p "You are a senior code reviewer. Read the file <PATCH_PATH> with read_file — it is a git diff. Review it for real bugs only (correctness, security, data loss), not style. You MAY read_file the repo files named in the diff headers for surrounding context, but do NOT search or explore beyond them and do NOT run commands. Output findings as one line each: file:line — issue — why it breaks. If none, output exactly: CLEAN"
   ```

   Always pass `-s read-only` (Codex) and `--sandbox` (Gemini) — a reviewer
   must never touch the tree, and the diff under review is untrusted input:
   a prompt-injected diff could otherwise steer an unsandboxed agent into
   running commands. Prompt-level "do NOT run commands" text is a
   constraint, not a boundary. If a sandbox blocks network access, grant
   network to the sandboxed run; never disable the sandbox for a review.

4. **While they run, invoke `/code-review` at high effort** on the same scope.
   **Don't assume `/code-review` inherits the session model** — some
   implementations fan out to their own fixed-tier workers (the official
   `code-review` plugin command, for one, pins Haiku agents plus 5 parallel
   Sonnet review agents). The model gate reliably covers the main-loop work:
   the verification pass in step 5, the rebuttal round, and the merge. If the
   finding-generation itself must run on the top tier, spawn the review
   agents directly with an explicit `model` rather than relying on
   inheritance.

5. **Merge the findings** once all three are done. Dedupe by file + line +
   issue, then rank:
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
   - Codex: `codex exec` (read-only).
   - Gemini: `agy --sandbox --model <model> -p "..."` (include the
     refutation inline; reference the patch file again).
   Concede → drop silently. Defend → re-examine once; if you still disagree,
   report it as **[disputed]** with both positions and your recommendation —
   the user rules. One rebuttal round only (reviews are expensive; the diff,
   unlike a plan, doesn't change mid-review). Skip when nothing was rejected.

7. **Report one consolidated list**, most severe first, tagging each finding
   with its source: `[all]`, `[claude+codex]`, `[claude+gemini]`,
   `[codex+gemini]`, `[claude]`, `[codex]`, `[gemini]`, or `[disputed]`.
   Never omit a disputed finding.

## Notes — Gemini leg (Antigravity CLI)

- Requires Google's Antigravity CLI (`agy`) installed and authenticated with
  a Google plan login (run `agy` interactively once to sign in). It may live
  at `~/.local/bin/agy` and not be on PATH in non-interactive shells — use
  the absolute path if `agy` isn't found.
- **`agy -p` does NOT pass stdin to the model.** Piping a diff in silently
  loses it and yields a hollow CLEAN. Always write the diff to a file and
  name the absolute path in the prompt.
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
  offers (e.g. `gemini-3.6-flash-high`); a newer flash tier at high effort
  tends to out-review an older pro tier. Note that `agy models` may also
  list Claude and GPT-OSS models — don't pick those, or two of your three
  "independent" reviewers share a lab and the agreement signal is void.
  There is no Gemini 3.5 Pro — don't guess model names.
- Auth error / "Please sign in" → tell the user to run `agy` in their own
  terminal and complete the Google login; do not attempt to re-auth headless
  (it requires an interactive OAuth code paste).

## Notes — Codex leg

- Requires the OpenAI Codex CLI (`codex`) installed and authenticated
  (`codex login` or the Codex desktop app). Don't change the user's global
  `~/.codex/config.toml`; use `-c` overrides only. Always override reasoning
  effort to `high` — a low default is too weak for review.
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
