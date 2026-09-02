---
name: tri-research
description: Research a factual question with Claude, OpenAI Codex, and Google Gemini: Claude gathers the facts and writes a claim ledger (every number dated and sourced), the other two re-fetch the sources and try to break it, then Claude re-verifies every disputed row against the page itself. Produces one ledger where every claim carries a status, confirmed by N auditors, corrected, disputed, unverified, unsourced, or single-source, rather than three merged reports. Use when the user says "tri research", "triple research", "verify these numbers", or before external facts (competitor pricing, platform capability, market claims) become load-bearing in a document or a hard-to-reverse decision.
---

# Tri research (Claude + Codex + Gemini, one ledger)

The **evidence layer** for the other skills. /tri-plan, /tri-decide and
/tri-strategy all reason over facts they assume are correct. This is the
only one that checks them.

## Read this before running it

The obvious design, give all three models the same question, let each go
research it, merge three reports, is the one to avoid. Three models
pointed at one question hit the same top search results, produce heavily
overlapping reports, and their agreement is one search sampled three
times. Worse, merging three prose reports is precisely where an unsourced
number survives, because nobody re-opens the link.

So this skill inverts the shape: **one researcher, two auditors, and a
ledger they can attack row by row.**

## The rule that makes this different from /tri-decide

**Agreement IS signal here**, the opposite of the decision skills. A
design opinion has no ground truth, so three models agreeing is one prior
sampled three times. A research claim has ground truth: a URL, a string on
a page, a query result. Two legs independently re-fetching and quoting the
same literal string is real confirmation.

**But majority is not truth.** Measured 2026-08-23, all three legs were
asked for the cheapest paid plan on `buffer.com/pricing`:

| Leg | Answer | Verdict |
|---|---|---|
| Gemini | "$6 / month per channel" monthly; "$5 / month per channel" annual | complete and correct |
| Codex | "$5/month per channel, billed annually at $60/year" | true, but only the annual term |
| Claude | "Monthly billing: $5/month per channel … Annual billing: $60/year" | wrong, and self-contradictory, "save 2 months" cannot follow from $5 × 12 = $60 |

One leg answered the question asked. The other two both produced the token
**$5** from *different billing terms*, so a merge that counted agreement
would have collapsed two different claims into one confident, wrong monthly
price.

Note what actually failed: **not fetching.** Every leg loaded the page. The
miss was **interpretation**, the pricing toggle defaults to annual, and
each leg silently answered a slightly different question. That is why the
ledger below demands literal strings rather than readings, and why step 4
resolves disputes by **re-reading the source, never by vote.**

## What it is actually for

In /tri-strategy the evidence pack is a **Claude monopoly**: Claude
assembles it, and the other two legs are explicitly forbidden from
inventing numbers, so a wrong figure in the pack propagates through both
critiques untouched and lands in the memo. /tri-decide's crux-verification
step has the same hole. That evidence layer is the largest unreviewed
failure point across these skills, and this is the skill that reviews it.

## Model per leg: pin all three

| Leg | Model | Where it's set |
|---|---|---|
| **Claude** (ledger, resolution, output) | the newest top-tier Claude available (2026-09: Fable 5.1, then Fable 5, then Opus 5) | the session model, check before step 0 |
| Codex | the CLI's default under config isolation, read the `model:` line Codex prints at startup; `-c model=...` to override | `--ephemeral --ignore-user-config -s read-only`, effort forced `high`, **web search enabled** |
| Gemini | the newest Gemini on the plan (2026-09: `gemini-3.8-flash-high`, a floor, not a pin) | `--model` on every `agy` call; web access on by default |

**Verified against codex-cli 0.146, do not re-derive:** `--search` is
**not** a valid flag on `codex exec`, it exists on the interactive TUI
only, and exec exits 2 with "unexpected argument". The working form is
`-c tools.web_search=true`, and it fetches fine under `-s read-only`,
because the tool is server-side rather than shell egress. `agy` needs no
flag at all; its `read_url_content` works under `--sandbox`.

If the session is not on the newest top-tier Claude the plan offers (the
dated example, Fable 5.1 as of 2026-09, is a floor that goes stale, not
the rule: a newer top tier also passes, and a `[1m]` suffix is the same
model), say so and ask the user to switch
before step 0; stop only for fast/cheap tiers (Haiku/Sonnet-class) or a
top tier older than the example, and if you genuinely can't classify the
session model, name it and ask. Pin any subagent this skill spawns to the
same tier explicitly (`model`, not just `subagent_type`).

## Cross-platform

Snippets are bash/zsh. On PowerShell: `Get-Content ledger.md | codex exec
... -` (PowerShell reserves `<`), and `(New-TemporaryFile).FullName` for
`mktemp`. All flags and rules are otherwise identical.

## Step 0: the "don't use me" gate

- **One fact, one authoritative source, uncontested**: what the project's
  own docs say, what shipped in a changelog: **fetch it and stop.**
- **Research feeding a reversible decision**: which topic to write about,
  which of two tools to trial for a week: do it solo and stop.
- **Proceed when** the facts become load-bearing in a hard-to-reverse
  decision or a document others will act on; when the claim is
  marketing-shaped (a competitor's capability, "X supports Y", pricing
  tiers, category statistics); or when /tri-strategy or /tri-decide is next
  and the evidence has to hold.

**A vendor's feature page is a marketing claim; their API reference is the
fact.** When the two disagree, the ledger records both and names which one
the decision actually depends on.

## Step 1: scope the question, then divide the search surface

Write the question scoped, with a time horizon, plus **what each claim will
be used for**, a claim nothing depends on does not belong in the ledger.

Then assign each leg a **surface**. Claude still writes the whole ledger,
the auditors do not research the question, so the assignment is not a
division of the initial search. It is the scope of the **coverage question**
each auditor answers in step 3 ("what is missing *on your surface*"), and it
is what makes their gap-finding non-redundant instead of three models
reciting the same top results:

| Leg | Surface it is accountable for |
|---|---|
| **Claude** | first-party, the user's own systems (billing, product database, analytics, support transcripts), the repo, internal docs. Claude searches this one; nobody audits it. |
| **Codex** | primary vendor sources, API references, changelogs, pricing pages, developer terms, status pages |
| **Gemini** | third-party, review sites, forums and communities, news, competitors' own customers |

Rotate the pairing across runs and **record it**. Claude's surface is the
one with no auditor, which is exactly why step 6 has to name the rows only
Claude ever touched.

Then state the access asymmetry plainly, because it decides what can be
verified at all: Codex can be given MCP servers in `~/.codex/config.toml`
and will load them in `codex exec`, so it may be able to re-run first-party
queries, but the audit legs in step 3 run config-isolated (`--ephemeral
--ignore-user-config`) precisely to keep that fleet away from web-fetched
untrusted pages, so first-party rows are Claude-only by construction unless
you deliberately run a separate non-isolated pass for them. Check `agy mcp
list` for the Gemini leg, if it has none, first-party rows can never be
verified by it, and any row neither leg could reach is a row only Claude
ever touched. The output says so.

## Step 2: the claim ledger

ONE file (`mktemp`). A markdown table, one row per load-bearing claim:

| ID | Claim | Value | As of | Source URL / query | How obtained + literal string |
|---|---|---|---|---|---|
| R1 | Buffer Essentials, monthly billing | $6/mo/channel | 2026-08-23 | https://buffer.com/pricing | fetched, "$6 per month per channel" |

Rules, each of which exists because of a specific failure:

- **Quote the literal string, never your reading of it.** The miss above
  was an interpretation error on a page all three fetched correctly.
- **No row may be sourced to recall.** Anything the model knows but did not
  fetch is `UNSOURCED` and goes to the critics as a target, not as a fact.
- **One claim per row.** A row containing "and" is two rows.
- **Numbers carry units, currency, and a billing term.** A price without a
  term is not a fact.
- **Include the rows you expect to survive.** The critics need a baseline,
  and the claims you are surest of are exactly where the misses hide.

## Step 3: refutation, in parallel

The other two legs are **not** researching the question. They are trying to
break the ledger.

First **build the audit file**, the brief *and* the ledger in one file, one
per auditor so each carries its own surface:

```bash
cat brief-codex.md ledger.md > audit-codex.md
```

This concatenation is not a nicety. **`codex exec -` treats stdin as its
entire prompt**, so piping the bare ledger sends a table with no
instructions, and Codex will summarise or answer it instead of auditing it.
The file you pipe must contain both.

```bash
codex exec --ephemeral --ignore-user-config --skip-git-repo-check -C /path/to/empty-dir -s read-only -c tools.web_search=true -c model_reasoning_effort="high" - < audit-codex.md
```

```bash
agy --sandbox --model <newest-gemini-on-plan> --print-timeout 12m -p "<brief, naming audit-gemini.md's absolute path to read_file>"
```

`-C` points Codex at an empty scratch directory (its audit arrives on
stdin), and `--skip-git-repo-check` is required with it: a non-git
directory otherwise trips Codex's trusted-directory check and the leg dies
before any model call, with piped stdin it hangs rather than failing
(verified on codex-cli 0.146). Gemini has no `-C`: write `audit-gemini.md`
alone into a scratch directory of its own and name that absolute path.
Neither is a confidentiality boundary, see Notes. The brief in each file:

> Attached is a claim ledger. Begin your reply with one line: READ: <row
> R1's Claim column, verbatim>, or FILE-NOT-READ if you could not open the
> file. For EVERY row: re-fetch the named source
> yourself and return **CONFIRMED / CORRECTED / UNVERIFIABLE**, with (a) the
> literal string you found, (b) the URL you actually fetched, (c) the date.
>
> A verdict with no fetch and no quoted string is not a verdict, return
> UNVERIFIABLE rather than guessing. Do not re-answer the research question.
>
> Then, separately, and **scoped to <YOUR SURFACE> only**: which
> load-bearing claims are **missing** from this ledger, and which specific
> search would find them?

Demand **one line per row ID**. Prose merges are exactly where an unsourced
number survives.

The anti-pattern to grep for is "looks right" with no URL. A row whose
verdict carries no fetched URL is UNVERIFIED, no matter how confidently it
was asserted.

## Step 4: resolve: the source, never the vote

Claude re-fetches every DISPUTED and every UNSOURCED row **itself** and
reads the literal string.

- **Three legs, same quoted string** → CONFIRMED.
- **Majority against minority** → re-fetch. If the minority's string is on
  the page, **the minority wins.**
- **Different strings from one URL** → both legs may have fetched honestly.
  Pages render differently per fetcher: JS toggles, geo-specific pricing,
  live A/B tests. Resolve by naming which variant was served, not by voting.
- **Still unresolved** → the row stays DISPUTED, carrying both readings and
  what would settle it. **Never average two numbers.**

## Step 5: the coverage gap (one round)

Take both critics' "what's missing" lists, dedupe against the ledger, run
the searches worth running, add the rows. **One round, then stop.**
Anything named and deliberately not run gets written down, a silent gap
reads as coverage.

**Rows added here have not been audited**, both auditors had already
finished when these were written. Mark every one of them `SINGLE-SOURCE`
and leave the mark in the final ledger. Step 6 presents a *verified* ledger,
and these rows have exactly one pair of eyes on them; letting them inherit
the ledger's credibility is the quiet way this skill would start lying. Send
them back for a second audit pass only if one of them is load-bearing enough
to carry the decision by itself.

## Step 6: output

Rewrite the ledger with a Status column, under a short brief:

1. **The question**: and what the claims will be used for.
2. **The verified ledger**: with source and date per row. The status
   vocabulary is closed, every row gets exactly one:

   | Status | Meaning |
   |---|---|
   | `CONFIRMED-BY-N` | N auditors re-fetched and quoted the same string |
   | `CORRECTED` | an auditor's re-fetch changed the value; carries old → new |
   | `DISPUTED` | readings conflict and re-fetching did not settle it |
   | `UNVERIFIED` | Claude sourced it, but no auditor could reach it (paywall, geo-block, login) |
   | `UNSOURCED` | nobody fetched it, it is recall wearing a citation |
   | `SINGLE-SOURCE` | added in step 5, after the auditors finished |

   Keep the last three visible in the output. They are the map of where this
   ledger is weakest, and burying them is how a verified-looking document
   ends up carrying an unchecked number.
3. **What changed in verification**: every corrected row, old → new, and
   which leg caught it. This is the skill's scoreboard. If nothing changed,
   say so plainly; it is the cheapest possible signal that the next run on
   this topic can be shorter.
4. **Coverage**: which surfaces were searched, which were not, and which
   rows only Claude ever touched.
5. **Disclosure**: Claude wrote the ledger *and* judged the disputes.

This file **is** /tri-strategy's evidence pack, or /tri-decide's verified
crux facts, hand it over directly rather than re-deriving it. Date it
prominently: a ledger goes stale, and competitor pricing goes stale fast.

## Notes

- Plumbing (install, auth, sandbox flags, the `agy` no-stdin trap) is shared
  with the sibling skills, see **/tri-review** and **/dual-review** Notes.
- **`-s read-only` and `--sandbox` are WRITE boundaries. They are not
  confidentiality boundaries, and this is the one skill in the family where
  that distinction bites.** Every sibling skill hands its auditors untrusted
  input with no way out; this one deliberately gives them **web egress**, and
  an auditor may also hold local file read and MCP servers wired to
  production data. A fetched page carrying "ignore previous instructions" can
  then induce a lookup and put the result **in a search query**, the query
  string itself is the exfiltration channel, and no write sandbox stops it.
  Two mitigations, both cheap:
  - **Never put a first-party row in front of a web-enabled auditor.** Rows
    sourced from billing, a production database, a support inbox, or anything
    with customer data are verified by Claude alone and reported as
    `UNVERIFIED` or as Claude-only coverage. The auditors get the
    public-source rows, which is all they can check anyway.
  - **Keep each auditor's working set empty**: Codex via `-C` into an empty
    scratch directory (its audit arrives on stdin), Gemini by placing
    `audit-gemini.md` alone in a scratch directory it reads by absolute
    path. This shrinks what a wandering read finds by default; it is not a
    boundary, `-s read-only` blocks writes, not reads of absolute paths.
    The `--ephemeral --ignore-user-config` flags in step 3 are the
    MCP-disabled profile this used to tell you to go build, they skip
    `config.toml` (auth still works) and keep the audit out of persisted
    session files.
- Nothing in this skill writes to the tree.
- Never pick a Claude or GPT-OSS model from `agy models`, one lab on two of
  three seats voids the independence the skill is built on.
- If one CLI is unavailable, run the other and **name the unverified
  surface.** Never silently absorb it.
- **Below roughly eight load-bearing claims, none of them contested, this is
  not worth running**, fetch them twice yourself. The cost is justified by
  claim count and by how marketing-shaped the claims are.
