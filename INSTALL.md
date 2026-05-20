# Installation

## Prerequisites

- macOS with iTerm2 (other terminals work for the color part — see Compatibility in the [README](README.md#compatibility))
- [Claude Code](https://docs.claude.com/en/docs/claude-code) installed and run at least once (so `~/.claude/settings.json` exists)
- `python3` available on `PATH` (ships with macOS; used by the installer to safely merge JSON)
- `bash` 3.2+ (ships with macOS)

## Quick install

```bash
git clone https://github.com/lumincui/cc-iterm2-color.git
cd cc-iterm2-color
bash install.sh                       # both hooks
# or pick a subset:
bash install.sh mark-input            # only the prompt marker
bash install.sh status-bg             # only the background tinting
```

Restart your Claude Code session.

## What the installer does

1. **Copies the hook script(s)**
   `hooks/<name>.sh` → `~/.claude/hooks/<name>.sh` (mode 0755), for each selected hook.

2. **Backs up settings**
   `~/.claude/settings.json` → `~/.claude/settings.json.before-cc-iterm2-color-<timestamp>.bak`

3. **Merges hook entries** into `~/.claude/settings.json`. The installer is idempotent — running it twice will not duplicate entries. Existing hooks pointing at other scripts are preserved.

   The events each script gets registered on:

   **`status-bg.sh`**

   | Event | Matcher | Behavior |
   |---|---|---|
   | `Stop` | (any) | green |
   | `PermissionRequest` | (any) | orange |
   | `UserPromptSubmit` | (any) | reset |
   | `SessionStart` | (any) | reset |
   | `SessionEnd` | (any) | reset |
   | `PermissionDenied` | (any) | reset |
   | `PreToolUse` | `AskUserQuestion` | orange |
   | `PostToolUse` | `AskUserQuestion` | reset |

   For `PreToolUse` / `PostToolUse`, a **new matcher block scoped to `AskUserQuestion`** is added so the script doesn't fire on every tool call.

   **`mark-input.sh`**

   | Event | Matcher | Behavior |
   |---|---|---|
   | `UserPromptSubmit` | (any) | drop iTerm2 mark at cursor |

## Manual install

If you'd rather not run the installer, do these three steps for each hook you want:

### 1. Copy the hook

```bash
mkdir -p ~/.claude/hooks
cp hooks/status-bg.sh   ~/.claude/hooks/   # if you want the background tinting
cp hooks/mark-input.sh  ~/.claude/hooks/   # if you want prompt marks
chmod +x ~/.claude/hooks/*.sh
```

### 2. Edit `~/.claude/settings.json`

Add `bash '/Users/<you>/.claude/hooks/<name>.sh'` to the `hooks` array of each event listed in the tables above. Wrap in the standard Claude Code hook block format:

```json
"Stop": [
  {
    "hooks": [
      { "type": "command", "command": "bash '/Users/<you>/.claude/hooks/status-bg.sh'" }
    ]
  }
]
```

For `PreToolUse` and `PostToolUse`, use a separate block with `matcher: "AskUserQuestion"`:

```json
"PreToolUse": [
  {
    "matcher": "AskUserQuestion",
    "hooks": [
      { "type": "command", "command": "bash '/Users/<you>/.claude/hooks/status-bg.sh'" }
    ]
  }
]
```

### 3. Restart Claude Code

The hook config is read at session start.

## Verify

Open a new Claude Code session and tail the logs in another terminal:

```bash
tail -f "$TMPDIR/claude-status-bg.log" "$TMPDIR/claude-mark-input.log"
```

Trigger each state:

| Action | Expected event in log | Expected effect |
|---|---|---|
| Send a prompt and wait for the response | `Stop` (status-bg) | 🟢 green |
| Send a new prompt | `UserPromptSubmit` (both) | reset color + iTerm2 mark dropped |
| Press `Cmd+Shift+↑` | — | cursor jumps to the previous mark |
| Ask Claude to call `AskUserQuestion` (e.g. "ask me a multi-choice question") | `PreToolUse` (status-bg) | 🟠 orange |
| Answer the question | `PostToolUse` (status-bg) | reset |

If you don't see colors changing, see [Troubleshooting](#troubleshooting). If marks aren't navigable, enable **Preferences → Profiles → Terminal → "Show mark indicators"** and confirm `Cmd+Shift+↑`/`↓` isn't rebound in **Preferences → Keys**.

## Troubleshooting

**No log file is being written**
The installer didn't take effect, or you didn't restart Claude Code. Check `~/.claude/settings.json` contains entries pointing at `status-bg.sh`, then open a fresh session.

**Log is being written but the pane color doesn't change**
- Confirm your terminal honors `OSC 11`. Quick test in your shell:
  ```bash
  printf '\e]11;#502508\e\\' ; sleep 2 ; printf '\e]111\e\\'
  ```
  If the background doesn't tint orange and reset, your terminal doesn't support `OSC 11`.
- Check that `status-bg.sh` is executable: `ls -l ~/.claude/hooks/status-bg.sh`.

**The `Stop` color (green) gets overridden to orange**
You wired the hook to `Notification` somewhere. Remove that wiring — `Notification` fires for both idle and attention, and our installer deliberately avoids it. The clean route is `Stop` + `PermissionRequest` + `PreToolUse(AskUserQuestion)`.

**Colors leak into newly split panes**
`OSC 11` is per-pane, but iTerm2 copies pane state into freshly split panes. Two options:
1. Live with it — the next event resets it, or Cmd+Click clears it (see "Optional: click to reset" in the README).
2. Add `printf '\e]111\e\\' 2>/dev/null` to the top of your shell rc (`~/.zshrc`, `~/.bashrc`) so each new shell starts clean.

## Uninstall

```bash
bash uninstall.sh                       # remove both hooks
bash uninstall.sh mark-input            # only one
bash uninstall.sh status-bg
```

Or restore the pre-install backup directly:

```bash
cp ~/.claude/settings.json.before-cc-iterm2-color-<timestamp>.bak ~/.claude/settings.json
rm ~/.claude/hooks/status-bg.sh ~/.claude/hooks/mark-input.sh
```
