---
name: tri-decide
description: Decide an architecture or technology question with Claude, OpenAI Codex, and Google Gemini proposing independently and blind, then cross-examining each other's approaches anonymized. Produces a decision record — options, cruxes, what each bets on, a recommendation, and a revisit trigger — not a winner. Use when the user says "tri decide", "triple decide", "decide with all three", or faces a hard-to-reverse technical decision (datastore, framework, protocol, architecture, build-vs-buy).
---

# Tri decide (Claude + Codex + Gemini)

Three models propose an approach to the same problem **blind**, then
cross-examine each other's proposals anonymized. The output is a decision
record for the user to rule on — never a verdict this skill issues itself.

## The rule that makes this different from /tri-review

**Agreement is NOT signal here.** In /tri-review, two models flagging the
same line is strong evidence because the claim is checkable against the
code. A design question has no such ground truth, and these models share a
training corpus — three of them saying "use Postgres and Redis" is one
piece of conventional wisdom sampled three times, not three independent
confirmations. So invert the instinct:

- **Where they converge** → ask "what are all three of us missing?" as an
  explicit prompt. Fast unanimity on a genuinely hard question usually
  means the question was under-specified or everyone reached for the same
  default.
- **Where they diverge** → that is the product. Something is genuinely
  underdetermined there, and it is where the user's judgment is actually
  needed.

Never score or weight the options numerically. It manufactures precision
that does not exist.

## Model per leg — pin all three

| Leg | Model | Where it's set |
|---|---|---|
| **Claude** (proposal, crux resolution, adjudication, the record) | the strongest Claude tier available (Opus) | the session model — see below |
| Codex proposer | whatever `~/.codex/config.toml` pins | `-c` override, effort forced to `high` |
| Gemini proposer | newest Gemini on the plan | `--model` on every `agy` call |

Claude drafts an option, resolves the cruxes, judges the comparison, and
writes the record — more load-bearing here than in any sibling skill. Check
the active model (stated in the session's environment context; the user can
confirm with `/status`) **before step 1**. If it is not the strongest tier,
say which model the Claude leg would run on and ask the user to switch
(`/model opus`) rather than spending two CLIs on a weak proposal. Pin any
subagent this skill spawns to the same tier explicitly.

## Cross-platform — the snippets below are bash/zsh

| bash/zsh | PowerShell |
|---|---|
| `codex exec ... - < brief.md` | `Get-Content brief.md \| codex exec ... -` — PowerShell **reserves `<`** and errors on it |
| `mktemp` | `(New-TemporaryFile).FullName` |
| `~/.codex/config.toml` | `$env:USERPROFILE\.codex\config.toml` |

CLI flags, the round cap, and every rule below are identical on all
platforms.

## Step 0 — the "don't use me" gate

Before anything else, classify the decision:

- **Reversible and cheap** (a two-way door — swap it later in a day, no
  data migration, no external contract): **say so and stop.** Recommend
  picking the obvious option and moving. Three models deliberating over a
  reversible choice is ceremony, and it teaches the user to distrust the
  skill's judgment about when it matters.
- **Hard to reverse** (data-shape or schema commitments, public API or
  message-contract shape, vendor lock-in, anything other teams will build
  on, anything with a migration cost): proceed.
- **Premise unverified** — the decision rests on a claim about what some
  API, vendor, or subsystem can do that nobody has checked: **verify that
  first** (step 3's method), then re-classify. Half of these dissolve.

Say which class it is out loud. A skill that sometimes declines to run is
more trustworthy than one that always produces a deliberation.

## Step 1 — freeze the brief

Write ONE brief to a scratch file outside the repo (`mktemp`) and give
**all three legs the identical file**. Different briefs produce divergence
that is an artifact of the prompt rather than the problem. The brief must
contain:

- The decision, stated as a question with a scope boundary.
- Hard constraints: existing stack, team size, timeline, budget, what is
  explicitly non-negotiable, what has already been tried and rejected
  (and why).
- Code/context pointers — files, services, data shapes — so the proposals
  are grounded in this codebase and not in the abstract.
- Success criteria: what "this worked" looks like in 6 months.

A brief without constraints yields three generic blog-post answers. Most
of this skill's value is created in this step.

## Step 2 — blind proposals, in parallel

Launch both external legs in the background first (they take minutes),
then write Claude's proposal **without reading their output** — blindness
is the point, and it is on Claude to preserve it. Do not open the critic
output files until Claude's own proposal is written to disk.

```bash
codex exec -s read-only -c model_reasoning_effort="high" - < /path/to/brief.md
```

```bash
agy --sandbox --model <newest-gemini-on-plan> --print-timeout 12m -p "<brief, naming the brief file's absolute path to read_file>"
```

Sandbox flags are mandatory (`-s read-only`, `--sandbox`) — a proposer has
no business writing to the tree. Remember `agy -p` does not read stdin;
name the brief's absolute path in the prompt.

Ask each leg for exactly this, and require the same of Claude's proposal:

> Propose ONE approach to the decision in the brief. Then, in the same
> response: (a) state the strongest case AGAINST your own recommendation;
> (b) list what would have to be TRUE for your approach to be the right
> one — the assumptions it bets on; (c) name what you would need to
> measure or check to know you were wrong, and how early you would know.
> Ground every claim about the existing system in files you actually read
> — cite paths. Do not hedge across multiple options; commit to one and
> own its downside.

The self-adversarial half is not decoration. It does more to prevent a
confident wrong answer than the cross-model comparison does.

## Step 3 — extract cruxes and resolve the cheap ones

Diff the three proposals. For each real point of divergence, write the
**crux**: the factual question whose answer would collapse the
disagreement. Cruxes look like "does that vendor API actually support
batch writes?", "how many rows are in that table today?", "does the
existing consumer already handle this shape?"

Then **go answer the cheap ones** — fetch the vendor's own docs, query the
data, grep the code. Do not accept any model's memory as the answer to a
capability question; models state confidently what an API supported two
years ago, and a feature existing in a product's UI does not mean it
exists in its API. Most design disputes dissolve the moment one fact is
checked.

Carry unresolved cruxes forward explicitly. An unresolvable crux is a real
finding: the decision genuinely rests on something unknown, and the user
should know that before choosing.

## Step 4 — anonymized cross-examination (one round only)

Send each external leg the other two proposals **stripped of
attribution** — "Approach A / B / C", never "Claude's approach". Models
defer to named authorities and to whatever sounds like the house position;
removing labels buys an actual reconsideration. Include any crux facts
resolved in step 3.

> Here are two alternative approaches to the same brief, plus facts we
> verified since. What do these alternatives account for that yours did
> not? Would you change your recommendation — and if so, what specifically
> changed your mind? If you would not switch, name the one assumption on
> which you and the alternative genuinely differ.

Claude does the same exercise against the other two. **One round. Stop.**
Unlike /tri-plan there is no SOUND verdict to converge toward, and a
second round produces drift, not insight.

## Step 5 — the decision record

Write a dated decision record (ADR) to the repo's docs directory:

1. **The decision** and its class (from step 0).
2. **The options**, one section each — approach, what it bets on, its
   strongest downside in the proposer's own words from step 2.
3. **Where all three converged**, plus the explicit "what might we all be
   missing" answer. Flag convergence as *unexamined default* until it has
   been challenged.
4. **The cruxes** — resolved (with the evidence and its source) and
   unresolved (with what it would take to resolve them).
5. **What changed in cross-examination** — who moved, on what.
6. **Recommendation, with the conflict of interest stated plainly**:
   Claude authored one of these options *and* ran the comparison. Name
   which option is Claude's so the user can discount accordingly, and hold
   Claude's own option to the harshest fact-checking of the three.
7. **Revisit trigger** — the concrete observation that should reopen this
   decision ("if X exceeds N", "the second time a customer asks for Y",
   "when the migration cost drops below Z"). Never a date alone.

Decisions rot silently. The revisit trigger is what makes the record worth
keeping, and it is the part everyone skips.

Present it to the user as a decision to rule on. **This skill does not
decide.** Once the user picks, record their choice *and their reasoning*
in the record — the reasoning is what a future reader needs most.

## Notes

- Plumbing (install, auth, the `codex-code-mode-host` symlink trap, the
  `agy` no-stdin trap, keeping the Antigravity allowlist read-only) is
  shared with the sibling skills — see **/dual-review** and **/tri-review**
  Notes.
- Pass `--model` explicitly on the Gemini leg and use the newest Gemini
  flash-high tier your plan offers — a newer flash tier at high effort
  holds up on open-ended reasoning, not just patch review. Never pick a
  Claude or GPT-OSS model from `agy models`: that puts one lab on two of
  the three seats and voids the independence the skill is built on.
- If one CLI is unavailable, say so and offer the two-model version rather
  than running short under a three-model banner. With only two proposers,
  divergence has no tiebreaker — be explicit that the output is weaker.
- Scale to the stakes: for a medium decision, one blind round and a
  written record is enough; skip the cross-examination round and say that
  you skipped it.
- The facts gathered when resolving cruxes are themselves unreviewed —
  Claude fetches them and nothing checks them. If several are load-bearing,
  `/tri-research` is the gate for that.
- If the decision produces an implementation, `/tri-plan` and then
  `/tri-review` are the next two gates.
