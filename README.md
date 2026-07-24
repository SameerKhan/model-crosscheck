# dual-ai — two (or three) models, one codebase

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
3. **Google Antigravity CLI** (`agy`) — only for `/tri-review` and
   `/tri-plan`; authenticated with a Google plan login (run `agy` once
   interactively to sign in).

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
/plugin marketplace add SameerKhan/dual-ai-skills
/plugin install dual-ai@dual-ai-skills
```

Plugin-installed skills are namespaced: invoke them as `/dual-ai:dual-plan`,
`/dual-ai:dual-review`, `/dual-ai:tri-plan`, and `/dual-ai:tri-review`. (If
they don't show up immediately, restart Claude Code.)

**Option B — plain copy** (skills appear unnamespaced as `/dual-plan`,
`/dual-review`, `/tri-plan`, and `/tri-review`):

```bash
git clone https://github.com/SameerKhan/dual-ai-skills
mkdir -p ~/.claude/skills
cp -r dual-ai-skills/plugins/dual-ai/skills/* ~/.claude/skills/
```

Windows (PowerShell):

```powershell
git clone https://github.com/SameerKhan/dual-ai-skills
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\skills"
Copy-Item -Recurse -Force dual-ai-skills\plugins\dual-ai\skills\* "$env:USERPROFILE\.claude\skills\"
```

(Or into a repo's `.claude/skills/` to share it with just that team/project.)

Either way, you can also just say **"dual plan this feature"**,
**"tri plan this feature"**, **"dual review this branch"**, or
**"tri review this branch"** in Claude Code — no slash command needed.

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

## License

MIT
