# Loop patterns — reference

Everything the dialogue needs to reason about. Load this when running `loop-engineering`.

---

## 1. What a loop is

You stop being the person who writes each prompt. You design the system that prompts
the agent. The agent checks state, decides, acts, gathers feedback, and judges itself —
iterating until the goal is met or it escalates to a human.

---

## 2. Six building blocks + Memory

| Block | Job in the loop |
|---|---|
| Automations / Scheduling | discovery + triage on a cadence |
| Worktrees | safe parallel execution isolation |
| Skills | persistent project knowledge |
| Plugins & Connectors (MCP) | reach into real tools |
| Sub-agents | maker / checker split |
| **+ Memory / State** | durable spine outside any conversation |

Compose the loop from these. Some are inferred from the harness scan (skills, sub-agents,
MCP); some are asked (scheduling, worktree); memory is derived from the goal.

For **sub-agents**, reuse a scanned agent (`agents[]` from the harness scan) for the
implementer/checker roles when one fits; otherwise define the maker/checker split inline.

---

## 3. The 5-step loop (per iteration)

1. **Check state** — read the memory/state files + run the check command.
2. **Decide** — pick the next action from current state.
3. **Act** — do the work (implementer sub-agent; calls skills/MCP/tools).
4. **Gather feedback** — test output, diff, screenshot, tool result.
5. **Verdict** — done or not. Update state. Continue only if the exit condition isn't met.

---

## 4. The 7 things to get right

1. **Context management** — control what enters context each turn; recent tool output
   buries the system prompt even with a huge window.
2. **Feedback quality** — the signal the agent reads to choose its next move (test
   output, UI screenshot, diff).
3. **Verification gates** — turn feedback into a clear done / not-done verdict.
4. **Termination condition** — an explicit stop rule; else it quits early or runs forever.
5. **Error handling** — what to do when a tool call fails, so state doesn't break.
6. **State across turns** — external files track progress as the window fills.
7. **Cost / token budget** — loops are token-heavy; bound them deliberately.

---

## 5. Deterministic vs non-deterministic

- **Deterministic** — a clear pass/fail check exists (tests/build/lint exit 0, audit
  clean). Verification gate = the command's exit code. Straightforward; the model knows
  exactly when it's done.
- **Non-deterministic** — fuzzy goal (improve clarity, triage, summarize). **Ask the
  user for the goal.** If no measurable check can be derived, the gate is **AI-as-judge**:
  a checker sub-agent evaluates the output against the stated goal.

The skill classifies first, then adapts the questions.

---

## 6. Verification gate vs guardrails (do not conflate)

- **Verification gate** answers *“is it done?”* → drives termination.
- **Guardrails** answer *“is this allowed?”* → forbidden paths/commands/actions the loop
  must NEVER cross. Skippable. On a violation the loop stops and escalates rather than
  proceeding.

---

## 7. State-derivation rubric

Persist a fact only if ALL hold:
- (a) **needed to resume** — without it the next iteration can't continue correctly;
- (b) **not recoverable** from the repo, git, or a tool call;
- (c) **changes across iterations** — static config belongs in the prompt, not state.

YAGNI on state. Smallest schema that survives a context reset.

| Goal | Derived state |
|---|---|
| PR babysitter | open-PR list + last-seen SHA per PR |
| Flaky-test triage | per-test `{ runs, pass, fail, verdict }` |
| Migration sweep | files done / files remaining |
| Daily triage | last-run timestamp + already-triaged item IDs |

`run-log.md` (audit + cost) and `budget.md` (iterations/budget) are generic — always
created by `init-memory.sh`, never "derived".

---

## 8. Scheduling → run mode

- **Scheduled** (user gave a time/cadence):
  - interval → `/loop <interval> <prompt>` (e.g. `/loop 15m …`)
  - cron / specific time → `/schedule` a routine carrying the prompt.
- **Run as goal** (user skipped scheduling) → self-paced until the exit condition:
  `/loop <prompt>` (no interval).

Prompt body is identical; only the run instruction differs.

---

## 9. Worktree env

- **Isolated worktree** — safe parallel execution; mutations don't touch the main tree.
  Requires `gitWorktreeCapable: true` from the scan. Use for risky/parallel loops.
- **Current dir** — simplest; the loop edits in place. Use for low-risk single-stream loops.

---

## 10. Safety levels (phased rollout)

- **L1 report-only** — observe and propose; no writes.
- **L2 assisted** — bounded fixes (e.g. patch-only), human reviews before merge.
- **L3 unattended** — full autonomy, only after gates pass consistently.

Always include a **human gate**: escalate risky/ambiguous actions with full context;
auto-proceed only on an explicit allowlist.

---

## 11. Emitted loop-prompt skeleton

Fill every `<…>` from the dialogue. Drop the guardrails line if the user skipped it.

```
Start "<name>" loop. Type: <deterministic | non-deterministic>. Goal: <end state>.
Env: <worktree <path> | current dir>.
Memory: read docs/loops-engineering/memory/<topic>/<state-files> before each pass;
        update them after each pass.
Max iterations: N. Budget: see budget.md.

Each pass (5 steps):
 1. Check state — read <state files> + run <check cmd>.
 2. Decide the next action.
 3. Act — implementer sub-agent; use skills [<…>], MCP [<…>].
 4. Verify — checker sub-agent / <check cmd> / AI-judge vs goal.
 5. Verdict — update <state files> + run-log.md. Continue only if exit not met.

Exit when: <condition>. On tool failure: <error handling>.
Guardrails — NEVER: <forbidden paths/commands/actions>. If a step would cross one,
        stop and escalate instead.
Human gate: escalate <risky actions> with full context; auto-proceed only on <allowlist>.
Safety level: L1 report-only | L2 assisted | L3 unattended.
Give a short status update each pass.
```
