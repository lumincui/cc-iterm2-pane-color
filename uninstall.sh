#!/bin/bash
# Uninstall cc-status-bg.
# - Removes hook entries from ~/.claude/settings.json
# - Deletes the hook script
# - Backs up settings.json before modifying

set -euo pipefail

TARGET_HOOK="$HOME/.claude/hooks/status-bg.sh"
SETTINGS="$HOME/.claude/settings.json"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

if [ ! -f "$SETTINGS" ]; then
    red "ERROR: $SETTINGS not found."
    exit 1
fi

BACKUP="$SETTINGS.before-cc-status-bg-uninstall-$(date +%Y%m%d-%H%M%S).bak"
cp "$SETTINGS" "$BACKUP"
green "✓ Backed up settings.json to $BACKUP"

python3 - "$SETTINGS" "$TARGET_HOOK" <<'PY'
import json, sys

path, hook_path = sys.argv[1], sys.argv[2]
cmd_str = f"bash '{hook_path}'"

with open(path) as f:
    s = json.load(f)

hooks = s.get("hooks", {})
removed = 0
emptied = []

for event, blocks in list(hooks.items()):
    new_blocks = []
    for block in blocks:
        block["hooks"] = [
            h for h in block.get("hooks", []) if h.get("command") != cmd_str
        ]
        if not block["hooks"]:
            # Block has no commands left — drop it (matcher block becomes useless)
            emptied.append(f"{event}/{block.get('matcher','*')}")
            removed += 1
            continue
        new_blocks.append(block)
        if any(
            h.get("command") == cmd_str for h in block["hooks"]  # shouldn't happen
        ):
            pass
    if new_blocks:
        hooks[event] = new_blocks
    else:
        del hooks[event]

with open(path, "w") as f:
    json.dump(s, f, indent=4, ensure_ascii=False)
    f.write("\n")

print(f"Cleared {removed} hook block(s):", ", ".join(emptied) if emptied else "(none)")
PY

if [ -f "$TARGET_HOOK" ]; then
    rm -f "$TARGET_HOOK"
    green "✓ Removed $TARGET_HOOK"
fi

green ""
green "✓ Uninstall complete."
yellow "→ Restart your Claude Code session to drop the in-memory hook config."
