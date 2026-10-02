# Changelog

Plugin versions live in `plugins/crosscheck/.claude-plugin/plugin.json`.
Dates are commit dates. Every entry since 1.2.1 was itself reviewed with
`/tri-review` before it shipped; the findings that changed the release are
noted where they mattered.

## 2.10.0 (2026-10-02)

`/tri-review`, from this week's five review runs. The proposal behind this
release was itself tri-reviewed, and lost its headline: replacing Codex's
built-in review on playbook diffs. All three legs showed the built-in review
had found real defects on playbook diffs; its one low count came from a
different question. It stays on every diff, and the new pass is added.

- **Trunk detection.** CLAUDE.md or AGENTS.md first; otherwise
  `git ls-remote --symref origin HEAD` (the server, not the cached
  `origin/HEAD`, which can be years stale), validated with
  `git rev-parse --verify`; stop if they disagree. The trunk is named in
  the report.
- **Prompted Codex pass for playbooks, prompts, plans, docs and config**,
  alongside the built-in review: walk each changed section as an agent
  executing it literally. Findings on lines the change neither touches nor
  exercises are reported as PRE-EXISTING and never block. A whole-repo
  walkthrough is a separate periodic audit (new README tip).
- **Blind Claude leg.** Claude writes its findings to disk before opening
  either external output, on the same baseline question as the others, so
  the agreement tags mean something.
- **Graded findings.** BLOCKER means a failure caused or exposed by this
  change; Codex's P0-P3 map onto the grades; a toolchain-wide concern is at
  most SHOULD; severity belongs to the leg that raised it. Open BLOCKERs
  mean the review recommends against merging; the user decides.
- **Every finding is verified, agreed ones included**, against what was
  reviewed (HEAD, or the patch for uncommitted work), never the base
  commit, where new lines do not exist.
- **Standing risks** the user keeps are matched by reference, with "made
  worse by this change: yes / no"; yes is a BLOCKER again, and Claude never
  adds to the list.
- Optional run log of counts only; misses are logged when they surface.

## 2.9.0 (2026-10-02)

`/tri-plan` convergence, from its own run history: every recorded run used
all three rounds, and two ended with changes no critic ever saw (one with
ten amendments made after the cap). The proposal behind this release was
itself tri-reviewed; two of its ideas (change-only rounds, dropping a lens
early) were cut because they would have weakened the final-plan guarantee.

- **Claims table.** The plan records its base commit and ends with every
  API, flag, config key and credential path it relies on, and how each was
  checked. Checks are read-only; anything needing a live call or a
  credential is `UNVERIFIED`. Lens A re-checks every row rather than
  trusting it, and names claims the table is missing.
- **Numbered, graded points.** Critics number each point and grade it
  BLOCKER / SHOULD / NIT with typed evidence (file:line, command output,
  config fact, or "needs an operator fact"). SOUND and AUTHORIZE mean no
  open BLOCKER. Severity is the critic's: the plan's author can rebut, not
  downgrade. Open SHOULDs reach the user with their risk; NITs never block.
- **Full plan every round, every lens every round**, with changes marked
  and the points ledger attached; each critic answers its open points
  before raising new ones.
- **No unreviewed changes.** Anything changed after a critic's last look,
  including post-cap amendments, is shown as `UNREVIEWED`, and the plan is
  never called signed off while any exists.
- **Gemini citations are re-checked** against the base commit
  (`git show <base>:<path>`); it has cited stale checkouts even when run
  from inside the right worktree.
- The approval summary gains a per-round table of open points per critic
  and lens. An optional, redacted run log records hits and misses
  (`MISSED-BY-ALL`), so the cost of each critic and lens can be measured.
- From this release's own /tri-review (Claude, Codex review + operations
  pass, Gemini; 18 findings, 2 rejected and conceded on rebuttal):
  critics are now told how to answer the ledger from round 2 (without it
  they re-review from scratch); "never present an unseen plan" and the
  `UNREVIEWED` label no longer contradict each other; Lens A, which now
  re-checks credential rows, gets the same credential-store ban as Lens B,
  and the table names credentials by identifier only; `--help` probes are
  limited to installed third-party CLIs; Gemini citations are re-checked
  quoted, and against the working tree when the plan builds on uncommitted
  changes; scratch files are deleted on any exit; the PR gets a plan
  summary, not the claims table; the run log is only written to a file the
  user has named.

## 2.8.0 (2026-09-27)

Second audit pass: Codex and Gemini each walked every skill as an agent
executing it literally (81 raw findings, deduplicated, each checked against
the text; one rejected by test: `git worktree add` into a fresh `mktemp -d`
directory works).

- **`/tri-decide` and `/tri-strategy` now send Codex its instructions.**
  Both piped the bare brief or evidence pack to `codex exec -`, which takes
  stdin as its whole prompt, so the ask, the lens, and the MISSING FACT rule
  never arrived. Same bug class `/tri-research` fixed in 2.4.0.
- **Cross-examination carries each leg's own earlier answer.** Every CLI
  call is a fresh session, so "what do these account for that yours did
  not?" referred to nothing.
- **`/tri-research` splits the ledger before auditing.** Step 3 sent the
  whole ledger to web-enabled auditors while its Notes forbade first-party
  rows there. Scratch paths are now real (`$WORK`), outside the repo; the
  Gemini leg's MCP servers are disabled for the audit.
- **`/tri-review` never touches the real index.** Untracked files are
  marked in a throwaway index copy (`GIT_INDEX_FILE`), replacing 2.7.0's
  add/reset pair, so an interrupted run cannot leave staging changed. It
  stops on an empty patch and on untracked secret-looking files.
- **The operations pass says who runs it and how**: plain `codex exec` with
  the patch inlined (`review` cannot take a custom prompt with a scope).
- **Reviews no longer grant shell network**; running a diff's code for the
  state-machine check happens only in a disposable, credential-free place.
- `/tri-plan`: the round cap covers DO-NOT-AUTHORIZE too; a human
  reviewer's conflicting requirement revises the plan and waits for
  approval instead of being implemented; Lens B may read the plan file.
- `/dual-plan` co-coder commits to the branch the feature started on and
  removes its worktree.
- Every skill deletes its scratch files, says where sibling skills live
  under a plugin install, and has a fallback if `/code-review` is absent;
  the receipt schema path is the skill's base directory, not `/path/to/`.
- `/tri-strategy` minimizes the evidence pack before it leaves the machine
  and no longer claims `/tri-research` checks first-party numbers.
- From this release's own review (Codex + Gemini, all 4 accepted): the
  operations-pass command now creates its prompt files (both legs caught
  it); the temp-index `git add` has no pathspec, so running from a
  subdirectory still catches untracked files repo-wide; the ledger receipt
  quotes the first retained public row; MCP servers are restored to their
  prior state, not all enabled.

## 2.7.0 (2026-09-27)

- **Every `codex exec` closes stdin (`< /dev/null`).** `codex exec` waits
  for stdin to reach EOF even when the prompt is an argument, and even for
  `review`, so a background shell with an open stdin hung forever at 0%
  CPU (measured on codex-cli 0.146: 51 s with a pipe held open for 45 s,
  5 s with `< /dev/null`). Fixed in `/dual-review` and `/tri-review` (review
  and rebuttal) and the `/dual-plan` co-coder, which also gains the
  config-isolation flags. Review legs write the final review with `-o`.
- **Model gate is decidable again.** "At least as new as Fable 5.1" could
  not rank Opus 5.5. The gate now passes the newest release available of
  a top-tier family (2026-09: Fable 5.1 or Opus 5.5) and stops on fast
  tiers or on a release whose family has a newer one available.
- **`/tri-review` no longer unstages your work.** The uncommitted-scope
  step marked every untracked file intent-to-add and then said to undo
  with a bare `git reset`, which unstaged everything. It now adds and
  resets exactly the untracked files, guarded against an empty list (an
  empty `--pathspec-from-file` also resets the whole index; verified on
  git 2.54). The patch is written inside the same block, before the
  reset; the first draft reset first and would have dropped the files
  (caught by this release's own review).
- **Critics are told to stay out of credential stores.** `/tri-plan` Lens B
  said "you may read any file needed", and in a real run a Gemini critic
  opened `~/.claude.json`. Lens B and `/tri-review`'s operations pass now
  scope reads to the repository and name credential paths as off-limits.
- **`/tri-research` Gemini auditor setup.** Headless `agy` denies
  `read_url_content` unless the domain is allowlisted, which killed the
  leg; the skill now says to add per-domain `read_url(...)` rules and never
  to allowlist `curl` instead.
- **Nothing is left behind.** Temp files (patch, untracked list, Codex
  output) are deleted after success or failure; `/tri-research`'s Gemini
  URL grants are restored from a copy after the audit, and `/tri-strategy`
  re-enables any `agy` MCP server it disabled (`agy mcp disable` persists).
- `/tri-review` notes: `codex exec review` accepts a custom prompt only
  without `--base`/`--uncommitted`, and silently ignores `--output-schema`
  (both verified).
- `/tri-strategy` no longer claims the trigger "decide this with all
  three", which collided with `/tri-decide`.
- README: a "What leaves your machine" section, the stdin and Gemini
  allowlist tips, about 35 sentences the em-dash pass left garbled, and a
  duplicated paragraph removed.
- `scripts/check.sh` + a GitHub Action: valid JSON, skill names match
  their directories and appear in the README and manifests, the version
  matches the CHANGELOG, no em-dashes, no `codex exec` with an open stdin,
  no unguarded `git reset --pathspec-from-file`.

## 2.6.1 (2026-09-03)

- Style only: every em-dash in the README and the seven skills recast
  (headings take a colon, prompt output formats use `|`, the rest commas).
  No command, flag, or rule changed; the receipt contract in the Gemini
  prompt now reads `INSPECTED: <n> | <first header>` and findings as
  `file:line | issue | why`.

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
