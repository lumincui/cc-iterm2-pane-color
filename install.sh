#!/bin/bash
# Install cc-iterm2-pane-color into ~/.claude.
# - Copies hooks/pane-color.sh to ~/.claude/hooks/
# - Merges hook entries into ~/.claude/settings.json (preserves existing hooks)
# - Idempotent: safe to run multiple times
# - Backs up settings.json before modifying

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_HOOK="$SCRIPT_DIR/hooks/pane-color.sh"
TARGET_HOOK="$HOME/.claude/hooks/pane-color.sh"
SETTINGS="$HOME/.claude/settings.json"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

if [ ! -f "$SOURCE_HOOK" ]; then
    red "ERROR: $SOURCE_HOOK not found. Run install.sh from the repo root."
    exit 1
fi

if [ ! -f "$SETTINGS" ]; then
    red "ERROR: $SETTINGS not found. Is Claude Code installed and run at least once?"
    exit 1
fi

if ! python3 -c "import json; json.load(open('$SETTINGS'))" 2>/dev/null; then
    red "ERROR: $SETTINGS is not valid JSON. Fix it before running install."
    exit 1
fi

mkdir -p "$HOME/.claude/hooks"
cp "$SOURCE_HOOK" "$TARGET_HOOK"
chmod +x "$TARGET_HOOK"
green "✓ Installed hook script to $TARGET_HOOK"

BACKUP="$SETTINGS.before-cc-pane-color-$(date +%Y%m%d-%H%M%S).bak"
cp "$SETTINGS" "$BACKUP"
green "✓ Backed up settings.json to $BACKUP"

python3 - "$SETTINGS" "$TARGET_HOOK" <<'PY'
import json, sys

path, hook_path = sys.argv[1], sys.argv[2]
cmd_str = f"bash '{hook_path}'"
hook_entry = {"type": "command", "command": cmd_str}

with open(path) as f:
    s = json.load(f)
hooks = s.setdefault("hooks", {})

# Events that get the script appended to existing matcher (any matcher OK).
WIDE_EVENTS = [
    "SessionStart", "SessionEnd", "UserPromptSubmit",
    "Stop", "PermissionRequest", "PermissionDenied",
]
# Events that get a NEW matcher block scoped to AskUserQuestion only.
NARROW_EVENTS = ["PreToolUse", "PostToolUse"]

added, skipped = [], []

for event in WIDE_EVENTS:
    blocks = hooks.setdefault(event, [{"hooks": []}])
    target_block = blocks[0]
    target_block.setdefault("hooks", [])
    if any(h.get("command") == cmd_str for h in target_block["hooks"]):
        skipped.append(event)
        continue
    target_block["hooks"].append(hook_entry)
    added.append(event)

for event in NARROW_EVENTS:
    blocks = hooks.setdefault(event, [])
    already = any(
        b.get("matcher") == "AskUserQuestion"
        and any(h.get("command") == cmd_str for h in b.get("hooks", []))
        for b in blocks
    )
    if already:
        skipped.append(f"{event}(AskUserQuestion)")
        continue
    blocks.append({"matcher": "AskUserQuestion", "hooks": [hook_entry]})
    added.append(f"{event}(AskUserQuestion)")

with open(path, "w") as f:
    json.dump(s, f, indent=4, ensure_ascii=False)
    f.write("\n")

print("ADDED:  ", ", ".join(added) if added else "(nothing new)")
print("SKIPPED:", ", ".join(skipped) if skipped else "(none)")
PY

green ""
green "✓ Installation complete."
yellow "→ Restart your Claude Code session for hooks to take effect."
yellow "→ Run \`tail -f \$TMPDIR/claude-pane-color.log\` to verify events fire."
