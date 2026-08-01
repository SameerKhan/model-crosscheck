# model-crosscheck — two (or three) models, one codebase

> **Renamed from `dual-ai-skills`.** Installed before 2026-07-25? Run
> `/plugin marketplace update dual-ai-skills`; the plugin is recognized as
> renamed and keeps working, but the skill namespace becomes `/crosscheck:*`.
> See [Renamed from dual-ai-skills](#renamed-from-dual-ai-skills).

[Claude Code](https://claude.com/claude-code) skills that put **Claude,
OpenAI's Codex CLI — and optionally Google's Gemini — in an adversarial loop**
on the same work, instead of trusting any one model alone:

- **`/dual-plan`** — Claude drafts an implementation plan, Codex critiques it
  against the actual codebase (read-only), Claude adjudicates each point, and
  they loop until Codex signs off **SOUND** (max 3 rounds — after that,
  unresolved disagreements are surfaced to you as a decision point, never
  papered over). You approve the converged plan before any code is written.
- **`/dual-review`** — before a merge, Claude's `/code-review` and
  `codex exec review` run **in parallel** on the same diff. The findings are
  merged: agreement between two different models is a strong signal;
  Codex-only findings are verified against the code before being reported
  (rejected ones get one rebuttal round); disputes are shown with both
  positions. Every finding is tagged `[both]`, `[claude]`, `[codex]`, or
  `[disputed]`.
- **`/tri-review`** — same idea with a **third independent reviewer**:
  Claude's `/code-review`, `codex exec review`, and Gemini (via Google's
  Antigravity CLI, `agy`) all review the same diff in parallel. Findings are
  ranked by cross-model agreement — all three > two > one — and Codex-only /
  Gemini-only findings are verified against the code before being reported.
  Tags:
  `[all]`, `[claude+codex]`, `[claude+gemini]`, `[codex+gemini]`,
  `[claude]`, `[codex]`, `[gemini]`, `[disputed]`.
- **`/tri-plan`** — `/dual-plan` with a **second independent critic**:
  Claude drafts the plan, Codex and Gemini critique it **in parallel**, and
  the revise loop runs until *both* sign off SOUND (same 3-round cap).
  Points both critics raise independently are treated as near-certain;
  single-critic points are verified against the code before the plan
  changes. Closes with `/tri-review` on the finished diff.
  Each critic runs **two separate lenses** — *is this correct?* and *would
  you authorize this to run?* — because reviewers who share one prompt
  share its blind spots, however many of them there are. Lens A includes an
  **executable-claim check**: open every API the plan says it will call and
  confirm the capability exists with the signature assumed.
- **`/tri-decide`** — for architecture and technology decisions rather than
  code. All three models propose an approach **blind** (none sees the
  others), each argues the strongest case *against its own* recommendation,
  then they cross-examine the alternatives **anonymized** so nobody defers
  to a name. The inversion that matters: unlike a code review, **agreement
  here is not signal** — three models trained on overlapping corpora share
  the same conventional wisdom, so convergence gets challenged as an
  unexamined default and *divergence* becomes the product. Output is a
  decision record — options, what each bets on, the cruxes (with the cheap
  ones actually verified), a recommendation that discloses which option
  Claude authored, and a revisit trigger. It declines to run on reversible
  decisions, and it never decides for you.
- **`/tri-strategy`** — the business sibling of `/tri-decide`, for pricing,
  packaging, market focus, GTM motion. Two things change, because the other
  models **cannot see your business**: you assemble an **evidence pack**
  (real numbers, inline, dated, sourced — they can't open your dashboards),
  and each model argues an **assigned lens** — unit economics, competitive
  positioning, execution capacity — because with no ground truth to check
  against, three generalists just triple the same prior while three lenses
  surface the actual trade-off. Every leg is forbidden from inventing a
  figure: anything missing is named a MISSING FACT and resolved with live
  tools, since fabricated benchmarks are the failure mode nothing else here
  would catch. Output is a strategy memo with months-to-unwind, who bears
  the cost, the cruxes, and a revisit trigger.

## Why this exists

Every AI coding agent has the same failure mode: **it reviews its own work
with the same blind spots it wrote it with.** A model that misread your
codebase while planning will misread it the same way while reviewing — and
it will sound just as confident both times. Self-testing is not review. We
learned this the hard way: changes that passed the authoring model's own
checks still shipped with real bugs that only an independent reviewer
caught.

The cheapest genuinely independent reviewer available is **a frontier model
from a different lab**. Claude and Codex are trained on different data with
different methods; they make *different* mistakes. That difference is the
product:

- **Agreement is signal.** When two unrelated models flag the same line,
  it's almost always a real bug — triage those first.
- **Disagreement is a map.** Findings only one model raises tell you exactly
  where human judgment is needed, instead of drowning you in one model's
  confident guesses.
- **Adversarial rules prevent rubber-stamping.** Every cross-model finding
  must be verified against the actual code before it reaches you; rejected
  findings get a concede-or-defend round; unresolved disputes surface to you
  with both positions rather than being papered over. Neither model gets to
  hallucinate unchallenged, and neither gets to wave the other through.

The result: fewer bugs reach your main branch, and the review you read is
pre-triaged by confidence instead of being one long unweighted list.

## Prerequisites

1. **Claude Code** (CLI, desktop, or IDE extension) — runs the skills.
2. **OpenAI Codex CLI** — `codex` on your PATH, authenticated
   (`codex login` or via the Codex desktop app).
3. **Google Antigravity CLI** (`agy`) — for every `tri-*` skill
   (`/tri-review`, `/tri-plan`, `/tri-decide`, `/tri-strategy`);
   authenticated with a Google plan login (run `agy` once interactively to
   sign in).

The first two are needed; the whole point is independent vendors. The third
adds a tie-breaker.

**Windows, macOS, and Linux are all supported.** The skills' command snippets
are written in bash/zsh, and each one carries a cross-platform table for the
handful of things PowerShell does differently — most importantly that
PowerShell **reserves `<`**, so the `codex exec - < prompt.md` stdin form
errors and must become `Get-Content prompt.md | codex exec -`. Temp-file
creation (`mktemp` → `New-TemporaryFile`) and config paths (`~/.codex` →
`$env:USERPROFILE\.codex`) differ too. Everything else — every CLI flag, the
merge logic, the convergence rules — is identical on all three.

## Install

Pick ONE of the two options — installing both registers duplicate skill
names, and the stale copy can shadow the auto-updating plugin.

**Option A — as a plugin (recommended):** in Claude Code, run

```
/plugin marketplace add SameerKhan/model-crosscheck
/plugin install crosscheck@model-crosscheck
```

Plugin-installed skills are namespaced: invoke them as `/crosscheck:dual-plan`,
`/crosscheck:dual-review`, `/crosscheck:tri-plan`, `/crosscheck:tri-review`,
`/crosscheck:tri-decide`, and `/crosscheck:tri-strategy`. (If they don't show
up immediately, restart Claude Code.)

**Option B — plain copy** (skills appear unnamespaced as `/dual-plan`,
`/dual-review`, `/tri-plan`, `/tri-review`, `/tri-decide`, and
`/tri-strategy`):

```bash
git clone https://github.com/SameerKhan/model-crosscheck
mkdir -p ~/.claude/skills
cp -r model-crosscheck/plugins/crosscheck/skills/* ~/.claude/skills/
```

Windows (PowerShell):

```powershell
git clone https://github.com/SameerKhan/model-crosscheck
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\skills"
Copy-Item -Recurse -Force model-crosscheck\plugins\crosscheck\skills\* "$env:USERPROFILE\.claude\skills\"
```

(Or into a repo's `.claude/skills/` to share it with just that team/project.)

Either way, you can also just say **"dual plan this feature"**,
**"tri plan this feature"**, **"dual review this branch"**,
**"tri review this branch"**, **"tri decide this"**, or **"tri strategy
this"** in Claude Code — no slash command needed.

## Not on Claude Code? (Cursor, Antigravity, etc.)

The SKILL.md files are plain-markdown playbooks — there's no code in them.
Two options:

- **Easiest:** install the Claude Code CLI and run it inside your IDE's
  terminal. The skills work anywhere the CLI runs.
- **Adapt:** paste the SKILL.md contents into your agent's custom
  instructions / workflow mechanism. Any agent that can run shell commands
  can drive the `codex exec` half; the merge-and-verify rules are
  model-agnostic. (You can also invert it — have Codex or Gemini drive and
  use `claude -p` as the second reviewer.)

## Tips learned the hard way

- **Always force Codex's reasoning effort to `high`** for reviews
  (`-c model_reasoning_effort="high"`). Default/low effort produces
  confident-sounding but shallow reviews.
- **Pin all three models, including Claude's.** It's easy to pin `--model`
  for Gemini and `-c` for Codex and then leave the Claude seat on whatever
  the session happened to be running. Claude's seat is the load-bearing one
  — it holds the repo context, verifies the other models' findings, and
  writes the merge — so run it on the strongest tier you have (Opus). The
  `/tri-*` skills now check the session model up front and stop rather than
  run a "triple review" with a downgraded Claude seat. Caveat worth knowing:
  `/code-review` does not necessarily inherit your session model — the
  official `code-review` plugin command fans out to Haiku and Sonnet workers
  — so the gate covers the main-loop verify/merge, and you should pin an
  explicit model if you need the finding-generation on Opus too.
- **Never let both models write to the same working tree.** One drives, the
  other critiques. The optional co-coder mode in `/dual-plan` uses an
  isolated `git worktree` for exactly this reason — and critique/review runs
  always pass an explicit sandbox flag (`-s read-only` for Codex,
  `--sandbox` for Gemini) rather than trusting the user's defaults. The
  diff under review is untrusted input; prompt-level "don't run commands"
  text is not a boundary.
- **Cap the argument loops** (3 rounds for plans, 1 rebuttal for reviews).
  Two LLMs will trade nits forever if you let them.
- **Keep an `AGENTS.md` in your repos** (Codex reads it automatically). A
  copy of your CLAUDE.md works — both models should see the same ground
  rules.
- **Gemini's `agy -p` does not read stdin.** Piping a diff in silently loses
  it and yields a hollow "CLEAN". Write the diff to a file and name the
  absolute path in the prompt.
- macOS Codex desktop app: if you symlink `codex` out of the app bundle,
  symlink its sibling `codex-code-mode-host` into the same directory too, or
  every run dies with "failed to spawn code-mode host". Check where `codex`
  actually points with `ls -l` — as of 2026-07 it lives in
  `/Applications/ChatGPT.app/Contents/Resources/`, not `Codex.app`.

## Renamed from dual-ai-skills

This repo was `SameerKhan/dual-ai-skills` until 2026-07-25. It shipped two
skills then; it ships four now, half of them three-model, so "dual" described
the wrapper badly. `model-crosscheck` names the mechanism instead — independent
models cross-checking each other — which stays accurate at two models, three,
or more.

The identifiers moved with it, in v2.0.0:

| | before | now |
|---|---|---|
| marketplace | `dual-ai-skills` | `model-crosscheck` |
| plugin | `dual-ai` | `crosscheck` |
| install | `dual-ai@dual-ai-skills` | `crosscheck@model-crosscheck` |
| namespace | `/dual-ai:tri-review` | `/crosscheck:tri-review` |

**The existing skill names did not change** — `dual-plan`, `dual-review`,
`tri-plan`, `tri-review` (`tri-decide` and `tri-strategy` were added after
the rename).
"dual" and "tri" are wrong as an umbrella but exactly
right at the skill level, where they tell you how many models that particular
workflow runs. So `/crosscheck:dual-plan` is not a typo: a two-model plan
inside the crosscheck plugin.

### If you installed before 2026-07-25

**Your install is not orphaned, but one thing does change.** Refresh first:

```
/plugin marketplace update dual-ai-skills
```

Claude Code then recognizes the rename — `/plugin list` marks the entry
*"Renamed to crosscheck"* — because this repo ships
`"renames": {"dual-ai": "crosscheck"}`. Two consequences, both verified
against Claude Code 2.1.215:

- **The plugin now answers to `crosscheck`, not `dual-ai`.** After the
  refresh, `crosscheck@…` resolves and `dual-ai@…` does not.
- **Your marketplace keeps its old registration key.** Claude Code does not
  re-key a marketplace when the manifest's `name` changes, so yours stays
  `dual-ai-skills` and the plugin is addressed as `crosscheck@dual-ai-skills`.
  (That is the *marketplace* key that's old, not the plugin name.)

**What actually breaks: the skill namespace.** Skills move from `/dual-ai:*`
to `/crosscheck:*`. Saved prompts, docs, or scripts that say
`/dual-ai:tri-review` must be updated to `/crosscheck:tri-review` by hand — no
mechanism can rewrite those for you.

**Optional, purely cosmetic** — if you want the marketplace to show up under
its new name too:

```
/plugin marketplace remove dual-ai-skills
/plugin marketplace add SameerKhan/model-crosscheck
/plugin install crosscheck@model-crosscheck
```

This step is manual because the `renames` map migrates a *plugin* name within a
marketplace; it cannot migrate a *marketplace* id.

**The one thing no mechanism can fix:** saved prompts, docs, or scripts that
say `/dual-ai:tri-review` need updating to `/crosscheck:tri-review` by hand.

**If your organization pins marketplace sources in managed settings** — via
`strictKnownMarketplaces` or `extraKnownMarketplaces` — note that those
allowlists match on the *source*, not the marketplace name: a marketplace
registered from a source that isn't allowlisted is ignored. Existing
registrations continue to work through the redirect, but before anyone adds
the marketplace fresh, an administrator should allowlist the new source:

```
SameerKhan/model-crosscheck
```

The old source (`SameerKhan/dual-ai-skills`) also still resolves via redirect,
so it can be kept alongside the new one during a transition.

## License

MIT
