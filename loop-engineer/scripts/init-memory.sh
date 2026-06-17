#!/usr/bin/env bash
# init-memory.sh — scaffold the durable memory dir for a loop.
#
# Creates docs/loops-engineering/memory/<topic>/ and writes ONLY the generic files
# (run-log.md, budget.md). Goal-specific state files are authored by the agent
# afterwards — this script does not invent domain state.
#
# Emits JSON on stdout: { "memoryDir": "...", "created": [...] }
#
# Usage: init-memory.sh --topic <slug> [--project-dir <path>]

set -euo pipefail
umask 077

TOPIC=""
PROJECT_DIR="$(pwd)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --topic)       TOPIC="${2:-}"; shift 2 ;;
    --project-dir) PROJECT_DIR="${2:-}"; shift 2 ;;
    *) printf '{"error": "Unknown argument: %s"}\n' "$1"; exit 1 ;;
  esac
done

if [[ -z "$TOPIC" ]]; then
  printf '{"error": "--topic is required"}\n'; exit 1
fi
# slugify: lowercase, non-alnum -> dash, collapse, trim
SLUG="$(printf '%s' "$TOPIC" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
if [[ -z "$SLUG" ]]; then
  printf '{"error": "--topic produced an empty slug"}\n'; exit 1
fi

MEM_DIR="${PROJECT_DIR}/docs/loops-engineering/memory/${SLUG}"
mkdir -p "$MEM_DIR"

CREATED=()

RUNLOG="${MEM_DIR}/run-log.md"
if [[ ! -f "$RUNLOG" ]]; then
  cat > "$RUNLOG" <<EOF
# Run log — ${SLUG}

Append one row per iteration. Audit trail + cost. Newest at the bottom.

| # | timestamp | action | result | check verdict | est. tokens | notes |
|---|-----------|--------|--------|---------------|-------------|-------|
EOF
  CREATED+=("$RUNLOG")
fi

BUDGET="${MEM_DIR}/budget.md"
if [[ ! -f "$BUDGET" ]]; then
  cat > "$BUDGET" <<EOF
# Budget — ${SLUG}

- **Max iterations:** <set during design>
- **Token budget (total):** <optional>
- **Per-iteration ceiling:** <optional>
- **Stop if exceeded:** yes — halt and escalate.

Loops are token-heavy. Keep these bounds explicit.
EOF
  CREATED+=("$BUDGET")
fi

# Safe empty-array expansion (macOS bash 3.2 + set -u).
if [[ ${#CREATED[@]} -gt 0 ]]; then
  CREATED_LIST=("${CREATED[@]}")
else
  CREATED_LIST=()
fi

# JSON output (python3 for safe escaping; fall back to plain if absent)
if command -v python3 >/dev/null 2>&1; then
  MEM_DIR="$MEM_DIR" python3 - ${CREATED_LIST[@]+"${CREATED_LIST[@]}"} <<'PY'
import os, sys, json
print(json.dumps({"memoryDir": os.environ["MEM_DIR"], "created": sys.argv[1:]}, indent=2))
PY
else
  joined=""
  if [[ ${#CREATED_LIST[@]} -gt 0 ]]; then
    joined="$(printf '"%s",' "${CREATED_LIST[@]}" | sed 's/,$//')"
  fi
  printf '{"memoryDir": "%s", "created": [%s]}\n' "$MEM_DIR" "$joined"
fi
