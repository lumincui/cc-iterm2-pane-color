#!/bin/bash
# Uninstall cc-status-bg hooks.
# - Removes hook entries from ~/.claude/settings.json
# - Deletes the hook scripts
# - Backs up settings.json before modifying
#
# Usage:
#   bash uninstall.sh                       # uninstall all hooks
#   bash uninstall.sh status-bg             # only status-bg
#   bash uninstall.sh mark-input            # only mark-input
#   bash uninstall.sh status-bg mark-input  # explicit list

set -euo pipefail

TARGET_HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

ALL_HOOKS=("status-bg" "mark-input")

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

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
    red "ERROR: $SETTINGS not found."
    exit 1
fi

BACKUP="$SETTINGS.before-cc-status-bg-uninstall-$(date +%Y%m%d-%H%M%S).bak"
cp "$SETTINGS" "$BACKUP"
green "✓ Backed up settings.json to $BACKUP"

# Pass the registrar a list of hook command strings to drop.
declare -a cmd_strings=()
for name in "${selected[@]}"; do
    cmd_strings+=("bash '$TARGET_HOOKS_DIR/$name.sh'")
done

python3 - "$SETTINGS" "${cmd_strings[@]}" <<'PY'
import json, sys

path = sys.argv[1]
targets = set(sys.argv[2:])

with open(path) as f:
    s = json.load(f)

hooks = s.get("hooks", {})
removed = 0
emptied = []

for event, blocks in list(hooks.items()):
    new_blocks = []
    for block in blocks:
        block["hooks"] = [
            h for h in block.get("hooks", []) if h.get("command") not in targets
        ]
        if not block["hooks"]:
            emptied.append(f"{event}/{block.get('matcher','*')}")
            removed += 1
            continue
        new_blocks.append(block)
    if new_blocks:
        hooks[event] = new_blocks
    else:
        del hooks[event]

with open(path, "w") as f:
    json.dump(s, f, indent=4, ensure_ascii=False)
    f.write("\n")

print(f"Cleared {removed} hook block(s):", ", ".join(emptied) if emptied else "(none)")
PY

for name in "${selected[@]}"; do
    f="$TARGET_HOOKS_DIR/$name.sh"
    if [ -f "$f" ]; then
        rm -f "$f"
        green "✓ Removed $f"
    fi
done

green ""
green "✓ Uninstall complete."
yellow "→ Restart your Claude Code session to drop the in-memory hook config."
