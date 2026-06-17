#!/usr/bin/env bash
# scan-harness.sh — discover the user's loop-engineering primitives.
#
# Emits a single JSON object on stdout:
#   { "skills": [...], "agents": [...], "mcp": [...], "hooks": [...], "gitWorktreeCapable": bool }
#
# Usage: scan-harness.sh [--project-dir <path>]
#   --project-dir <path>  Project root to scan for .claude/ (default: cwd).
#
# Errors print {"error": "..."} to stdout and exit non-zero.

set -euo pipefail
umask 077   # skill/MCP/settings paths may embed secrets — keep anything we touch private

PROJECT_DIR="$(pwd)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir) PROJECT_DIR="${2:-}"; shift 2 ;;
    *) printf '{"error": "Unknown argument: %s"}\n' "$1"; exit 1 ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  printf '{"error": "python3 not found — required for JSON assembly"}\n'
  exit 1
fi

# git worktree feasibility: is the project dir inside a git work tree?
GIT_CAPABLE="false"
if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_CAPABLE="true"
fi

HOME_DIR="${HOME:-$HOME}"

# All scanning + JSON emission happens in python3 for safe escaping.
PROJECT_DIR="$PROJECT_DIR" HOME_DIR="$HOME_DIR" GIT_CAPABLE="$GIT_CAPABLE" python3 <<'PY'
import os, json, re, glob

project = os.environ["PROJECT_DIR"]
home = os.environ["HOME_DIR"]
git_capable = os.environ["GIT_CAPABLE"] == "true"

def read_frontmatter_desc(skill_md):
    """Pull `description:` from a SKILL.md YAML frontmatter block."""
    try:
        with open(skill_md, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError:
        return ""
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    block = m.group(1) if m else text[:2000]
    dm = re.search(r"^description:\s*(.+)$", block, re.MULTILINE)
    if not dm:
        return ""
    desc = dm.group(1).strip()
    if len(desc) >= 2 and desc[0] == desc[-1] and desc[0] in "\"'":
        desc = desc[1:-1]
    return desc.strip()

def read_frontmatter_field(path, field):
    """Pull an arbitrary `field:` from a markdown YAML frontmatter block."""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError:
        return ""
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    block = m.group(1) if m else text[:2000]
    fm = re.search(r"^%s:\s*(.+)$" % re.escape(field), block, re.MULTILINE)
    if not fm:
        return ""
    val = fm.group(1).strip()
    if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
        val = val[1:-1]
    return val.strip()

def scan_skills():
    seen, out = set(), []
    roots = [
        (os.path.join(home, ".claude", "skills"), "global"),
        (os.path.join(project, ".claude", "skills"), "project"),
    ]
    for root, scope in roots:
        if not os.path.isdir(root):
            continue
        for skill_md in sorted(glob.glob(os.path.join(root, "*", "SKILL.md"))):
            name = os.path.basename(os.path.dirname(skill_md))
            if name in seen:
                continue
            seen.add(name)
            out.append({
                "name": name,
                "scope": scope,
                "description": read_frontmatter_desc(skill_md),
            })
    return out

def scan_agents():
    """Sub-agents: markdown files with name/description frontmatter."""
    seen, out = set(), []
    roots = [
        (os.path.join(home, ".claude", "agents"), "global"),
        (os.path.join(project, ".claude", "agents"), "project"),
    ]
    for root, scope in roots:
        if not os.path.isdir(root):
            continue
        for md in sorted(glob.glob(os.path.join(root, "*.md"))):
            name = read_frontmatter_field(md, "name") or \
                os.path.splitext(os.path.basename(md))[0]
            if name in seen:
                continue
            seen.add(name)
            out.append({
                "name": name,
                "scope": scope,
                "description": read_frontmatter_field(md, "description"),
            })
    return out

def load_json(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None

def scan_mcp():
    seen, out = set(), []
    candidates = [
        os.path.join(home, ".claude.json"),
        os.path.join(home, ".claude", "settings.json"),
        os.path.join(project, ".mcp.json"),
        os.path.join(project, ".claude", "settings.json"),
        os.path.join(project, ".claude", "settings.local.json"),
    ]
    for path in candidates:
        data = load_json(path)
        if not isinstance(data, dict):
            continue
        servers = data.get("mcpServers")
        if isinstance(servers, dict):
            for name in servers:
                if name not in seen:
                    seen.add(name)
                    out.append({"name": name, "source": os.path.basename(path)})
    return out

def scan_hooks():
    seen, out = set(), []
    candidates = [
        os.path.join(home, ".claude", "settings.json"),
        os.path.join(project, ".claude", "settings.json"),
        os.path.join(project, ".claude", "settings.local.json"),
    ]
    for path in candidates:
        data = load_json(path)
        if not isinstance(data, dict):
            continue
        hooks = data.get("hooks")
        if isinstance(hooks, dict):
            for event in hooks:
                if event not in seen:
                    seen.add(event)
                    out.append({"event": event, "source": os.path.basename(path)})
    return out

result = {
    "skills": scan_skills(),
    "agents": scan_agents(),
    "mcp": scan_mcp(),
    "hooks": scan_hooks(),
    "gitWorktreeCapable": git_capable,
}
print(json.dumps(result, indent=2))
PY
