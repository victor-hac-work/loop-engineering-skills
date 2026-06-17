# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-06-17

### Added
- **`loop-engineering` skill** — turns a rough idea into a production-grade, memory-backed
  agent loop and emits a `/loop`-ready prompt behind a human approval gate.
  - Classifies **deterministic vs non-deterministic** loops; non-deterministic goals get
    an **AI-as-judge** verification gate when no measurable check exists.
  - **Harness scan** (`scan-harness.sh`) — discovers installed skills, sub-agents, MCP
    servers, and hooks (+ git/worktree feasibility) as JSON.
  - **Goal-derived memory** — critiques the goal to persist only resume-critical state;
    `init-memory.sh` scaffolds generic `run-log.md` / `budget.md`.
  - **Guardrails** step (skippable) — forbidden paths/commands/actions, distinct from the
    done-gate.
  - **Scheduling** step — cadence/cron, or skip → run-to-goal.
  - **Worktree vs current-dir** env choice.
  - Loop-tuned **self-review subagent** before the approval gate.
- **Plugin marketplace packaging** — `.claude-plugin/marketplace.json` + `plugin.json`;
  installable via `/plugin marketplace add` + `/plugin install`.
- **CI** — bash syntax, ShellCheck, manifest validation, scan/init smoke + idempotency.
- **Banner** (`assets/banner.svg` / `.png`) and README with the loop-engineering model.

[1.0.0]: https://github.com/victor-hac-work/loop-engineering-skills/releases/tag/v1.0.0
