---
name: tri-strategy
description: Decide a business or strategy question with Claude, OpenAI Codex, and Google Gemini arguing from three deliberately different lenses: unit economics, competitive positioning, and execution capacity, over the same evidence pack. Produces a strategy memo with what each option bets on, the cruxes resolved against real data, and a revisit trigger. Use when the user says "tri strategy", "strategy decision", "decide this with all three", or faces a hard-to-reverse business decision (pricing, packaging, market focus, build-vs-buy, hiring shape, GTM motion).
---

# Tri strategy (Claude + Codex + Gemini, three lenses)

The business sibling of /tri-decide. Same adversarial machinery, three
changes that matter, the models argue from **assigned lenses** rather than
as generalists, they reason over an **evidence pack you assemble** rather
than a codebase they can read, and **no number may be invented**.

## Read this before running it

**The other two models cannot see your business.** In /tri-review and
/tri-decide, Codex and Gemini earn their seat by reading the actual code,
they check claims against ground truth. Here, **by default**, they have no
access to your billing system, your product analytics, your support inbox,
or your customers. Left to themselves they reason from generic priors, and those
priors skew hard toward US venture-backed SaaS: grow-at-all-costs, move
upmarket, land-and-expand. For a bootstrapped team, a price-sensitive
market, or a non-US cost base, that advice arrives confidently and is
frequently wrong.

Two consequences, both load-bearing:

1. **The evidence pack does the work** (step 1). Without real numbers in
   the brief, this skill produces three consultants riffing. With them, it
   produces three genuinely different readings of your actual situation.
2. **Value shifts from verification to structure.** In a code review, most
   of the value is independent checking. Here most of it is the forcing
   function: stating what each option bets on, finding the crux, refusing
   to deliberate over reversible choices, writing down a revisit trigger.
   Be honest with the user about that, do not present model consensus as
   though it were evidence.

**That default is enforced, not assumed.** The step 2 commands run Codex
config-isolated (`--ephemeral --ignore-user-config`), so a
`~/.codex/config.toml` that wires billing or database MCP servers stays out
of the run. The Gemini side has no such flag, `--sandbox` restricts the
terminal, not MCP tools, so run `agy mcp list` first: if it shows an
enabled server, `agy mcp disable <name>` for the run, or do not make the
pack-only claim. Only then do the legs see the pack and only the pack. If a
first-party number needs a second
model's re-derivation, that is /tri-research's job under its confidentiality
rules, not a licence to hand a lens leg production access mid-argument,
because a web-enabled model holding production data is an exfiltration
path.

**Agreement is not signal**, even more so than in /tri-decide. Three
models trained on overlapping corpora will converge on the same strategy-
blog consensus. Treat convergence as an unexamined default and challenge
it explicitly; treat divergence as the product. Never score options
numerically.

## Model per leg: pin all three

| Leg | Model | Where it's set |
|---|---|---|
| **Claude** (evidence pack, one lens, crux resolution, the memo) | the newest top-tier Claude available (2026-09: Fable 5.1, then Fable 5, then Opus 5) | the session model, check before step 0 |
| Codex | the CLI's default under config isolation, read the `model:` line Codex prints at startup; `-c model=...` to override | `--ephemeral --ignore-user-config -s read-only`, effort forced to `high` |
| Gemini | the newest Gemini on the plan (2026-09: `gemini-3.8-flash-high`, a floor, not a pin) | `--model` on every `agy` call |

Claude assembles the evidence, argues a lens, resolves the cruxes, and
writes the memo, more load-bearing than in any sibling skill, which is
also why the conflict of interest below must be stated out loud. If the
session is not on the newest top-tier Claude the plan offers (the dated
example, Fable 5.1 as of 2026-09, is a floor that goes stale, not the
rule: a newer top tier also passes, and a `[1m]` suffix is the same
model), say so and ask the user to switch
before step 0; stop only for fast/cheap tiers (Haiku/Sonnet-class) or a
top tier older than the example, and if you genuinely can't classify the
session model, name it and ask. Pin any subagent this skill spawns to the
same tier explicitly (`model`, not just `subagent_type`).

## Cross-platform

Snippets below are bash/zsh. On PowerShell: `Get-Content brief.md | codex
exec ... -` (PowerShell reserves `<`), and `(New-TemporaryFile).FullName`
for `mktemp`. All flags and rules are otherwise identical.

## Step 0: the "don't use me" gate

Classify the decision first, and say the class out loud:

- **Reversible and cheap**: a pricing experiment on new signups, a
  landing-page test, a campaign, a reversible hire: **stop and say so.**
  Recommend running it and reading the result. Deliberation is the
  expensive way to learn something an experiment answers in two weeks.
- **Hard to reverse**: repricing an existing base, a public commitment,
  a platform or partner dependency, sunsetting a product, anything that
  touches customer trust or contracts, anything that takes a quarter of
  engineering to unwind: proceed.
- **Premise unverified**: the decision rests on an unchecked belief about
  what customers want, what a competitor charges, or what a platform's
  terms permit: **go verify it first** (step 3's method), then
  re-classify. A large fraction of strategy questions dissolve here.

Two extra questions for business decisions that do not arise in code:
**how long would it take to unwind, in months** (not "is it reversible",
almost everything is, at a price), and **who bears the cost if this is
wrong**, the user, their customers, or their team. Put both in the memo.

## Step 1: assemble the evidence pack (this is the skill)

The brief is not a question, it is a **question plus the facts**. Pull real
data before writing it, using whatever tools are available, billing and
revenue systems, the product database, analytics, support transcripts,
competitor pricing pages fetched live. Then write ONE file (`mktemp`)
containing:

- **The decision**: as a scoped question with a time horizon.
- **The numbers, inline and dated.** Revenue and its composition, the
  relevant cohort or segment splits, churn, ARPA, unit costs, runway,
  team size and who is actually free to work on this. Every figure gets a
  source label. Do not paste a dashboard link, the other two models
  cannot open it.
- **Verbatim customer evidence** where relevant, real quotes from support
  or sales, not summarized sentiment.
- **Hard constraints**: cash, headcount, what the user refuses to do, what
  was already tried and why it failed.
- **What "this worked" looks like** at a named date, in a number.

**If the numbers are load-bearing, run /tri-research on the pack first**,
it is the only skill here that checks them. Without it, a wrong figure in
the pack propagates through both critiques untouched (they are forbidden
from inventing numbers, so they faithfully reason from yours) and lands in
the memo.

Then state the **information asymmetry** plainly in the brief: Claude
assembled this pack and holds the live tools; the other two legs know only
what is in this file. That is a limitation of their input, not a licence
to discount them, but it belongs on the record.

## Step 2: three lenses, in parallel, blind

Assign each leg a **different lens** and give all three the identical
evidence pack. Distinct lenses beat three generalists here: with no ground
truth to converge on, redundancy just triples the same prior, while
diversity surfaces the trade-off actually being made.

| Lens | Argues from |
|---|---|
| **Unit economics** | margin, payback, ARPA, cost to serve, what this does to the P&L in 12 months |
| **Competitive positioning** | where this leaves the user against named competitors, what it signals to the market, what it forecloses |
| **Execution capacity** | can this team actually ship and support it, at what opportunity cost, and what breaks if the timeline doubles |

Rotate which model gets which lens across runs, and **record the pairing**
in the memo. Then respect the consequence: **a lens split is not a model
split.** If the economics leg and the positioning leg disagree, that is the
lenses doing their job by construction, never report it as "the models
disagreed." Genuine model disagreement is only visible *within* a lens or
in step 4, when each is shown the others' cases.

Launch the external legs in the background first, then write Claude's own
lens **without opening their output**, blindness is on Claude to preserve.

```bash
codex exec --ephemeral --ignore-user-config -s read-only -c model_reasoning_effort="high" - < /path/to/brief.md
```

```bash
agy --sandbox --model <newest-gemini-on-plan> --print-timeout 12m -p "<brief, naming the evidence pack's absolute path to read_file>"
```

Require each external reply to open with one line, `READ: <the evidence
pack's first line, verbatim>` (or `FILE-NOT-READ`); a lens argument
without it means the pack was never read (see /tri-review's Notes on
hollow verdicts), discard it and re-run once. Ask each leg for exactly
this:

> You are arguing the **<LENS>** case. Read the evidence pack and
> recommend ONE course of action, reasoned from that lens specifically.
> Then, in the same response: (a) the strongest case AGAINST your own
> recommendation; (b) what would have to be TRUE for it to be right, the
> assumptions it bets on, stated so they could be checked; (c) the
> earliest observable signal that you were wrong.
>
> **Use only numbers that appear in the evidence pack.** If you need a
> figure that is not there, a market size, a benchmark rate, a
> competitor's price, do NOT estimate it. Name it as a MISSING FACT and
> say how the recommendation changes depending on its value. Inventing a
> plausible number is the worst thing you can do here.

That last paragraph is not optional. Fabricated benchmarks and
confidently-recalled market statistics are the single most common failure
mode of language models on business questions, and unlike a wrong claim
about code, nothing in this workflow would catch it.

## Step 3: cruxes and MISSING FACTS

Collect every MISSING FACT the three legs named, plus the factual
questions behind each real disagreement. Then **go answer the cheap ones
with live tools**, query the billing and product data, fetch the
competitor's own pricing page rather than trusting recall, read the actual
support transcripts, check the platform's published terms.

Most strategy arguments are factual disagreements wearing a costume. "Will
this segment pay more" is usually answerable from data already in hand,
and answering it collapses the debate faster than any amount of
deliberation.

Carry the unresolved ones forward as named unknowns with what it would
take to resolve each. An unresolvable crux is itself a finding: the
decision genuinely rests on something unknown, and the user should know
that before committing.

## Step 4: anonymized cross-examination (one round)

Send each leg the other two cases **stripped of both attribution and lens
label**, "Case A / B / C", plus the facts resolved in step 3. Models
defer to named authorities, and telling a model it is reading "the
economics case" invites it to concede on economics rather than think.

> Here are two alternative cases built on the same evidence, plus facts we
> verified since. What do they account for that yours did not? Would you
> change your recommendation, and if so, what specifically changed your
> mind? If not, name the one assumption on which you and the alternative
> genuinely differ.

Claude does the same. **One round, then stop.** There is no verdict to
converge toward.

## Step 5: the strategy memo

Write a dated memo to the user's docs directory:

1. **The decision, its class, months-to-unwind, and who bears the cost.**
2. **The evidence pack summary**: the numbers the whole thing rests on,
   with sources and dates, so a future reader can tell whether they have
   since moved.
3. **The three cases**: each labelled with its lens *and* its model,
   approach, what it bets on, strongest downside in its own words.
4. **Where all three converged**: flagged as unexamined default, plus the
   explicit "what might all three of us be missing" answer.
5. **Cruxes**: resolved (evidence + source) and unresolved (what it would
   take). Keep the MISSING FACTS list visible even when resolved, it
   shows which parts of the reasoning were data-free.
6. **What changed in cross-examination**: who moved, on what.
7. **Recommendation, with two disclosures**: which case Claude authored
   *and* that Claude assembled the evidence pack and holds the live tools.
   Hold Claude's own case to the harshest fact-checking of the three.
8. **Revisit trigger**: the observation that reopens this decision, never
   a date alone. For business decisions make it a metric with a threshold
   and a named owner who would notice.

**Out of scope, and say so:** founder conviction, team morale, investor
and partner politics, personal appetite for risk. The models cannot see
these and will not mention them; they frequently decide the matter. Name
them as the user's input, not an input this skill can supply.

Present it as a decision for the user to rule on. **This skill does not
decide.** When they choose, record the choice *and their reasoning*, the
reasoning is what a future reader needs most, and it is the thing that
makes the revisit trigger interpretable.

## Notes

- Plumbing (install, auth, sandbox flags, config isolation via
  `--ephemeral --ignore-user-config`, `-s read-only` doesn't cover MCP,
  and a leg holding billing/database MCP servers while parsing an evidence
  pack is the highest-stakes variant of that exposure, the `agy` no-stdin
  trap, the read-receipt contract) is shared with the sibling skills, see
  **/tri-review** and **/tri-decide** Notes. Sandbox flags are mandatory
  here too even though nothing is being built: an untrusted evidence pack
  is still untrusted input.
- Never pick a Claude or GPT-OSS model from `agy models`, one lab on two
  of three seats voids the independence the skill is built on.
- If one CLI is unavailable, run two lenses and **say which lens is
  missing**, the absent lens is exactly the blind spot the memo will
  have.
- Scale to the stakes: a medium decision can skip step 4 and say so. What
  must never be skipped is the evidence pack and the no-invented-numbers
  rule, without them this is three chatbots agreeing with each other.
- If the decision produces a build, `/tri-plan` then `/tri-review` are the
  next two gates.
