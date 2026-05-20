#!/usr/bin/env bash
# Apply iTerm2 pane UI configuration:
#   - install ClaudeCode dynamic profile (live, no restart needed)
#   - set global defaults (DimInactiveSplitPanes, SeparateStatusBarsPerPane,
#     ShowPaneTitles, Default Bookmark Guid)
#
# Global defaults can only be written safely while iTerm2 is NOT running —
# otherwise iTerm2's in-memory cache overwrites the file on quit. By default
# the script never quits iTerm2 for you. Pass --with-quit to opt in; you'll
# still get a confirmation dialog.
#
# Usage:
#   bash apply.sh                # safe path: never quits iTerm2
#   bash apply.sh --with-quit    # offers to quit iTerm2 after confirmation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

PROFILE_SRC="$SKILL_DIR/assets/ClaudeCode.json"
PROFILE_DST_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
PROFILE_GUID="claude-code-pane-ui"
PLIST_DOMAIN="com.googlecode.iterm2"
PLIST_FILE="$HOME/Library/Preferences/$PLIST_DOMAIN.plist"

WITH_QUIT=0
for arg in "$@"; do
    case "$arg" in
        --with-quit) WITH_QUIT=1 ;;
        -h|--help)
            sed -n '2,15p' "$0" | sed 's|^# \{0,1\}||'
            exit 0
            ;;
        *) echo "unknown arg: $arg (try --help)" >&2; exit 2 ;;
    esac
done

if [[ ! -f "$PROFILE_SRC" ]]; then
    echo "ERROR: profile template missing at $PROFILE_SRC" >&2
    exit 1
fi

# Step 1 — install dynamic profile. Always safe: iTerm2 watches this dir
# and reloads on file changes; no restart needed.
mkdir -p "$PROFILE_DST_DIR"
cp "$PROFILE_SRC" "$PROFILE_DST_DIR/ClaudeCode.json"
echo "✓ installed ClaudeCode dynamic profile"
echo "    → $PROFILE_DST_DIR/ClaudeCode.json"

# Step 2 — global defaults. These are the part that needs iTerm2 stopped.
iterm_running() {
    [[ "$(osascript -e 'application "iTerm2" is running' 2>/dev/null)" == "true" ]]
}

inside_iterm() {
    [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]
}

write_globals() {
    local stamp
    stamp=$(date +%Y%m%d-%H%M%S)
    if [[ -f "$PLIST_FILE" ]]; then
        cp "$PLIST_FILE" "$PLIST_FILE.bak.$stamp"
        echo "✓ backed up plist → $PLIST_FILE.bak.$stamp"
    fi
    defaults write "$PLIST_DOMAIN" DimInactiveSplitPanes -bool false
    defaults write "$PLIST_DOMAIN" SeparateStatusBarsPerPane -bool true
    defaults write "$PLIST_DOMAIN" ShowPaneTitles -bool false
    defaults write "$PLIST_DOMAIN" 'Default Bookmark Guid' -string "$PROFILE_GUID"
    echo "✓ wrote global defaults"
    echo "    DimInactiveSplitPanes      = false"
    echo "    SeparateStatusBarsPerPane  = true"
    echo "    ShowPaneTitles             = false"
    echo "    Default Bookmark Guid      = $PROFILE_GUID"
}

print_manual_instructions() {
    cat <<EOF

iTerm2 is currently running, so global defaults can't be written safely —
iTerm2 caches preferences in memory and will overwrite the file on next quit.

When you next quit iTerm2 (or now, if convenient), run:

    defaults write $PLIST_DOMAIN DimInactiveSplitPanes -bool false
    defaults write $PLIST_DOMAIN SeparateStatusBarsPerPane -bool true
    defaults write $PLIST_DOMAIN ShowPaneTitles -bool false
    defaults write $PLIST_DOMAIN 'Default Bookmark Guid' -string '$PROFILE_GUID'

Or re-run this script with --with-quit to do it automatically (you'll get a
confirmation dialog before iTerm2 is closed).

The ClaudeCode profile itself is already installed and usable now — open it
from Profiles menu, or via Cmd+I → Profiles → ClaudeCode.
EOF
}

confirm_quit_via_dialog() {
    # AppleScript dialog. Returns 0 if user clicked "Quit iTerm2", non-zero otherwise.
    local result
    result=$(osascript <<'APPLESCRIPT' 2>/dev/null || true
try
    display dialog "This will quit iTerm2.

All sessions, ssh connections, and tmux/screen attaches in iTerm2 will be closed.

Continue?" buttons {"Cancel", "Quit iTerm2"} default button "Cancel" with icon caution with title "Apply iTerm2 pane UI config"
    return button returned of result
on error
    return "Cancel"
end try
APPLESCRIPT
)
    [[ "$result" == "Quit iTerm2" ]]
}

quit_iterm_and_wait() {
    osascript -e 'tell application "iTerm2" to quit' >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        if ! iterm_running; then
            return 0
        fi
        sleep 0.5
    done
    echo "ERROR: iTerm2 didn't exit within 10s; aborting." >&2
    return 1
}

if ! iterm_running; then
    write_globals
    echo
    echo "Done. Launch iTerm2 — new windows will use the ClaudeCode profile."
    exit 0
fi

if [[ $WITH_QUIT -eq 1 ]]; then
    if inside_iterm; then
        cat >&2 <<EOF
ERROR: this script is running inside iTerm2 (TERM_PROGRAM=iTerm.app).
       --with-quit would close the very session you're sitting in.
       Either run from Terminal.app, or omit --with-quit and run the
       printed defaults commands later.
EOF
        exit 1
    fi
    if confirm_quit_via_dialog; then
        quit_iterm_and_wait
        write_globals
        echo
        echo "Done. Relaunch iTerm2 — new windows will use the ClaudeCode profile."
        exit 0
    else
        echo "User cancelled quit."
        print_manual_instructions
        exit 0
    fi
fi

print_manual_instructions
