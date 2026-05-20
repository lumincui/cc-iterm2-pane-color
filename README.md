# cc-iterm2-pane-color

> Color-code your iTerm2 panes by Claude Code state. **Green = ready to sign off. Orange = needs your input. Default = still working.** Triage a wall of parallel agents at a glance — no daemon, no Python runtime, just a shell hook.

Running multiple Claude Code sessions in parallel is how you scale yourself — but the panes look identical, so you can't tell which session is **done**, which is **blocked on you**, and which is **still chugging**. You tab through them one by one and miss the one that's been waiting on a permission prompt for ten minutes.

This hook fixes that by tinting each pane's **background** based on Claude Code's lifecycle events. One glance across the grid and you know exactly where to act:

| State | Color | When it triggers | What to do |
|---|---|---|---|
| 🟢 **Ready to sign off** | dark green | Claude finished its turn (`Stop`) | Review the diff, accept or push back |
| 🟠 **Needs you** | dark orange | Permission prompt, or `AskUserQuestion` is waiting | Answer it — Claude is blocked |
| _Working_ | _your default profile bg_ | Running, just launched, or right after you reply | Leave it alone |

![Four-pane iTerm2 grid demonstrating the colors: two green panes are finished and waiting to be reviewed, one orange pane is blocked on a multi-choice question, one default-colored pane is still actively working.](docs/screenshot.jpg)

Subtle by default — the colors are dark and low-saturation so they don't fight your theme. Tune in one line if you want them louder.

## How it works

```
Claude Code event ──▶ pane-color.sh ──▶ writes OSC 11 to /dev/<parent_tty>
                                         │
                                         ▼
                                    iTerm2 reads pty, parses OSC,
                                    repaints pane background
```

- Pure shell hook. Bash + `printf`. No Python runtime, no AutoLaunch script, no daemon.
- Standard `OSC 11` / `OSC 111` escape sequences — works on any modern terminal that honors them; iTerm2 is the primary target.
- Per-pane scoped — split panes are colored independently because OSC 11 targets the writer's pty, not the tab.
- Routes around the `Notification` event (which fires both on idle _and_ on attention with no reliable way to tell them apart) and uses `Stop` + `PermissionRequest` + `PreToolUse(matcher=AskUserQuestion)` for clean state mapping.

## Install

```bash
git clone https://github.com/lumincui/cc-iterm2-pane-color.git
cd cc-iterm2-pane-color
bash install.sh
```

The installer:
1. Copies `hooks/pane-color.sh` to `~/.claude/hooks/`
2. **Merges** entries into `~/.claude/settings.json` — your existing hooks are preserved
3. Backs up `settings.json` to a timestamped `.bak` before writing

**Restart your Claude Code session** afterward — Claude Code reads the hook config at startup.

Detailed steps in [INSTALL.md](INSTALL.md).

## Configure colors

Edit `~/.claude/hooks/pane-color.sh`, top of file:

```bash
readonly GREEN=$'\e]11;#0a2418\e\\'   # idle
readonly ORANGE=$'\e]11;#502508\e\\'  # attention
```

Hex is standard `#RRGGBB`. Changes take effect on the **next** event — no restart needed for color tweaks.

Suggestions:

| Goal | Green | Orange |
|---|---|---|
| Subtle (default) | `#0a2418` | `#502508` |
| Visible | `#143a20` | `#7a3a10` |
| Loud | `#1f5530` | `#a04a18` |

## Optional: click to reset

If you want a focused pane's color to clear on click — without writing a daemon — bind a pointer action in iTerm2:

> **Preferences → Pointer → +**
> - **Action**: Run Command
> - **Modifier**: ⌘ + Click _(bare left click can't be repurposed without breaking selection)_
> - **Command**: `printf '\e]111\e\\' > \(session.tty)`

Cmd-click any pane → background resets to your profile default. iTerm2 spawns a sub-shell to run the command; the `printf` writes `OSC 111` to that pane's pty, which iTerm2 itself parses as "reset background color".

## Verify

Tail the log and trigger a turn:

```bash
tail -f "$TMPDIR/claude-pane-color.log"
```

You should see lines like:

```
[14:32:01] event=UserPromptSubmit
[14:32:08] event=PostToolUse
[14:32:14] event=Stop
```

And the pane background should follow the state table above.

## Uninstall

```bash
bash uninstall.sh
```

Removes the script, removes hook entries from `settings.json`, leaves a backup. Restart your session afterward.

## Compatibility

- **macOS + iTerm2** — primary target, tested.
- **Other terminals** — `OSC 11` and `OSC 111` are standard xterm sequences. Most modern terminals (Ghostty, kitty, alacritty, Terminal.app) honor them. The "Cmd+Click reset" recipe above is iTerm2-specific.
- **Other shells** — the hook is `bash`. Your interactive shell can be anything; the hook is invoked by Claude Code, not by your shell.

## License

MIT
