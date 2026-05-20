#!/bin/bash
# Install cc-status-bg hooks into ~/.claude.
# - Copies selected hook scripts to ~/.claude/hooks/
# - Merges hook entries into ~/.claude/settings.json (preserves existing hooks)
# - Idempotent: safe to run multiple times
# - Backs up settings.json before modifying
#
# Usage:
#   bash install.sh                       # install all hooks
#   bash install.sh status-bg             # install only status-bg
#   bash install.sh mark-input            # install only mark-input
#   bash install.sh status-bg mark-input  # explicit list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_HOOKS_DIR="$SCRIPT_DIR/hooks"
TARGET_HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

ALL_HOOKS=("status-bg" "mark-input")

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

# Resolve which hooks to install.
if [ "$#" -eq 0 ]; then
    selected=("${ALL_HOOKS[@]}")
else
    selected=("$@")
    for h in "${selected[@]}"; do
        case " ${ALL_HOOKS[*]} " in
            *" $h "*) ;;
            *) red "ERROR: unknown hook '$h'. Available: ${ALL_HOOKS[*]}"; exit 1 ;;
        esac
    done
fi

if [ ! -f "$SETTINGS" ]; then
    red "ERROR: $SETTINGS not found. Is Claude Code installed and run at least once?"
    exit 1
fi

if ! python3 -c "import json; json.load(open('$SETTINGS'))" 2>/dev/null; then
    red "ERROR: $SETTINGS is not valid JSON. Fix it before running install."
    exit 1
fi

mkdir -p "$TARGET_HOOKS_DIR"

# Copy each selected script and collect its installed path for the registrar.
declare -a installed_paths=()
for name in "${selected[@]}"; do
    src="$SOURCE_HOOKS_DIR/$name.sh"
    dst="$TARGET_HOOKS_DIR/$name.sh"
    if [ ! -f "$src" ]; then
        red "ERROR: $src not found. Run install.sh from the repo root."
        exit 1
    fi
    cp "$src" "$dst"
    chmod +x "$dst"
    green "✓ Installed $dst"
    installed_paths+=("$name=$dst")
done

BACKUP="$SETTINGS.before-cc-status-bg-$(date +%Y%m%d-%H%M%S).bak"
cp "$SETTINGS" "$BACKUP"
green "✓ Backed up settings.json to $BACKUP"

# Hand the registrar a `name=path` map and let it know which to register.
python3 - "$SETTINGS" "${installed_paths[@]}" <<'PY'
import json, sys

path = sys.argv[1]
mapping = dict(arg.split("=", 1) for arg in sys.argv[2:])

# Per-hook event matrix.
HOOK_EVENTS = {
    "status-bg": {
        "wide": [
            "SessionStart", "SessionEnd", "UserPromptSubmit",
            "Stop", "PermissionRequest", "PermissionDenied",
        ],
        "narrow": [
            ("PreToolUse", "AskUserQuestion"),
            ("PostToolUse", "AskUserQuestion"),
        ],
    },
    "mark-input": {
        "wide": ["UserPromptSubmit"],
        "narrow": [],
    },
}

with open(path) as f:
    s = json.load(f)
hooks = s.setdefault("hooks", {})

added, skipped = [], []

def add_wide(event, cmd_str):
    blocks = hooks.setdefault(event, [{"hooks": []}])
    block = blocks[0]
    block.setdefault("hooks", [])
    if any(h.get("command") == cmd_str for h in block["hooks"]):
        return False
    block["hooks"].append({"type": "command", "command": cmd_str})
    return True

def add_narrow(event, matcher, cmd_str):
    blocks = hooks.setdefault(event, [])
    for b in blocks:
        if b.get("matcher") == matcher and any(
            h.get("command") == cmd_str for h in b.get("hooks", [])
        ):
            return False
    blocks.append({"matcher": matcher,
                   "hooks": [{"type": "command", "command": cmd_str}]})
    return True

for name, hook_path in mapping.items():
    cmd_str = f"bash '{hook_path}'"
    events = HOOK_EVENTS[name]
    for event in events["wide"]:
        tag = f"{name}/{event}"
        (added if add_wide(event, cmd_str) else skipped).append(tag)
    for event, matcher in events["narrow"]:
        tag = f"{name}/{event}({matcher})"
        (added if add_narrow(event, matcher, cmd_str) else skipped).append(tag)

with open(path, "w") as f:
    json.dump(s, f, indent=4, ensure_ascii=False)
    f.write("\n")

print("ADDED:  ", ", ".join(added) if added else "(nothing new)")
print("SKIPPED:", ", ".join(skipped) if skipped else "(none)")
PY

green ""
green "✓ Installation complete."
yellow "→ Restart your Claude Code session for hooks to take effect."
yellow "→ Logs: \$TMPDIR/claude-status-bg.log, \$TMPDIR/claude-mark-input.log"
