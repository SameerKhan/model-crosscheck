# Changelog

Plugin versions live in `plugins/crosscheck/.claude-plugin/plugin.json`.
Dates are commit dates. Every entry since 1.2.1 was itself reviewed with
`/tri-review` before it shipped; the findings that changed the release are
noted where they mattered.

## 2.6.0 (2026-09-03)

- **Model gates on every skill, decidable and floor-based.** `/dual-plan`
  and `/dual-review` gain the same "Model per leg" gate the `tri-*` skills
  carry. The dated model example is explicitly a floor (a newer top tier
  passes; a `[1m]` context-window suffix is the same model), and the
  stop-cases are ones an agent can evaluate from its own environment.
- **Read receipts are machine-checkable.** `/tri-review` ships
  `receipt.schema.json`; `agy --output-format json --json-schema` returns a
  validated `structured_output` (verified on Gemini 3.8 Flash). The
  `--json-schema` flag is rejected without `--output-format json`, which the
  previous note omitted.
- Gemini example refreshed to `gemini-3.8-flash-high`, the 3.7 example went
  stale within a month, so it is now labelled a floor, like the Claude one.
- `/tri-plan` says which form of the plan each critic gets: Codex reads
  stdin as its whole prompt, so the plan must be inlined; Gemini gets the
  absolute path to `read_file`.
- `/tri-strategy`'s "the other models cannot see your business" paragraph
  now reflects that the Codex leg is config-isolated by construction, and
  that the Gemini side needs `agy mcp list` checked (it has no isolation
  flag).
- `/tri-research`'s Codex auditor command gains `--skip-git-repo-check`:
  `-C` into a non-git scratch directory otherwise trips the
  trusted-directory check and the leg dies before any model call (a hang,
  with piped stdin). Caught by this release's own tri-review.
- Prose that still said the Codex leg is "pinned by `config.toml`" corrected
  everywhere: under config isolation the CLI default runs unless
  `-c model=` is passed.
- README: a ten-second setup check, tips for config isolation and read
  receipts, and this changelog.

## 2.5.0 (2026-09-02)

- **Claude leg: "the newest top-tier Claude available", never a pinned tier
  name** (Fable 5.1 as of 2026-09). The Opus pin from 1.4.0 had itself gone
  stale, the failure the rule now guards against.
- **Codex legs run config-isolated**: `--ephemeral --ignore-user-config
  -s read-only` in the canonical command of all seven skills. `-s read-only`
  sandboxes the shell, not MCP; a credentialed MCP fleet in `config.toml`
  otherwise boots against untrusted input. Its own tri-review caught that a
  note-level "prefer" no agent executes is not a fix, all three legs
  converged on it.
- **Hollow-verdict detection**: `/tri-review`'s Gemini prompt demands an
  `INSPECTED` preamble; sibling `agy` legs and the rebuttal round get a
  `READ` receipt. Reproduced failure: a fluent "CLEAN" from a run that never
  opened the patch.
- `/dual-plan` drops fixed `/tmp` paths for `mktemp`; Windows worktree note
  gets a real directory-creation command.

## 2.4.0 (2026-08-23)

- **`/tri-research`**: one researcher, two auditors, one claim ledger. Every
  row carries a status (`CONFIRMED-BY-N`, `CORRECTED`, `DISPUTED`,
  `UNVERIFIED`, `UNSOURCED`, `SINGLE-SOURCE`). Disputes are settled by
  re-reading the source, never by vote, on the live test, two legs agreed
  on a price for different billing terms.
- Codex web search: `-c tools.web_search=true` (`codex exec --search` does
  not exist). `-s read-only` is a write boundary, not a confidentiality
  boundary, first-party rows never go to a web-enabled auditor.
- README restructured: which-skill table, worked examples, when *not* to
  use these.

## 2.3.1 (2026-08-16)

- Gemini model example refreshed to 3.7 Flash.

## 2.3.0 (2026-08-01)

- **Authorization lens** in `/tri-plan` and `/tri-review`: "would you let
  this run unattended against production?" as a separate pass from "is it
  correct?". Reviewers who share one prompt share its blind spots.

## 2.2.0 (2026-07-26)

- **`/tri-strategy`**: three assigned lenses (unit economics, competitive
  positioning, execution capacity) over one evidence pack; no invented
  numbers.

## 2.1.0 (2026-07-26)

- **`/tri-decide`**: blind proposals, anonymized cross-examination, a
  decision record with a revisit trigger. Agreement is not signal here.

## 2.0.0 (2026-07-25, breaking)

- Identifiers renamed: marketplace `model-crosscheck`, plugin `crosscheck`,
  namespace `/crosscheck:*`. Ships `renames` so pre-rename installs keep
  working; see the README migration section.

## 1.6.0 (2026-07-25)

- Repository renamed from `dual-ai-skills` to `model-crosscheck`; install
  identifiers unchanged in this release.

## 1.5.0 (2026-07-25)

- Windows/PowerShell support in all four skills: `<` is reserved in
  PowerShell, `mktemp` → `New-TemporaryFile`, `CODEX_HOME` is a directory.

## 1.4.0 (2026-07-25)

- Claude leg pinned to Opus in `/tri-plan` and `/tri-review` (superseded by
  2.5.0's floor rule).

## 1.3.0 (2026-07-23)

- **`/tri-plan`**: Codex and Gemini critique the plan in parallel; both must
  sign off SOUND, shared 3-round cap.

## 1.2.1 (2026-07-23)

- Fixes from `/tri-review`'s review of itself: `--base origin/<trunk>`,
  sandbox flags mandatory, `mktemp` patch path, "newest Gemini" (not a
  Claude or GPT-OSS entry from `agy models`).

## 1.2.0 (2026-07-22)

- **`/tri-review`**: Claude + Codex + Gemini on the same diff.

## 1.0.0 (2026-07-17)

- `/dual-plan` and `/dual-review`, published as `dual-ai-skills`.
