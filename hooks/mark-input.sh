#!/bin/bash
# cc-status-bg / mark-input
# Drop an iTerm2 SetMark on every UserPromptSubmit so you can jump
# between your own prompts in scrollback with Cmd+Shift+Up / Down,
# and (if you enable mark indicators in iTerm2) see a gutter triangle
# at every line where you typed.
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
[ "$event" = "UserPromptSubmit" ] || exit 0

printf '[%s] event=%s\n' "$(date '+%H:%M:%S')" "$event" >>"$LOG" 2>/dev/null

# The hook subprocess does not have /dev/tty in all spawn contexts —
# walk up to the parent (claude) process and write to ITS controlling tty.
parent_tty=$(ps -p "$PPID" -o tty= 2>/dev/null | tr -d ' ')
case "$parent_tty" in ""|"?"|"??"|"-") exit 0 ;; esac
target="/dev/$parent_tty"
[ -w "$target" ] || exit 0

# When this hook fires, Claude Code's TUI has already moved the cursor a
# few lines past the user's submitted message (rendered prompt + blank
# line + "Working..." spinner). Marking the cursor's current line lands
# below the user message and Claude's streaming response then overwrites
# that spot. To place the mark on the user message line, briefly cursor
# up by MARK_OFFSET, drop the mark, restore cursor. Tunable per-user.
#
# OSC 1337 SetMark — Cmd+Shift+Up/Down jumps between marks (iTerm2).
MARK_OFFSET="${CC_MARK_INPUT_OFFSET:-4}"
printf '\e7\e[%dA\e]1337;SetMark\e\\\e8' "$MARK_OFFSET" >"$target" 2>/dev/null

exit 0
