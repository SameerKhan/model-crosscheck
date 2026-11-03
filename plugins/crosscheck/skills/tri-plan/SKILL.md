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

**Aim: converge in at most 3 complete rounds.** A run that took 12 showed
where rounds go: early correctness rounds found wrong readings of existing
behaviour the claims table never listed (step 1); decisions only the user
could make stayed open BLOCKERs for rounds after a critic had named them
(OWNER-DECISION, step 3); new blockers kept landing on the previous round's
fixes (step 3, "check the fix"); and one critic first returned both lenses
on the same version in round 10 (step 4, complete rounds).

> **Sibling skills.** `/dual-review`, `/tri-review` and the rest name the
> other skills in this set. Installed as the plugin, invoke them as
> `/crosscheck:<name>`; as plain copies, as `/<name>`. Either way their
> files sit next to this one, so "see /tri-review's Notes" means
> `../tri-review/SKILL.md` relative to this skill's base directory.

## Model per leg: pin all three

| Leg | Model | Where it's set |
|---|---|---|
| **Claude** (plan draft, adjudication, implementation) | the newest available release of a top-tier Claude family (2026-09: Fable 5.1 or Opus 5.5) | the session model, see below |
| Codex critic | the CLI's default under config isolation, read the `model:` line Codex prints at startup; `-c model=...` to override | `--ephemeral --ignore-user-config -s read-only`, effort forced to `high` |
| Gemini critic | the newest Gemini on the plan (2026-10: `gemini-4-argon-high`, a floor, not a pin) | `--model` on every `agy` call |

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

- On the newest release available to you of a top-tier family
  (Fable/Opus-class; as of 2026-09, Fable 5.1 or Opus 5.5; the names date,
  the rule does not) → proceed. A `[1m]` context-window suffix on the model
  id is the same model.
- On a fast/cheap tier (Haiku/Sonnet-class), or a top-tier release whose
  family has a newer one available (as of 2026-09, Fable 5 or Opus 5) →
  **stop before step 1**, say which model the Claude leg would
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
| `mktemp -d` (the run folder) | `New-Item -ItemType Directory -Path (Join-Path $env:TEMP ("tri-plan." + [guid]::NewGuid().ToString('N')))` |
| `openssl rand -hex 4` | `[guid]::NewGuid().ToString('N').Substring(0,8)` |
| `chmod 444 <file>` | `Set-ItemProperty <file> -Name IsReadOnly -Value $true` |
| `rm -rf "$RUN"` | `Remove-Item -Recurse -Force $RUN` |
| `~/.codex/config.toml` | `$env:USERPROFILE\.codex\config.toml` (or `$env:CODEX_HOME\config.toml`, `CODEX_HOME` is the directory, not the file) |
| `~/.gemini/antigravity-cli/settings.json` | `$env:USERPROFILE\.gemini\antigravity-cli\settings.json` |

`codex` and `agy` are on PATH on Windows when installed normally, the
`~/.local/bin/agy` fallback and the `codex-code-mode-host` symlink trap are
macOS/Linux-only. All CLI flags, the convergence rules, and the round cap are
identical on every platform.

## Steps

0. **Set up the run folder.** Create it OUTSIDE every repo, in the
   session's scratch directory if it has one, else `${TMPDIR:-/tmp}`:
   `mktemp -d "<that directory>/tri-plan.XXXXXX"` (mode 700), writing the literal directory path in place of the placeholder. Check it exists and
   is not inside a git work tree (`git -C "$RUN" rev-parse
   --is-inside-work-tree` must fail). Scratch files inside a repo would
   pollute a later `--uncommitted` review scope or get committed by
   accident, and a fixed name collides with a concurrent run. Every working
   copy this run makes (prompts, plan snapshots, critic outputs and logs)
   lives in it. Gemini also keeps its own copy of each conversation;
   deleting the folder does not remove that. Record `REPO` (the target
   repo's absolute root, `git rev-parse --show-toplevel`) and `BASE` (`git
   rev-parse HEAD`).
   **Document review with no repo:** stage the documents in `$RUN`, set
   `REPO` to `$RUN` and `BASE` to `none`, skip every git command in this
   skill except the run-folder check above (which applies in both modes),
   run the critics from `$RUN`, add `--skip-git-repo-check` to
   `codex exec` only, and re-check citations against the staged files.
   **Shell variables do not survive between Bash calls** in most agent
   harnesses: write the literal run folder, repo and base into every
   command (`$RUN`, `$REPO`, `$BASE` below stand for those literals), and
   start every command that writes a file with `umask 077`.

1. **Scope the feature.** Explore the codebase as usual (respect the repo's
   CLAUDE.md conventions and known landmines). Write `$RUN/plan.md` in two passes. First: a first line naming the
   version (`# <title> (v<V>)`), the repo root and base commit, the
   `OWNER QUESTIONS` section (below) and the **claims table**. Round 0
   (step 1b) checks those. Only then add the plan itself after them (goal,
   files to touch, approach, data-shape changes, risks, test plan).

   **One plan per risk level.** If the work mixes a low-risk part (copy,
   styling, docs) with a part that touches data shape, auth, tenancy,
   credentials, queues or deploy, propose a split in `OWNER QUESTIONS`
   (default: split). Each resulting plan gets the full process; splitting
   never shortens review. A plan that ships first must be safe to ship
   alone, and its Lens B judges that. A critic may object to the split (or
   to not splitting) like any other point.

   **The claims table** has one row per API, function, CLI flag, config
   key or credential the plan relies on, **and one row per behaviour of
   existing code the approach depends on**: which value wins when two
   sources disagree (a header vs a query parameter), what happens on a
   missing or failed read (fail open, reject, default), what a library call
   returns for the actual type, which scope a request resolves to and from
   where. Each row says what is assumed and how it was checked (file:line
   of the definition, `--help` output, the vendor's docs). Checks are
   **read-only**: read the source, read docs, and run `--help` only on
   installed third-party CLIs, never on the repo's own scripts (a script
   that ignores its arguments simply runs). Name a credential by its
   identifier (env var, secret name), never by opening the store that
   holds it. A behaviour that reading cannot settle, and anything that
   would call a live service, touch data, or need a credential, is marked
   `UNVERIFIED` rather than probed, unless the user approves that specific
   call or script (propose it in `OWNER QUESTIONS`: what it runs, what it
   imports, what it can reach). The table is a set of assertions for the
   critics to attack, not facts they inherit: a plan that cannot run
   usually fails on one of these rows, and Claude's own checks share
   Claude's blind spots.

   **`OWNER QUESTIONS`.** If the plan touches something a specific person
   is accountable for (see "A human who owns the resource", below), list
   each question for them, with the safe default the plan uses until it is
   answered, and mark each `LOAD-BEARING` (the answer could change scope,
   privilege, credentials, retention or behaviour) or not. Give the list to
   the user before round 0; they send it, or name the channel Claude may
   send it through. Round 1 waits for the LOAD-BEARING answers unless the
   user says to proceed on the defaults; the others run alongside the
   rounds. None: write "OWNER QUESTIONS: none".

1b. **Round 0: claims pass, Codex only.** Before writing the approach,
   send Codex the plan so far (header, owner questions, claims table) with
   this prompt, from `$REPO`:

   > The file named on the CLAIMS line below is the claims table of a plan
   > that has no approach yet; read it first.
   > Do NOT edit files; read the repository to check it. Re-check every
   > row yourself in the source (do not trust its "how checked" column)
   > and mark it CONFIRMED / WRONG / UNVERIFIABLE with file:line. Then
   > list behaviours of the code these rows name that an approach would
   > depend on and the table omits: precedence between sources, failure
   > and default behaviour, return types, scope resolution. Do not judge
   > the missing approach, files, blast radius or tests. Never open
   > credential stores (`~/.claude.json`, `~/.codex/`, `~/.gemini/`,
   > `~/.aws/`, `~/.ssh/`, `.env*`, keychains). Begin your reply with one
   > line: `PLAN: <that file's first line, verbatim>`. End with the
   > line `Verdict: CLAIMS-CHECKED`.
   > CLAIMS: <absolute path of the round-0 snapshot>

   Snapshot, command, output and validity follow step 2's rules with attempt `<K>` = 0 (its only verdict is `CLAIMS-CHECKED`). Fix every WRONG row,
   add every missing row, then draft the approach. Round 0 does not count
   toward the cap and needs no sign-off; Gemini re-checks every row in
   round 1. Round 0 is Codex only because Gemini's quota is usually the
   scarce resource. It also shows early whether Codex is up.

2. **Critique gate: four passes per round, in parallel, in the
   background.** Two critics times two lenses = **four** Bash calls with
   `run_in_background: true`. **Freeze the version first.** Check that
   `git -C "$REPO" rev-parse HEAD` still equals `BASE`; if it does not, the
   code moved: update the plan's base, re-check the claims it touches, and
   treat it as a new version. Also check the tree is clean:
   `git -c core.fsmonitor=false -C "$REPO" status --porcelain` must print
   nothing, so every critic reads exactly `BASE`. On a dirty tree, stop
   and ask the user to commit the work the plan builds on (or to approve
   the exact files Claude may commit), then use that commit as `BASE`;
   never commit or stash it unasked. Nobody edits `$REPO` while a round
   runs. Then, in one command, write the snapshot
   `$RUN/plan-v<V>-a<K>.md` as a new first line
   `# <title> (v<V>, attempt <K>, nonce <openssl rand -hex 4>)` followed by
   `plan.md` without its first line, `chmod 444` it, and record its sha256.
   `<V>` is the plan version and `<K>` the attempt: it goes up by one at
   every freeze and is never reused, so a void or incomplete round never
   collides with an earlier read-only snapshot. The round cap counts
   complete rounds only, and "round 2" below means the second complete
   round. Every prompt names that snapshot, never the live `plan.md`. Each attempt
   writes to new files (`mktemp "$RUN/a<K>-<critic>-<lens>.XXXXXX"` for the
   output, the same name plus `.log` for stderr and stdout), so a failed
   attempt can never leave an older output that looks valid, and nothing a
   critic prints lands outside `$RUN`. Each prompt is written to a file in `$RUN` first. Each command runs as one Bash call, so `OUT` is set where it is used. Run from the repo so each critic reads the right tree and
   Codex loads its AGENTS.md:

   ```bash
   umask 077
   OUT=$(mktemp "$RUN/a<K>-codex-<lens>.XXXXXX")
   cd "$REPO" && codex exec --ephemeral --ignore-user-config -s read-only -c model_reasoning_effort="high" -o "$OUT" - < "$RUN/a<K>-prompt-codex-<lens>.md" > "$OUT.log" 2>&1
   ```

   ```bash
   umask 077
   OUT=$(mktemp "$RUN/a<K>-gemini-<lens>.XXXXXX")
   cd "$REPO" && agy --sandbox --model <newest-gemini-on-plan> --print-timeout 25m -p "$(cat "$RUN/a<K>-prompt-gemini-<lens>.md")" > "$OUT" 2> "$OUT.log"
   ```

   Pass `-s read-only` (Codex) and `--sandbox` (Gemini) explicitly, a
   critic must never touch the tree. Remember `agy -p` does NOT read stdin:
   the prompt must name the snapshot's absolute path for Gemini to
   `read_file`; passing it as `"$(cat file)"` avoids quoting breakage from
   backticks or `$` in the ledger. Gemini gets 25 minutes here: at 15 it
   timed out on a large plan.

   **A pass is valid only if** its output file is non-empty, its first
   line quotes the snapshot's first line with the right nonce (Codex:
   `PLAN: <line>`; Gemini: the READ line below), and it has exactly one
   line `Verdict: <v>` with `<v>` one of the verdicts its prompt defines
   (the prompt's last line asks for it, see "Assemble each prompt" below). Anything else is a failed
   pass, whatever the exit code. After all four passes return, recompute
   the snapshot's sha256, HEAD and the clean-tree check: if any changed,
   the round is void, not retried; freeze a new version and start the
   round again. A pass still running after 30 minutes (Codex has no
   timeout of its own) is stopped and counts as failed.

   **Two lenses, not one prompt.** Send each critic BOTH lenses as
   **separate passes**, never a single merged prompt. Lens A asks whether
   the plan is *right*; Lens B asks whether you would *let it run*. They
   surface different defect classes, and a plan can pass A completely while
   failing B in ways that damage production.

   For Gemini, prepend to each lens: "Read the plan at <ABS_PATH> with
   read_file first. Use only the read_file and grep_search tools; do not
   run shell commands. Begin your reply with one line: READ: <the plan
   file's first line, verbatim>, or FILE-NOT-READ if you could not open
   it." A SOUND or AUTHORIZE without that READ line is a failed run, not a
   sign-off, the hollow-verdict failure is reproduced, not hypothetical
   (see /tri-review's Notes): check whether the critique cites the plan's
   actual content; if not, discard it, re-check the path, and re-run once.
   A run that dies with "required the command permission" tried a shell
   command: re-run once with the tool rule repeated; never widen the
   allowlist for it. For Codex, prepend: "Read the plan file named on the PLAN line at the end of this prompt first (it is outside the repo). Begin your reply with one line: PLAN: <the plan file's first line, verbatim>."  The nonce in that line
   exists only in this round's snapshot, so the echo proves the critic
   read that file.

   **Both lens prompts carry this paragraph** (Lens B drops the
   sentence on the claims table, except for rows that bear on privilege,
   data or cleanup):
   > This is your one complete pass at this version. List every BLOCKER
   > and SHOULD you can find now; do not hold any back for a later round.
   > Go through the claims table row by row (CONFIRMED / WRONG /
   > UNVERIFIABLE) before your other points. If a point can only be
   > settled by a fact or a preference that only the operator or a named
   > resource owner holds (a retention term, whether a credential may be
   > used, a product choice), mark it `OWNER-DECISION` in addition to its
   > severity, say exactly what must be decided, and say whether the
   > plan's stated default for it is safe to run on. If every BLOCKER you
   > still hold is an OWNER-DECISION whose default you judge safe, your
   > verdict is `SOUND-PENDING-OWNER` (Lens A) or
   > `AUTHORIZE-PENDING-OWNER` (Lens B), listing those points.

   **Assemble each prompt in this order:** the critic's preamble (Gemini or
   Codex, above); the lens text (below); from round 2, the ledger appendix
   (below); the closing paragraph above; the `PLAN:` line; and last the
   line "Put your verdict on its own line, `Verdict: <verdict>`, as the
   last line of your reply." Nothing comes after it.

   **Lens A, correctness:**
   > You are reviewing an implementation plan for this repository (read the
   > code to check every claim; AGENTS.md, or CLAUDE.md if there is no
   > AGENTS.md, has project context, when present). Do NOT implement
   > anything, do NOT edit files. Verify the plan's claims against the
   > files and symbols it names. Do not tour the repo at large. The plan
   > has a claims table: re-check EVERY row yourself in the source
   > (do not trust its "how checked" column), mark each CONFIRMED / WRONG /
   > UNVERIFIABLE, and name any load-bearing claim missing from the table.
   > For a credential row, confirm the code reads that identifier; never
   > open credential stores (`~/.claude.json`, `~/.codex/`, `~/.gemini/`,
   > `~/.aws/`, `~/.ssh/`, `.env*`, keychains). Find: (1) factually wrong assumptions
   > about the codebase, (2) missed files, call sites, or cross-repo blast
   > radius, (3) simpler alternatives, (4) risks/edge cases the plan
   > ignores, (5) anything in the test plan that wouldn't catch a
   > regression. Be specific, cite file paths.
   >
   > Number every point (P1, P2, ...) and give each a severity: BLOCKER
   > (wrong or unsafe as written), SHOULD (a real gap the plan could ship
   > with, at a stated risk), or NIT. Give each point its evidence: a
   > file:line, command output, a config fact, or "needs an operator fact".
   >
   > Verdict: SOUND (no open BLOCKER) / SOUND-PENDING-OWNER / NEEDS-CHANGES.
   >
   > PLAN: <snapshot path> (sha256 <hash>)

   **Lens B, authorization / operations:**
   > You are deciding whether to AUTHORIZE this plan to run, assume it will
   > execute unattended, against production, with the credentials the
   > operator already holds. Do NOT implement anything, do NOT edit files.
   > You may read the plan file and any file inside the repository needed
   > to answer these.
   > Never open credential stores (`~/.claude.json`, `~/.codex/`,
   > `~/.gemini/`, `~/.aws/`, `~/.ssh/`, `.env*`, keychains): if an answer
   > depends on one, name the fact you needed instead. Check: (1) what
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
   > behind. Be specific, cite file paths.
   >
   > Number every point (P1, P2, ...) and give each a severity: BLOCKER
   > (wrong or unsafe as written), SHOULD (a real gap the plan could ship
   > with, at a stated risk), or NIT. Give each point its evidence: a
   > file:line, command output, a config fact, or "needs an operator fact".
   >
   > Verdict: AUTHORIZE (no open BLOCKER) / AUTHORIZE-PENDING-OWNER / DO-NOT-AUTHORIZE.
   >
   > PLAN: <snapshot path> (sha256 <hash>)

   **Lens B's read scope is not boilerplate.** "Would you authorize this?"
   invites a critic to go and inspect the operator's setup. In a real run,
   the earlier wording ("you may read any file needed") led a Gemini
   critic straight to `~/.claude.json`. `-s read-only` and `--sandbox`
   block writes, not reads of absolute paths, so the prompt is the only
   fence: state the config facts the lens needs inline, with secret values
   removed, rather than letting a critic fetch them.

   **From round 2,** append to each lens prompt the compact ledger (open
   points in full; closed points by ID and one line) and the plan's change
   log for this version, then: "First answer each of YOUR open points:
   RESOLVED or NOT RESOLVED, with why, citing the revised plan. Then read
   the change log and name any entry that breaks something elsewhere in
   the plan or the code, or write `CHANGE-LOG: OK`. Then raise only new
   points, numbered on from your last list. A point you raised earlier
   stays open until you mark it RESOLVED." Without this the critics
   re-review from scratch and the ledger cannot close. The appended text
   never tells a critic how to label or grade a specific point ("mark it
   OWNER-DECISION", "do not repeat this argument"): that is a rebuttal,
   and goes in the ledger as one, with its evidence.

   **The executable-claim check (in Lens A) is the highest-value single
   rule here.** A plan that says "inject the credentials at call time"
   against a function whose signature takes no credentials is a plan that
   cannot run, and that gap is invisible to anyone reviewing only the
   plan's prose. Confirm the capability in the source, not the intent.

   The "verify, don't tour" line matters for Gemini especially, an
   unconstrained agent wanders the repo and exceeds `--print-timeout` with
   no output.

3. **Merge and adjudicate.** Dedupe the critique lists into one **points
   ledger** (ID, critic, lens, severity, the point, its disposition), then:
   - **Both critics raised it**: treat as near-certain, revise the plan
     (only reject with strong code evidence, stated in the ledger).
   - **One critic raised it**: verify against the code first; accept
     (revise) or reject with the reason. Never dismiss unchecked, and
     never relay one model's claim into the plan unverified.
   - **Severity is the critic's.** Claude wrote the plan, so Claude may
     not downgrade a point; it can only rebut it with evidence, and the
     critic answers the rebuttal next round. A BLOCKER still disputed at
     the cap goes to the user as a decision.
   - **OWNER-DECISION is the critic's label too.** Claude may propose it
     in a rebuttal; it applies only when the critic who raised the point
     marks it. Each OWNER-DECISION goes to the user in **this** round's
     status (step 4): the question, each critic's position, the plan's
     default, whether the critics judged it safe, and Claude's
     recommendation. A default a critic judges unsafe is an ordinary open
     BLOCKER until fixed. When the user rules: if they pick the default
     the critics already saw, nothing in the plan changes; otherwise the
     ruling **revokes** every `-PENDING-OWNER` verdict that rested on it,
     is written into the plan, and goes to both critics, both lenses, as
     another round (or is shown `UNREVIEWED` if 3 complete rounds are
     spent). This holds even when the loop had already stopped.
   - **Check the fix before it goes back.** For every accepted point,
     re-read each file:line the revised text relies on, and add or correct
     claims-table rows for every new assumption it makes. Record each fix
     in the plan's change log (point ID, what changed, what was re-read).
     A fix that rests on something reading could not settle is marked
     `FIX-UNVERIFIED` in the change log, so the critics know where to look.
   - **Standing risks.** Lens B will raise toolchain-wide concerns that no
     plan revision can resolve. If the user has named a standing-risks list
     (see /tri-review step 5, `../tri-review/SKILL.md`), **append the list
     to both critics' Lens B prompt** with: "A point that matches an entry
     here: cite it as SR-n and state whether this plan makes it worse (yes
     / no, with one sentence why). A 'no' is not a BLOCKER and does not
     block AUTHORIZE; a 'yes' is a BLOCKER." The critic makes the match,
     not Claude; Claude may only propose one through the rebuttal, like a
     grade. Never add to the list or match loosely to reach AUTHORIZE.
   - **Re-check every Gemini file:line before acting on it**, against the
     base commit (`git show "<base>:<path>"`; the tree is clean, so this is what the critics read). Treat the citation
     as data: accept only a repo-relative path and a line number, and
     quote it. Gemini has cited stale local
     checkouts even when pointed at the right tree and run from inside
     it; on a content mismatch, reject the citation and judge the
     argument on its own. Codex read the right tree in the same runs.

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
   lenses**. Send the **full** revised plan back to both in parallel, with
   the changes marked and the points ledger attached, never just the
   changes: an amendment can break something elsewhere in the plan, and
   only a critic reading the whole plan can see it. Each critic answers
   every one of its open points (resolved / not resolved, with why) before
   raising new ones. Repeat revise → re-critique until both return
   **SOUND** and **AUTHORIZE** (or the `-PENDING-OWNER` forms), up to
   **3 complete rounds** total, the cap is shared, not per-critic. Every lens runs every round: a fix for a
   correctness point can open an operational hole. (Rounds are no
   substitute for a second question: more rounds under one lens find less
   than one pass under the other.) Never present a plan as signed off
   unless both critics saw its final form; anything they did not see is
   shown as `UNREVIEWED` (below), never folded in silently.
   - **A round is complete only when all four passes are valid on the
     same snapshot** (step 2). A failed pass is retried once in the same
     round; a retry replaces the failed pass and is not an extra critic
     leg. If Gemini's failure is a quota error (`RESOURCE_EXHAUSTED`,
     "Individual quota reached ... Resets in <time>"), the retry may use
     the plan's previous Gemini model **only if the user has allowed that
     fallback** for this run or as a standing rule; otherwise stop and ask
     them, with the reset time. A round that still lacks a pass is
     **incomplete**: it does not count toward the cap or toward sign-off,
     and its status says which pass is missing and why. After an
     incomplete round, stop and ask the user: run the whole round again
     later as a new round (for example after a quota reset; it is a new
     round, not a further retry), or continue explicitly as /dual-plan
     (named so on every later report). There is no third option: a plan is
     never presented as tri-plan reviewed with a critic missing.
   - **Status to the user after every round**, not only the last: open
     BLOCKER and SHOULD counts per critic and lens, the verdicts, which
     Gemini model ran, new OWNER-DECISION points with their defaults, and
     any incomplete pass. The user can rule mid-run; the rounds do not
     wait unless every open BLOCKER is an OWNER-DECISION.
   - If either critic still says NEEDS-CHANGES or DO-NOT-AUTHORIZE after
     round 3, stop looping:
     present the plan WITH each unresolved disagreement as a named decision
     point, who holds which position and your recommendation, and let the
     user rule. Never paper over a disagreement to fake consensus, and
     never keep looping past 3 rounds (models can trade nits forever).
   - A critic that keeps raising NEW nits each round (rather than defending
     old ones) is churning, not converging, after round 3 that also goes
     to the user as-is. NITs never block; they go in an appendix.
   - **No unreviewed changes.** Anything changed after a critic's last
     look, including amendments made after the cap, is marked
     `UNREVIEWED` in what the user sees, and the plan is never described
     as signed off while any exists. Whether to spend a fourth round on
     the final text is the user's call, not a reason to skip the label.

5. **User approval.** Present the converged plan with a short section
   covering: what each critic changed; a per-round table of open BLOCKER
   and SHOULD counts per critic and lens, with the verdicts, marking
   incomplete rounds and round 0; which Gemini model ran each pass; every
   SHOULD still open, with its stated risk; every OWNER-DECISION with its
   default, the critics' safety judgement and the user's ruling or "not
   yet ruled"; every `UNREVIEWED` change and `FIX-UNVERIFIED` entry; every
   [disputed] point. The user approves before any code is written, and not
   while an OWNER-DECISION or a resource owner's gate (below) is open. A
   ruling that differs from a reviewed default sends the plan back to step
   2 (step 3, OWNER-DECISION) before approval.

6. **Implement.** Claude writes the code (Claude holds the tools, memory,
   and repo context). Neither critic edits the working tree, multiple
   writers on one tree causes conflicts.

7. **Close with /tri-review** (the sibling skill) on the finished diff
   before any PR/merge. When the run ends for any reason, including a
   rejected plan or a failed critic: confirm none of this run's background
   passes is still running (stop any), then `rm -rf "$RUN"` and check the
   folder is gone, reporting it if not, unless the user asked to keep it.

   The PR description gets a summary of the approved
   plan, not the claims table or the critiques.

   **If the user has named a run-log file** (outside any repo; never
   create one yourself, and do not ask on every run), append one line per
   run with only these fields: date, a short slug, rounds (complete and
   incomplete), final verdict per critic and lens, open-point counts per
   round, Gemini model per round. When
   /tri-review or production later finds a defect the plan stage should
   have caught, log it too, credited to the critic and lens that raised
   it or as `MISSED-BY-ALL`. Without the misses, the log can only count
   hits, and cannot tell which critic or lens earns its cost. Never log
   plan text, code, secrets, or customer data.

## A human who owns the resource is a third reviewer class

If the plan touches something a specific person is accountable for, the
production database, the deploy pipeline, the cloud account, route it past
that person **before round 1**, through step 1's `OWNER QUESTIONS`, not
after. They are not
a slower critic; they ask a different question, because they are the one
who gets paged. In practice their review lands the operational blockers
(enforced privilege, egress exposure, retention) that correctness-focused
review does not reach, and it lands them in one pass.

Treat their sign-off as a **gate**, not a data point, and give them the
same lens B checklist so the ask is concrete.

If such a reviewer requires a change that contradicts the written spec or
brief, do **not** silently pick a side: revise the plan to the safer,
more reversible option, define exactly one behaviour so an unattended run
is never ambiguous, and escalate the conflict to whoever owns the brief.
Nothing is implemented until the user approves the revised plan (step 5).

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
- Gemini gets a longer `--print-timeout` here (25m vs review's 8m),
  checking a plan's claims against real code takes more reading than
  reviewing a patch file.
- **Gemini quota is usually the scarce resource.** A full round is two
  Gemini calls; plan for at most about six per plan. A quota reset days
  away is the user's call (wait, allow the fallback, or /dual-plan),
  raised the moment it appears.
- If one critic CLI is unavailable (not installed / auth broken), say so
  and offer to fall back to /dual-plan rather than silently running with
  one critic under a three-critic banner.
- The co-coder variant (a critic implementing a separable piece in an
  isolated worktree) is documented in /dual-plan, it applies unchanged;
  use it only when the user asks.
