#!/bin/bash
# cc-iterm2-color / mark-input
# Drop an iTerm2 SetMark at navigation-worthy moments so Cmd+Shift+Up/Down
# in scrollback jumps between them, and (if you enable mark indicators in
# iTerm2) the gutter shows a triangle at each one.
#
# Events handled:
#   - UserPromptSubmit             — every prompt you type
#   - PostToolUse / ExitPlanMode   — Claude's "● Updated plan" moments
#
# Why not a colored banner instead? Claude Code's TUI repaints during
# streaming and would clobber any text we print. OSC 1337 marks are
# stored in iTerm2's scrollback model, not on screen, so they survive.
#
# Debug log: tail -f $TMPDIR/claude-mark-input.log

readonly LOG="${TMPDIR:-/tmp}/claude-mark-input.log"

input=$(cat)
[[ "$input" =~ \"hook_event_name\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] || exit 0
event="${BASH_REMATCH[1]}"

# Pick the cursor offset based on what fired. The hook's job is to land
# the mark on (or close to) the line that says either the user's prompt
# or "● Updated plan", so when you Cmd+Shift+Up later you arrive at the
# right place in scrollback.
case "$event" in
    UserPromptSubmit)
        # TUI has already rendered: prompt + blank + "Working..." spinner.
        # Step back 4 lines to land on the user message itself.
        offset="${CC_MARK_INPUT_OFFSET:-4}"
        ;;
    PostToolUse)
        # Only mark ExitPlanMode — that's the "● Updated plan" render.
        [[ "$input" =~ \"tool_name\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] || exit 0
        [ "${BASH_REMATCH[1]}" = "ExitPlanMode" ] || exit 0
        # Offset estimated for the "● Updated plan" + "└ /plan to preview"
        # render. Hardcoded — tune here if it lands off in your install.
        offset=3
        ;;
    *) exit 0 ;;
esac

printf '[%s] event=%s offset=%s\n' "$(date '+%H:%M:%S')" "$event" "$offset" >>"$LOG" 2>/dev/null

# The hook subprocess does not have /dev/tty in all spawn contexts —
# walk up to the parent (claude) process and write to ITS controlling tty.
parent_tty=$(ps -p "$PPID" -o tty= 2>/dev/null | tr -d ' ')
case "$parent_tty" in ""|"?"|"??"|"-") exit 0 ;; esac
target="/dev/$parent_tty"
[ -w "$target" ] || exit 0

# OSC 1337 SetMark — save cursor, step up, drop mark, restore cursor.
# Cmd+Shift+Up/Down in iTerm2 jumps between marks.
printf '\e7\e[%dA\e]1337;SetMark\e\\\e8' "$offset" >"$target" 2>/dev/null

exit 0
