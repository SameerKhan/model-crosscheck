# Standing risks: crosscheck toolchain (example)

A starter list of the systemic risks every /tri-review and /tri-plan run on
this toolchain carries. **Copy it somewhere you control and edit it**: the
plugin directory is replaced on every update. Then name its path in your
repo's CLAUDE.md or AGENTS.md (for example `Standing risks:
docs/standing-risks.md`), or when you invoke the skill. The skills use a
list only when you have named one.

How it is used: a review finding that matches an entry is reported by
reference (SR-n), with "made worse by this change: yes / no" and one
sentence of evidence for a "no". **Yes makes it a BLOCKER again.** A
systemic finding not on the list goes to you as a normal finding: the
agent never adds, edits or loosens an entry, and never matches loosely to
clear a gate. Only you change this file.

Each entry names concrete triggers for "made worse", so the yes / no is a
check, not a judgement call. Delete entries that do not apply to you, and
add your own the same way.

## SR-1: The sandboxes block writes, not reads

**Accepted:** `codex exec -s read-only` and `agy --sandbox` stop the external
legs changing anything, but each can read any file your user account can,
including credential stores. The prompts' bans on `~/.claude.json`,
`~/.codex/`, `~/.gemini/`, `~/.aws/`, `~/.ssh/` and `.env*` are text only.
**Made worse if the change:** widens what a leg is told it may read; removes
or weakens a credential-store ban; drops `-s read-only`, `--sandbox`,
`--ephemeral` or `--ignore-user-config` from any command; gives an external
leg MCP servers or new tools.

## SR-2: Safety rules are prompt-only

**Accepted:** approval gates, "never log", redaction, the blind Claude leg,
"do not run commands" and scratch-file cleanup are instructions an agent
follows, not capabilities it lacks.
**Made worse if the change:** moves a property from a command flag into
prose; removes a gate or a "never" rule; makes an unconditional gate depend
on the agent's own judgement.

## SR-3: Work leaves the machine

**Accepted:** diffs, plans, briefs, evidence packs and any repo file a leg
opens go to OpenAI and Google under your accounts' terms.
**Made worse if the change:** sends a new category of data to an external
leg: first-party business data, other repositories' code, secrets, customer
data, or untracked files not shown to you first.

## SR-4: Gemini keeps every conversation

**Accepted:** `agy` has no no-persist flag; every Gemini leg is saved under
`~/.gemini/antigravity-cli/conversations/`, which grows by hundreds of MB a
month under regular use. Keep it at mode 700 and purge it periodically
(skip files modified in the last hour, in case a run is live).
**Made worse if the change:** sends more sensitive data to Gemini, adds
Gemini runs without a reason, or loosens the directory's permissions.

## SR-5: No process supervision

**Accepted:** legs run as background jobs with no signal-trap cleanup; an
interrupted run can leave temp files (private, via `mktemp`) and processes.
**Made worse if the change:** adds long-lived processes, tunnels or
browsers; writes sensitive data outside `mktemp` files; puts temp files
inside a repo; removes a cleanup instruction.

## SR-6: Headless Gemini auto-approves its global allowlist

**Accepted:** `agy -p` auto-approves whatever is in `permissions.allow` of
`~/.gemini/antigravity-cli/settings.json`, for every headless run. Keep it
to read-only commands and per-domain `read_url(...)` rules.
**Made worse if the change:** adds a `command(...)` rule that can write,
execute or reach the network (`bash`, `sh`, `node`, `curl`, `git`, `sed`,
`find`, ...); adds a write tool or an unscoped `read_url(*)`; or tells an
agent to use `--dangerously-skip-permissions`.

## SR-7: The optional run log is lightly specified

**Accepted:** a run log you name has no locking, permission check or
retention rule.
**Made worse if the change:** logs anything beyond counts (diff text, code,
finding text, customer data), or writes the log inside a repo.
