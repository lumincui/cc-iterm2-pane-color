#!/bin/bash
# cc-status-bg
# Map Claude Code lifecycle events to terminal background color.
#
# State        Trigger                                              Color
# ----------   --------------------------------------------------   --------
# idle         Stop                                                 green
# attention    PermissionRequest                                    orange
# attention    PreToolUse  (matcher: AskUserQuestion only)          orange
# running      UserPromptSubmit                                     reset
# running      PostToolUse (matcher: AskUserQuestion only)          reset
# initial      SessionStart / SessionEnd / PermissionDenied         reset
# other        any other event                                      untouched
#
# Debug log: tail -f $TMPDIR/claude-status-bg.log

readonly GREEN=$'\e]11;#0a2418\e\\'
readonly ORANGE=$'\e]11;#502508\e\\'
readonly RESET=$'\e]111\e\\'
readonly LOG="${TMPDIR:-/tmp}/claude-status-bg.log"

input=$(cat)
[[ "$input" =~ \"hook_event_name\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] || exit 0
event="${BASH_REMATCH[1]}"

printf '[%s] event=%s\n' "$(date '+%H:%M:%S')" "$event" >>"$LOG" 2>/dev/null

# The hook subprocess itself does not have /dev/tty in all spawn contexts —
# walk up to the parent (claude) process and write to ITS controlling tty.
parent_tty=$(ps -p "$PPID" -o tty= 2>/dev/null | tr -d ' ')
case "$parent_tty" in ""|"?"|"??"|"-") exit 0 ;; esac
target="/dev/$parent_tty"
[ -w "$target" ] || exit 0

emit() { printf '%s' "$1" >"$target" 2>/dev/null || true; }

case "$event" in
  Stop)                                                                  emit "$GREEN"  ;;
  PermissionRequest|PreToolUse)                                          emit "$ORANGE" ;;
  PostToolUse|UserPromptSubmit|SessionStart|SessionEnd|PermissionDenied) emit "$RESET"  ;;
esac

exit 0
